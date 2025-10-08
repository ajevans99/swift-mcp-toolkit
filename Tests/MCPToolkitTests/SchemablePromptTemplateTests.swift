import MCPToolkit
import Testing

struct SummaryPrompt: MCPPromptTemplate {
  let name = "status-summary"
  let description: String? = "Collects a short status update."

  @Schemable
  struct Arguments {
    let topic: String
    let includeBlockers: Bool
  }

  func messages(using arguments: Arguments) async throws -> [Prompt.Message] {
    PromptMessages {
      "Summarise the latest progress for \(arguments.topic)."
      if arguments.includeBlockers {
        "List any blockers that need escalation."
      }
      Prompt.Message.assistant("Acknowledged.")
    }
  }
}

@Suite("@Schemable MCPPromptTemplate")
struct SchemablePromptTemplateTests {
  @Test("render(arguments:) parses @Schemable definitions correctly")
  func renderProducesMessages() async throws {
    let messages = try await SummaryPrompt().render(arguments: [
      "topic": .string("MCPToolkit"),
      "includeBlockers": .bool(true),
    ])

    #expect(messages.count == 3)
    #expect(messages.first?.role == .user)

    if case .text(let text) = messages.first?.content {
      #expect(text.contains("MCPToolkit"))
    } else {
      Issue.record("Expected initial user message")
    }
  }

  @Test("render(arguments:) throws for invalid payloads")
  func renderFailsWithMissingArgument() async {
    do {
      _ = try await SummaryPrompt().render(arguments: [
        "topic": .string("MCPToolkit")
        // Missing includeBlockers flag
      ])
      Issue.record("Expected render to throw invalidParams")
    } catch MCPError.invalidParams(let detail) {
      #expect(detail?.contains("includeBlockers") == true)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("toPrompt() generates prompt metadata from schema")
  func toPromptGeneratesArguments() throws {
    let prompt = SummaryPrompt().toPrompt()

    #expect(prompt.name == "status-summary")
    #expect(prompt.description == "Collects a short status update.")
    let arguments = try #require(prompt.arguments)
    #expect(arguments.count == 2)

    let includeBlockers = arguments.first { $0.name == "includeBlockers" }
    #expect(includeBlockers?.required == true)
  }
}
