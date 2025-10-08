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

  @Test("register(prompts:) responds to prompts/list and prompts/get")
  func serverHandlesPromptLifecycle() async throws {
    let transport = TestTransport()
    let server = Server(name: "Prompt Server", version: "1.0.0")
    let prompt = SummaryPrompt()

    await server.register(prompts: [prompt])
    try await server.start(transport: transport)

    do {
      let encoder = JSONEncoder()
      let decoder = JSONDecoder()

      await transport.push(try encoder.encode(ListPrompts.request(.init())))

      let listResponses = try await transport.waitForSent(count: 1)
      let listResponseData = try #require(listResponses.first)
      let listResponse = try decoder.decode(Response<ListPrompts>.self, from: listResponseData)
      let listResult = try listResponse.result.get()
      let registeredPrompt = try #require(listResult.prompts.first)

      #expect(registeredPrompt.name == prompt.name)
      #expect(registeredPrompt.description == prompt.description)
      #expect(registeredPrompt.arguments?.count == 2)

      let arguments: [String: MCP.Value] = [
        "topic": .string("SDK ergonomics"),
        "includeBlockers": .bool(false),
      ]

      await transport.push(
        try encoder.encode(GetPrompt.request(.init(name: prompt.name, arguments: arguments)))
      )

      let getResponses = try await transport.waitForSent(count: 1)
      let getResponseData = try #require(getResponses.first)
      let getResponse = try decoder.decode(Response<GetPrompt>.self, from: getResponseData)
      let getResult = try getResponse.result.get()

      #expect(getResult.messages.count == 2)
      if case .text(let text) = getResult.messages.first?.content {
        #expect(text.contains("SDK ergonomics"))
      } else {
        Issue.record("Expected textual prompt content")
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
