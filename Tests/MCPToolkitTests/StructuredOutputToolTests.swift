import MCP
import Testing

@testable import MCPToolkit

@Schemable
struct WeatherToolParameters: Codable, Sendable {
  let location: String
}

@Schemable
struct WeatherToolOutput: Codable, Sendable {
  let temperature: Double
  let conditions: String
  let humidity: Int
}

private struct StructuredWeatherTool: MCPToolWithStructuredOutput {
  let name = "structured-weather"

  typealias Parameters = WeatherToolParameters
  typealias Output = WeatherToolOutput

  func produceOutput(with arguments: Parameters) async throws -> Output {
    Output(temperature: 22.5, conditions: "Partly cloudy", humidity: 65)
  }

  func content(for output: Output) throws -> [Tool.Content] {
    [
      .text(
        "Weather for location is \(output.temperature)C with \(output.conditions.lowercased())."
      )
    ]
  }
}

@Schemable
struct InvalidStructuredParameters: Codable, Sendable {
  let location: String
}

@Schemable
struct InvalidStructuredOutput: Codable, Sendable {
  let value: Int
}

private struct InvalidStructuredOutputTool: MCPToolWithStructuredOutput {
  let name = "invalid-structured"

  typealias Parameters = InvalidStructuredParameters
  typealias Output = InvalidStructuredOutput

  func produceOutput(with arguments: Parameters) async throws -> Output {
    Output(value: 1)
  }

  func call(with arguments: Parameters) async throws -> CallTool.Result {
    CallTool.Result(
      content: [.text("bad structured output")],
      structuredContent: .string("not an object")
    )
  }
}

@Suite("Structured output tools")
struct StructuredOutputToolTests {
  @Test("call(arguments:) returns structured content")
  func callProducesStructuredOutput() async throws {
    let tool = StructuredWeatherTool()

    let result = try await tool.call(arguments: [
      "location": .string("Seattle")
    ])

    #expect(result.isError != true)

    #expect(result.structuredContent?.objectValue?["temperature"]?.doubleValue == 22.5)
    #expect(result.structuredContent?.objectValue?["conditions"]?.stringValue == "Partly cloudy")
    #expect(result.structuredContent?.objectValue?["humidity"]?.intValue == 65)

    #expect(
      result.content == [
        .text("Weather for location is 22.5C with partly cloudy.")
      ]
    )
  }

  @Test("toTool includes output schema")
  func toolIncludesOutputSchema() throws {
    let tool = StructuredWeatherTool().toTool()

    #expect(tool.outputSchema != nil)
    #expect(
      tool.outputSchema?.objectValue?["required"]?.arrayValue?.contains(.string("temperature"))
        == true
    )
  }

  @Test("call(arguments:) reports structured output validation errors")
  func callReportsStructuredValidationIssues() async throws {
    let result = try await InvalidStructuredOutputTool().call(arguments: [
      "location": .string("Anywhere")
    ])

    #expect(result.isError == true)

    guard case .text(let message)? = result.content.first else {
      Issue.record("Expected a textual error message")
      return
    }

    #expect(
      message.contains(
        "Structured output for tool invalid-structured failed parsing and validation"
      )
    )
  }
}
