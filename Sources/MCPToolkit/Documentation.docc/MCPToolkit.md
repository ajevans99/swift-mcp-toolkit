# `MCPToolkit`

Build Model Context Protocol (MCP) tools in Swift using structured concurrency, JSON Schema builders, and the official [`swift-sdk`](https://github.com/modelcontextprotocol/swift-sdk).

## Overview

The MCP specification standardises how AI assistants discover and invoke server-side tools. This package focuses on the tooling surface that server authors most frequently implement:

- `MCPTool` defines a strongly typed contract between your Swift code and `tools/call` requests.
- `Server/register(tools:messaging:)` wires those tools into the SDK's `Server` actor so clients can list and execute them, while exposing hooks for customising toolkit-managed responses.
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

2. **Register Tools** on your `Server` and optionally tailor messaging:

   ```swift
   let server = Server(
     name: "Weather Station",
     version: "1.0.0",
     capabilities: .init(tools: .init(listChanged: true))
   )

   await server.register(
     tools: [WeatherTool()],
     messaging: ResponseMessagingFactory.defaultWithOverrides { overrides in
       overrides.toolThrew = { context in
         CallTool.Result(
           content: [
             .text("Weather machine failure: \(context.error.localizedDescription)")
           ],
           isError: true
         )
       }
     }
   )
   ```

3. **Respond to Clients** – incoming `tools/call` requests are parsed, validated, and routed without additional glue code.

### Resources

MCP Resources let servers expose data that clients can read. Define resources using the `MCPResource` protocol and the `@ResourceContentBuilder`:

```swift
struct DocumentationResource: MCPResource {
  let uri = "docs://api/overview"
  let name: String? = "API Overview"
  let description: String? = "Complete API documentation"
  let mimeType: String? = "text/markdown"

  var content: Content {
    """
    # API Documentation
    
    Welcome to our API!
    """
  }
}
```

For multiple content blocks with different MIME types, use `Group`:

```swift
struct HTMLPageResource: MCPResource {
  let uri = "ui://widget/page.html"
  let name: String? = "Widget Page"

  var content: Content {
    Group {
      "<!DOCTYPE html>"
      "<html><body>Hello!</body></html>"
    }
    .mimeType("text/html")
    
    Group(separator: " ") {
      ".widget { color: blue; }"
    }
    .mimeType("text/css")
  }
}
```

Register resources on your server:

```swift
let server = Server(
  name: "Documentation Server",
  version: "1.0.0",
  capabilities: .init(resources: .init(listChanged: true))
)

await server.register(resources: [
  DocumentationResource(),
  HTMLPageResource()
])
```

## Topics

### Core APIs

- `MCPTool`
- `MCPTool/call(arguments:)`
- `MCPTool/toTool()`
- `Server/register(tools:messaging:)`
- ``ResponseMessaging``
- ``DefaultResponseMessaging``
- ``ResponseMessagingFactory``

### Resources

- `MCPResource`
- `MCPResource/content`
- `ResourceContentItem`
- `Group`
- `Server/register(resources:)`
