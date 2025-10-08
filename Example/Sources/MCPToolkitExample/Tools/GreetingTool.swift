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

  func call(with arguments: Parameters) async throws -> CallTool.Result {
    let greeting = "Hello, \(arguments.name)!"
    return .init(content: [.text(greeting)])
  }
}
