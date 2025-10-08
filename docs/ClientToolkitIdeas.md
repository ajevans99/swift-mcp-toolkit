# Client-Side Ergonomics Roadmap

This note brainstorms ideas for extending `swift-mcp-toolkit` to the client side. The focus is on
small affordances that complement the new prompt + tool helpers, with a nod to larger future
efforts like code generation.

## Principles

- Keep transport and scheduling decisions inside `swift-sdk`; the toolkit should layer convenience
  APIs without hiding the underlying MCP primitives.
- Prefer opt-in wrappers so existing client implementations stay valid.
- Mirror the server-facing abstractions where possible (e.g. reuse `JSONSchemaBuilder` to describe
  expected arguments/results).

## Near-Term Ideas

1. **Typed Tool Calls**
   - Define a protocol such as `MCPClientToolCall` that mirrors ``MCPTool`` but from the caller’s
     perspective (typed request arguments + typed content parsing).
   - Provide a helper on `Client`:
     ```swift
     let result = try await client.invoke(tool: SumTool.self) { builder in
       builder["left"] = 21
       builder["right"] = 21
     }
     ```
   - Use the schema metadata returned by `tools/list` to validate requests locally before sending.

2. **Prompt Invocation Helpers**
   - Introduce a `RenderedPrompt<Arguments>` wrapper so clients can request `prompts/get` with typed
     arguments using the same builder DSL as the server (`PromptMessages`).
   - Automatically substitute default values and surface validation errors as Swift errors before
     the round-trip.

3. **Sampling Payload Builders**
   - Reuse ``PromptMessageBuilder`` to compose `Sampling.Message` payloads. For example:
     ```swift
     let request = SamplingRequest {
       "Summarise the diff"
       Sampling.Message.resource(uri: fileURI)
     }
     try await client.requestSampling(request, metadata: Metadata(...))
     ```
   - Layer schema validation on `CreateSamplingMessage.Parameters.metadata` using
     `JSONSchemaBuilder`.

4. **Client Capability DSL**
   - Similar to server capabilities, offer a builder/macro to describe the features the client
     exposes (e.g. sampling, prompts, logging). This keeps negotiation logic symmetrical between the
     client and server helper APIs.

5. **Observability Hooks**
   - Provide typed events (tool invoked, prompt fetched, sampling requested) that emit structured
     payloads. This makes it easier to integrate with logging systems without handling raw JSON-RPC
     messages.

## Medium-Term Explorations

- **Session Cache**: Cache `tools/list` / `prompts/list` responses and expose typed accessors (e.g.
  `client.availablePrompts["status-summary"]`).
- **Composable Pipelines**: Build higher-level helpers that chain prompt rendering → tool calls →
  sampling in a single ergonomic function, while still exposing underlying MCP messages for
  debugging.
- **Client Test Harness**: Similar to the `TestTransport` created for the server, provide an
  in-memory harness so client integrations can be validated without starting a real server.

## Deferred / Larger Projects

- **Code Generation Build Tool** (separate project):
  - Connect to a running server, fetch schemas (`tools/list`, `prompts/list`, resource templates),
    and generate Swift types + easy-call APIs.
  - Consider a plugin style (`swift package plugin` or dedicated CLI) so the generated code stays in
    sync with the server contract.
  - This work will dovetail nicely with the server-side schema helpers now that tool/prompt
    definitions are strongly typed.

These ideas should be prioritised after we stabilise the prompt APIs just added. Feedback from real
client authors will help pick the first client-centric helper to ship.
