import MCPToolkit

func makeMCPServer() async -> Server {
  let server = Server(
    name: "MCPToolkit Example Server",
    version: "0.1.0",
    capabilities: .init(tools: .init(listChanged: true))
  )

  await server.register(tools: [
    GreetingTool(),
    MathTool(),
    WeatherTool(),
  ])

  return server
}
