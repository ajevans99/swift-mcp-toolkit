import Foundation
import MCPToolkit
import Testing

struct AdditionTool: MCPTool {
  let name = "addition"
  let description: String? = "Add two integers and return the sum."

  struct Parameters: Sendable {
    let left: Int
    let right: Int
  }

  var parameters: some JSONSchemaComponent<Parameters> {
    JSONObject {
      JSONProperty(key: "left") {
        JSONInteger()
      }
      .required()

      JSONProperty(key: "right") {
        JSONInteger()
      }
      .required()
    }
    .map { values in
      Parameters(left: values.0, right: values.1)
    }
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    let sum = arguments.left + arguments.right
    "\(sum)"
  }
}

@Suite("MCPTool bridging")
struct MCPToolkitUnitTests {
  @Test("call(arguments:) maps JSON values into typed parameters")
  func callSucceedsWithValidSchema() async throws {
    let result = try await AdditionTool().call(arguments: [
      "left": .int(21),
      "right": .int(21),
    ])

    #expect(result.isError != true)
    #expect(result.content == [.text("42")])
  }

  @Test("call(arguments:) reports schema violations instead of throwing")
  func callSurfacesValidationIssue() async throws {
    let result = try await AdditionTool().call(arguments: [
      "left": .int(21)
      // Missing "right" value triggers a validation failure
    ])

    #expect(result.isError == true)

    switch result.content.first {
    case .some(.text(let message)):
      #expect(
        message.contains("Arguments for tool addition failed parsing and validation.")
      )
    default:
      Issue.record("Expected textual validation error payload")
    }
  }
}
