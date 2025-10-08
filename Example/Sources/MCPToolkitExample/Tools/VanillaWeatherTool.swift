import MCP

/// A hand-rolled weather tool that relies only on the `swift-sdk` primitives.
///
/// This demonstrates the amount of boilerplate required when you are not using `MCPToolkit`.
struct VanillaWeatherTool {
  static let name = "weather"

  static func configure(server: Server) async {
    await server.withMethodHandler(ListTools.self) { _ in
      let tools = [
        Tool(
          name: Self.name,
          description: "Return the weather for a location",
          inputSchema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "properties": .object([
              "location": .object([
                "type": .string("string"),
                "description": .string("Location as city, like \"Detroit\" or \"New York\""),
              ]),
              "unit": .object([
                "type": .string("string"),
                "enum": .array(["fahrenheit", "celsius"].map { .string($0) }),
                "description": .string("Unit for temperature"),
              ]),
            ]),
            "required": .array([.string("location"), .string("unit")]),
          ])
        )
      ]
      return .init(tools: tools)
    }

    await server.withMethodHandler(CallTool.self) { params async in
      guard let arguments = params.arguments else {
        return .init(
          content: [.text("Missing arguments for tool \(Self.name)")],
          isError: true
        )
      }

      guard
        case .string(let location)? = arguments["location"],
        case .string(let unit)? = arguments["unit"]
      else {
        return .init(
          content: [.text("Arguments for tool \(Self.name) failed validation.")],
          isError: true
        )
      }

      let summary: String
      switch unit {
      case "fahrenheit":
        summary = "The weather in \(location) is 75°F and sunny."
      case "celsius":
        summary = "The weather in \(location) is 24°C and sunny."
      default:
        return .init(
          content: [.text("Arguments for tool \(Self.name) failed validation.")],
          isError: true
        )
      }

      return .init(content: [.text(summary)])
    }
  }
}
