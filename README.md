# swift-mcp-toolkit

[![CI](https://github.com/ajevans99/swift-mcp-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/ajevans99/swift-mcp-toolkit/actions/workflows/ci.yml)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgrey.svg)](https://swift.org)

A toolkit built on top of the [official Swift SDK for Model Context Protocol server and clients](https://github.com/modelcontextprotocol/swift-sdk) that makes it easy to define strongly-typed tools.

## Quick Start

### Step 1: Define a Tool

Conform to `MCPTool`, describe your parameters using the JSONSchemaBuilder or @Schemable from [`swift-json-schema`](https://github.com/ajevans99/swift-json-schema), and implement the `call(with:)` method.

```swift
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
```

### Step 2: Register the Tool with a MCP Server

Create the same `Server` instance you would when using the `swift-sdk`, then call `register(tools:)` with your tool instance(s).

```swift
import MCPToolkit

let server = Server(
  name: "Weather Station",
  version: "1.0.0",
  capabilities: .init(tools: .init(listChanged: true))
)

await server.register(tools: [WeatherTool()])
```

## Running the Example Server with MCP Inspector

[MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector) is an interactive development tool for MCP servers.

To install MCP Inspector, run:

```bash
npm install -g @modelcontextprotocol/inspector
```

Then you can run the [example cli](./Example) with either stdio or HTTP transport modes.

### Stdio

To run the example server with stdio transport, use:

```bash
npx @modelcontextprotocol/inspector@latest swift run OpenAIAppsServer --transport stdio
```

This will start the server and connect it to MCP Inspector.

![MCP Inspector screenshot (STDIO mode)](./docs/images/mcp-inspector-stdio.png)

### HTTP

In HTTP mode, the CLI will spin up a [Vapor web server](https://vapor.codes) (on port 8080 by default) with MCP tools at `/mcp` endpoint.

First start the Vapor server:

```bash
swift run MCPToolkitExample --transport http
```

Then in another terminal, start MCP Inspector and connect to the server:

```bash
npx @modelcontextprotocol/inspector@latest --server-url http://127.0.0.1:8080/mcp --transport http
```

![MCP Inspector screenshot (HTTP mode)](./docs/images/mcp-inspector-http.png)

## Documentation

Full API documentation is available on Swift Package Index [here](https://swiftpackageindex.com/ajevans99.swift-mcp-toolkit).

## Installation

### Swift Package Manager

Add `swift-mcp-toolkit` to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/ajevans99/swift-mcp-toolkit.git", from: "0.1.0")
]
```

Then add the dependency to your target:

```swift
.target(
  name: "YourTarget",
  dependencies: [
    .product(name: "MCPToolkit", package: "swift-mcp-toolkit")
  ]
)
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Resources

- [MCP Official Documentation](https://modelcontextprotocol.io/docs)
- [Example MCP Servers](https://github.com/modelcontextprotocol/servers)
- [Swift SDK - MCP](https://github.com/modelcontextprotocol/swift-sdk)
- [Swift JSON Schema](https://github.com/ajevans99/swift-json-schema)
