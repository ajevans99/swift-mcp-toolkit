import MCPToolkit

struct MathTool: MCPTool {
  enum Operation: String, Sendable, Equatable { case add, sub, mul, div }

  let name = "math"
  let description: String? = "Do basic arithmetic on two numbers."

  var parameters: some JSONSchemaComponent<(Operation, Double, Double)> {
    JSONObject {
      JSONProperty(key: "op") {
        JSONString()
          .enumValues {
            "add"
            "sub"
            "mul"
            "div"
          }
          .compactMap {
            switch $0 {
            case "add": return Operation.add
            case "sub": return Operation.sub
            case "mul": return Operation.mul
            case "div": return Operation.div
            default: return nil
            }
          }
          .description("Operation to perform.")
      }
      .required()

      JSONProperty(key: "a") {
        JSONNumber()
          .maximum(1_000_000)
          .description("First operand.")
      }
      .required()

      JSONProperty(key: "b") {
        JSONNumber()
          .maximum(1_000_000)
          .description("Second operand.")
      }
      .required()
    }
    .additionalProperties(false)
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    let result: Double
    switch arguments.0 {
    case .add: result = arguments.1 + arguments.2
    case .sub: result = arguments.1 - arguments.2
    case .mul: result = arguments.1 * arguments.2
    case .div:
      guard arguments.2 != 0 else {
        throw ToolError("Division by zero is not allowed")
      }
      result = arguments.1 / arguments.2
    }
    return [ToolContentItem(text: String(result))]
  }
}
