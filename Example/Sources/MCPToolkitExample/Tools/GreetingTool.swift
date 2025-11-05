import MCPToolkit

struct GreetingTool: MCPTool {
  let name = "greeter"
  let description: String? = "Return a friendly greeting from the OpenAIApps module."

  @Schemable
  @ObjectOptions(.additionalProperties { false })
  struct Parameters {
    /// Name to greet
    let name: String
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    "Hello, \(arguments.name)!"
  }
}
