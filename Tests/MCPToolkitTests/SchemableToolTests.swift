import Foundation
import MCPToolkit
import Testing

struct MultiplicationTool: MCPTool {
  let name = "multiplication"
  let description: String? = "Multiply two integers and return the product."

  @Schemable
  struct Parameters {
    /// The first number to multiply
    let multiplicand: Int
    /// The second number to multiply
    let multiplier: Int
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    let product = arguments.multiplicand * arguments.multiplier
    "\(product)"
  }
}

struct SimpleBuilderTool: MCPTool {
  let name = "simple"

  @Schemable
  struct Parameters {
    let name: String
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    "Hello, \(arguments.name)!"
  }
}

struct SimpleContentTool: MCPTool {
  let name = "content_builder"

  @Schemable
  struct Parameters {
    let name: String
    let enthusiastic: Bool
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    let message =
      switch arguments.enthusiastic {
      case true:
        "Hello, \(arguments.name)!!!"
      case false:
        "Hello, \(arguments.name)."
      }

    return [ToolContentItem(text: message)]
  }
}

struct ToolErrorTool: MCPTool {
  let name = "tool_error"

  @Schemable
  struct Parameters {
    let shouldError: Bool
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    if arguments.shouldError {
      throw ToolError {
        "Something went wrong"
        "Please check your input"
      }
    }
    return ["Success"]
  }
}

struct MultiLineContentTool: MCPTool {
  let name = "multi_line"

  @Schemable
  struct Parameters {
    let lines: Int
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    // Demonstrates flexible return types:
    // - Single string (no array wrapper needed)
    // - Array of strings
    switch arguments.lines {
    case 1:
      "Line 1"  // Single string works without wrapping in array
    case 2:
      ["Line 1", "Line 2"]  // Array literal also works
    default:
      ["Line 1", "Line 2", "Line 3"]
    }
  }
}

@Suite("@Schemable MCPTool")
struct SchemableToolTests {
  @Test("call(arguments:) parses @Schemable parameters correctly")
  func callSucceedsWithSchemable() async throws {
    let result = try await MultiplicationTool().call(arguments: [
      "multiplicand": .int(6),
      "multiplier": .int(7),
    ])

    #expect(result.isError != true)
    #expect(result.content == [.text("42")])
  }

  @Test("call(arguments:) reports validation errors for @Schemable")
  func callHandlesMissingParameter() async throws {
    let result = try await MultiplicationTool().call(arguments: [
      "multiplicand": .int(6)
      // Missing "multiplier" value triggers a validation failure
    ])

    #expect(result.isError == true)

    switch result.content.first {
    case .some(.text(let message)):
      #expect(
        message.contains("Arguments for tool multiplication failed parsing and validation.")
      )
    default:
      Issue.record("Expected textual validation error payload")
    }
  }

  @Test("toTool() generates correct schema from @Schemable")
  func toToolProducesValidSchema() throws {
    let tool = MultiplicationTool().toTool()

    #expect(tool.name == "multiplication")
    #expect(tool.description == "Multiply two integers and return the product.")
    #expect(tool.inputSchema != nil)
  }

  @Test("ToolContentBuilder works with string literals")
  func toolContentBuilderWorksWithStrings() async throws {
    let result = try await SimpleBuilderTool().call(arguments: [
      "name": .string("World")
    ])

    #expect(result.isError != true)
    #expect(result.content == [.text("Hello, World!")])
  }

  @Test("call(with:) method works with Content return type")
  func contentForMethodWorks() async throws {
    let result = try await SimpleContentTool().call(arguments: [
      "name": .string("Alice"),
      "enthusiastic": .bool(true),
    ])

    #expect(result.isError != true)
    #expect(result.content == [.text("Hello, Alice!!!")])
  }

  @Test("ToolError provides custom error content")
  func toolErrorProvidesCustomContent() async throws {
    let errorResult = try await ToolErrorTool().call(arguments: [
      "shouldError": .bool(true)
    ])

    #expect(errorResult.isError == true)
    #expect(errorResult.content.count == 2)
    #expect(errorResult.content[0] == .text("Something went wrong"))
    #expect(errorResult.content[1] == .text("Please check your input"))

    let successResult = try await ToolErrorTool().call(arguments: [
      "shouldError": .bool(false)
    ])

    #expect(successResult.isError != true)
    #expect(successResult.content == [.text("Success")])
  }

  @Test("Content builder works with multiple items")
  func contentBuilderWorksWithMultipleItems() async throws {
    let result1 = try await MultiLineContentTool().call(arguments: [
      "lines": .int(1)
    ])

    #expect(result1.isError != true)
    #expect(result1.content.count == 1)
    #expect(result1.content[0] == .text("Line 1"))

    let result2 = try await MultiLineContentTool().call(arguments: [
      "lines": .int(2)
    ])

    #expect(result2.isError != true)
    #expect(result2.content.count == 2)
    #expect(result2.content[0] == .text("Line 1"))
    #expect(result2.content[1] == .text("Line 2"))

    let result3 = try await MultiLineContentTool().call(arguments: [
      "lines": .int(3)
    ])

    #expect(result3.isError != true)
    #expect(result3.content.count == 3)
    #expect(result3.content[0] == .text("Line 1"))
    #expect(result3.content[1] == .text("Line 2"))
    #expect(result3.content[2] == .text("Line 3"))
  }
}
