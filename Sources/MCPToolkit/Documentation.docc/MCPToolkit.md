# `MCPToolkit`

Build Model Context Protocol (MCP) tools in Swift using structured concurrency, JSON Schema builders, and the official [`swift-sdk`](https://github.com/modelcontextprotocol/swift-sdk).

## Overview

The MCP specification standardises how AI assistants discover and invoke server-side tools and prompts. This package focuses on the surfaces that server authors most frequently implement:

- `MCPTool` defines a strongly typed contract between your Swift code and `tools/call` requests.
- `Server/register(tools:)` wires those tools into the SDK's `Server` actor so clients can list and execute them.
- `MCPTool/call(arguments:)` bridges raw MCP arguments into validated Swift values using `JSONSchemaBuilder`.
- `MCPPromptTemplate` mirrors this experience for `prompts/get`, providing a message-building DSL and schema-backed validation.

### Why MCPToolkit?

- **Spec-aligned defaults** – input schemas and validation mirror the
  [MCP tools spec](https://spec.modelcontextprotocol.io/specification/2024-11-05/server/tools/).
- **Type-safe ergonomics** – swift-json-schema's builders and macros keep your tool and prompt parameters expressive while avoiding manual JSON parsing and validation.
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

4. **Craft Prompts** with the prompt helpers:

   ```swift
   struct StatusPrompt: MCPPromptTemplate {
     let name = "status-summary"

     @Schemable
     struct Arguments {
       let topic: String
       let includeBlockers: Bool
     }

     func messages(using arguments: Arguments) async throws -> [Prompt.Message] {
       PromptMessages {
         "Summarise the latest progress for \(arguments.topic)."
         if arguments.includeBlockers {
           "List any blockers that need escalation."
         }
         Prompt.Message.assistant("Acknowledged.")
       }
     }
   }
   ```

## Topics

### Core APIs

- `MCPTool`
- `MCPTool/call(arguments:)`
- `MCPTool/toTool()`
- `Server/register(tools:)`
- `MCPPromptTemplate`
- `MCPPromptTemplate/render(arguments:)`
- `PromptMessages(_:)`
- `Server/register(prompts:)`
