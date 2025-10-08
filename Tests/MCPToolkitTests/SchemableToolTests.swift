import Foundation
import Logging
import Testing

@testable import MCPToolkit

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

  func call(with arguments: Parameters) async throws -> CallTool.Result {
    let product = arguments.multiplicand * arguments.multiplier
    return .init(content: [.text("\(product)")])
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
}
