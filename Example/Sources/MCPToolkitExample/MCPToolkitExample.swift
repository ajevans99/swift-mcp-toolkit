import ArgumentParser
import MCP
import MCPToolkit
import Vapor

@main
struct MCPToolkitExampleCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Run the MCPToolKit example MCP server over stdio or HTTP."
  )

  enum TransportKind: String, Codable, ExpressibleByArgument {
    case stdio
    case http
  }

  @ArgumentParser.Option(
    name: [.short, .long],
    help: "Transport to use: stdio or http."
  )
  var transport: TransportKind = .stdio

  @ArgumentParser.Option(
    name: .long,
    help: "Hostname to bind when using the HTTP transport."
  )
  var host: String = "127.0.0.1"

  @ArgumentParser.Option(
    name: .long,
    help: "Port to bind when using the HTTP transport."
  )
  var port: Int = 8080

  @ArgumentParser.Option(
    name: .long,
    help: "HTTP endpoint path for the MCP stream."
  )
  var endpoint: String = "/mcp"

  func run() async throws {
    let server = await makeMCPServer()

    switch transport {
    case .stdio:
      try await runStdio(server: server)
    case .http:
      try await runHTTP(server: server)
    }
  }

  private func runStdio(server: MCP.Server) async throws {
    let transport = StdioTransport()
    try await transport.connect()
    defer { Task { await transport.disconnect() } }

    try await server.start(transport: transport)
    await server.waitUntilCompleted()
  }

  private func runHTTP(server: MCP.Server) async throws {
    let executable = ProcessInfo.processInfo.arguments.first ?? "OpenAIAppsServer"

    var env = try Environment.detect(arguments: [executable])
    try LoggingSystem.bootstrap(from: &env)

    let app = try await Application.make(env)
    app.http.server.configuration.hostname = host
    app.http.server.configuration.port = port

    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    let transport = VaporStreamableHTTPTransport(app: app, endpoint: endpoint, logger: app.logger)
    try await transport.connect()

    let cleanup: @Sendable () async -> Void = {
      await server.stop()
      await server.waitUntilCompleted()
      await transport.disconnect()
      try? await app.asyncShutdown()
    }

    app.get("health") { req async throws -> String in
      "MCPToolKit example MCP server is running. Connect your MCP client to the /mcp endpoint."
    }

    do {
      try await server.start(transport: transport)
      try await app.execute()
    } catch {
      app.logger.error("Error occurred while running HTTP server: \(error)")
      await cleanup()
      throw error
    }

    await cleanup()
  }
}
