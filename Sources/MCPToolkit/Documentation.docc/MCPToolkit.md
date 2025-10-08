# `MCPToolkit`

Build Model Context Protocol (MCP) tools in Swift using structured concurrency, JSON Schema builders, and the official [`swift-sdk`](https://github.com/modelcontextprotocol/swift-sdk).

## Overview

The MCP specification standardises how AI assistants discover and invoke server-side tools. This package focuses on the tooling surface that server authors most frequently implement:

- `MCPTool` defines a strongly typed contract between your Swift code and `tools/call` requests.
- `Server/register(tools:)` wires those tools into the SDK's `Server` actor so clients can list and execute them.
- `MCPTool/call(arguments:)` bridges raw MCP arguments into validated Swift values using `JSONSchemaBuilder`.

### Why MCPToolkit?

- **Spec-aligned defaults** – input schemas and validation mirror the
  [MCP tools spec](https://spec.modelcontextprotocol.io/specification/2024-11-05/server/tools/).
- **Type-safe ergonomics** – swift-json-schema's builders and macros keeps your tool parameters expressive while avoiding manual JSON parsing and validation.
- **Concurrency-first** – tools are `Sendable` and embrace Swift's `async`/`await`.

### How to Adopt

1. **Describe Parameters** using the schema builder:

   ```swift
   struct WeatherTool: MCPTool {
     let name = "weather"

     @Schemable
     struct Parameters {
       let city: String
       let useMetric: Bool
     }

     func call(with arguments: Parameters) async throws -> CallTool.Result {
       let summary = try await fetchWeather(for: arguments.city, metric: arguments.useMetric)
       return .init(content: [.text(summary)])
     }
   }
   ```

2. **Register Tools** on your `Server`:

   ```swift
   let server = Server(
     name: "Weather Station",
     version: "1.0.0",
     capabilities: .init(tools: .init(listChanged: true))
   )

   await server.register(tools: [WeatherTool()])
   ```

3. **Respond to Clients** – incoming `tools/call` requests are parsed, validated, and routed without additional glue code.

## Topics

### Core APIs

- `MCPTool`
- `MCPTool/call(arguments:)`
- `MCPTool/toTool()`
- `Server/register(tools:)`
