import Foundation
import MCPToolkit
import Testing

@Suite("MCP server integration")
struct MCPToolkitIntegrationTests {
  @Test("register(tools:) responds to tools/list and tools/call")
  func serverHandlesToolLifecycle() async throws {
    let transport = TestTransport()
    let server = Server(name: "Test Server", version: "1.0.0")
    let tool = AdditionTool()

    await server.register(tools: [tool])
    try await server.start(transport: transport)

    do {
      let encoder = JSONEncoder()
      let decoder = JSONDecoder()

      await transport.push(try encoder.encode(ListTools.request(.init())))

      let listResponses = try await transport.waitForSent(count: 1)
      let listResponseData = try #require(listResponses.first)
      let listResponse = try decoder.decode(Response<ListTools>.self, from: listResponseData)
      let listResult = try listResponse.result.get()
      let registeredTool = try #require(listResult.tools.first)

      #expect(registeredTool.name == tool.name)
      #expect(registeredTool.description == tool.description)

      let arguments: [String: MCP.Value] = [
        "left": .int(2),
        "right": .int(3),
      ]
      await transport.push(
        try encoder.encode(CallTool.request(.init(name: tool.name, arguments: arguments)))
      )

      let callResponses = try await transport.waitForSent(count: 1)
      let callResponseData = try #require(callResponses.first)
      let callResponse = try decoder.decode(Response<CallTool>.self, from: callResponseData)
      let callResult = try callResponse.result.get()

      #expect(callResult.isError != true)

      switch callResult.content.first {
      case .some(.text(let message)):
        #expect(message == "5")
      default:
        Issue.record("Expected textual tool response")
      }
    } catch {
      await transport.finish()
      await server.stop()
      throw error
    }

    await transport.finish()
    await server.stop()
  }
}
