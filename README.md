# swift-mcp-toolkit

[![CI](https://github.com/ajevans99/swift-mcp-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/ajevans99/swift-mcp-toolkit/actions/workflows/ci.yml)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgrey.svg)](https://swift.org)

A toolkit built on top of the [official Swift SDK for Model Context Protocol server and clients](https://github.com/modelcontextprotocol/swift-sdk) that makes it easy to define strongly-typed tools.

## Quick Start

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

### HTTP

In HTTP mode, the CLI will spin up a [Vapor web server](https://vapor.codes) (on port 8080 by default) with MCP tools at `/mcp` endpoint.

First start the Vapor server:

```bash
swift run MCPToolkitExample --transport http
```

Then in another terminal, start MCP Inspector and connect to the server:

```bash
npx @modelcontextprotocol/inspector@latest


```

## Documentation

Full API documentation is available on Swift Package Index [here](https://swiftpackageindex.com/ajevans99.swift-mcp-toolkit).

## Installation

### Swift Package Manager

Add `swift-mcp-toolkit` to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/ajevans99/swift-mcp-toolkit.git", from: "1.0.0")
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

- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io)
- [MCP Official Documentation](https://modelcontextprotocol.io/docs)
- [Example MCP Servers](https://github.com/modelcontextprotocol/servers)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)

## Related Projects

- [anthropic/mcp](https://github.com/anthropic/mcp) - Official MCP implementations
- [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) - Example MCP servers
