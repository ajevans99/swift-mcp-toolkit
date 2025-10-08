import MCPToolkit

struct WeatherTool: MCPTool {
  let name = "weather"
  let description: String? = "Return the weather for a location"

  @Schemable
  enum Unit {
    case fahrenheit
    case celsius
  }

  @Schemable
  @ObjectOptions(.additionalProperties { false })
  struct Parameters {
    /// Location as city, like "Detroit" or "New York"
    let location: String

    /// Unit for temperature
    let unit: Unit
  }

  func call(with arguments: Parameters) async throws -> CallTool.Result {
    let weather: String

    switch arguments.unit {
    case .fahrenheit:
      weather = "The weather in \(arguments.location) is 75°F and sunny."
    case .celsius:
      weather = "The weather in \(arguments.location) is 24°C and sunny."
    }

    return .init(content: [.text(weather)])
  }
}
