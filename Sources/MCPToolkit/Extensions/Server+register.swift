import MCP

extension Server {
  public func register(tools: [any MCPTool]) async {
    self.withMethodHandler(ListTools.self) { _ in
      .init(tools: tools.map { $0.toTool() })
    }

    self.withMethodHandler(CallTool.self) { params async in
      guard let tool = tools.first(where: { $0.name == params.name }) else {
        return .init(
          content: [.text("Unknown tool: \(params.name)")],
          isError: true
        )
      }

      if let arguments = params.arguments {
        do {
          let result = try await tool.call(arguments: arguments)
          return result
        } catch {
          return .init(
            content: [.text("Error occurred while calling tool \(params.name): \(error)")],
            isError: true
          )
        }
      }

      return .init(
        content: [.text("Missing arguments for tool \(params.name)")],
        isError: true
      )
    }
  }
}
