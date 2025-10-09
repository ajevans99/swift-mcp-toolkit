import Foundation
import MCPToolkit
import Testing

@Suite("Response messaging customization")
struct ResponseMessagingTests {
  @Test("Default messaging mirrors legacy strings")
  func defaultMessagingMatchesLegacyBehaviour() {
    let messaging = DefaultResponseMessaging()

    let unknown = messaging.unknownTool(.init(requestedName: "mystery"))
    #expect(unknown.isError == true)
    #expect(unknown.content == [.text("Unknown tool: mystery")])

    let missingArguments = messaging.missingArguments(.init(toolName: "addition"))
    #expect(missingArguments.content == [.text("Missing arguments for tool addition")])
  }

  @Test("call(arguments:) surfaces override for parsing failures")
  func callUsesCustomParsingMessaging() async throws {
    let messaging = ResponseMessagingFactory.defaultWithOverrides { overrides in
      overrides.parsingFailed = { context in
        #expect(context.toolName == "addition")
        #expect(!context.issues.isEmpty)
        return .init(
          content: [.text("Custom parse failure for \(context.toolName)")],
          isError: true
        )
      }
      overrides.parsingAndValidationFailed = { context in
        #expect(context.toolName == "addition")
        #expect(!context.parseIssues.isEmpty)
        return .init(
          content: [.text("Custom parse failure for \(context.toolName)")],
          isError: true
        )
      }
    }

    let result = try await AdditionTool().call(
      arguments: [
        "left": .int(1),
        "right": .string("not-a-number"),
      ],
      messaging: messaging
    )

    #expect(result.isError == true)
    #expect(result.content == [.text("Custom parse failure for addition")])
  }

  @Test("Server.register uses custom messaging for toolkit errors")
  func serverUsesCustomMessaging() async throws {
    let transport = TestTransport()
    let server = Server(name: "Messaging Server", version: "1.0.0")
    let tool = AdditionTool()

    let messaging = ResponseMessagingFactory.defaultWithOverrides { overrides in
      overrides.missingArguments = { context in
        #expect(context.toolName == tool.name)
        return .init(content: [.text("Provide args for \(context.toolName)!")], isError: true)
      }
      overrides.toolThrew = { context in
        return .init(content: [.text("Tool boom: \(context.error)")], isError: true)
      }
    }

    await server.register(tools: [tool], messaging: messaging)
    try await server.start(transport: transport)

    do {
      let encoder = JSONEncoder()
      let decoder = JSONDecoder()

      await transport.push(
        try encoder.encode(CallTool.request(.init(name: tool.name, arguments: nil)))
      )

      let responses = try await transport.waitForSent(count: 1)
      let data = try #require(responses.first)
      let response = try decoder.decode(Response<CallTool>.self, from: data)
      let result = try response.result.get()

      #expect(result.isError == true)
      #expect(result.content == [.text("Provide args for addition!")])
    } catch {
      await transport.finish()
      await server.stop()
      throw error
    }

    await transport.finish()
    await server.stop()
  }
}
