# JSON Schema Builder Expansion Ideas

This document sketches where JSON Schema helpers could make the Model Context Protocol
(`swift-sdk`) more ergonomic beyond tool registration. The intent is to tease out high–leverage
APIs that feel as lightweight as ``MCPTool`` while covering the other MCP surfaces: resources,
prompts, notifications, and sampling.

## Goals

- Treat JSON Schema authoring as an implementation detail. Package authors should describe their
  data using Swift types and get request/response validation for free.
- Align strongly with the MCP specification so that generated schemas and runtime behaviour stay
  compliant.
- Create room for shared helpers (e.g. DocC snippets, integration tests) that compare the “vanilla”
  `swift-sdk` experience with the builder-based one.

## Candidate Surfaces

### 1. Resources

**Spec reference:**  
<https://spec.modelcontextprotocol.io/specification/2024-11-05/server/resources/>

**Pain today**
- Resource `metadata` is an untyped `[String: String]?`. Servers hand–roll validation and lack a
  single source of truth for describing those fields.
- Templates (`Resource.Template`) often need argument schemas so clients can provide URI inputs, but
  the spec only gives us strings.

**Proposed direction**

Create an `MCPResourceDescriptor` protocol mirroring `MCPTool`:

```swift
public protocol MCPResourceDescriptor: Sendable {
  associatedtype Metadata

  var resource: Resource { get }

  @JSONSchemaBuilder
  var metadataSchema: some JSONSchemaComponent<Metadata> { get }

  func listMetadata() -> Metadata
  func read() async throws -> Resource.Content
}
```

Servers could register descriptors to:

- auto-generate `resources/list` metadata by calling `listMetadata()` and encoding it with
  the schema’s output;
- provide typed URI template arguments (think `ProjectFile.ResourceArguments` that validates
  branch + path).

**Example sketch**

```swift
struct ProjectReadme: MCPResourceDescriptor {
  struct Metadata {
    let repo: String
    let branch: String
  }

  let repository: GitRepository

  var resource: Resource {
    Resource(
      name: "Project README",
      uri: "project://\(repository.name)/README.md",
      mimeType: "text/markdown"
    )
  }

  var metadataSchema: some JSONSchemaComponent<Metadata> {
    JSONObject {
      JSONProperty(key: "repo") { JSONString().description("Repository name") }.required()
      JSONProperty(key: "branch") { JSONString().defaultValue("main") }
    }
    .map(Metadata.init(repo:branch:))
  }

  func listMetadata() -> Metadata {
    Metadata(repo: repository.name, branch: repository.defaultBranch)
  }

  func read() async throws -> Resource.Content {
    .text(
      try await repository.readFile(path: "README.md", branch: repository.defaultBranch),
      uri: resource.uri,
      mimeType: resource.mimeType
    )
  }
}
```

### 2. Prompts *(implemented in MCPToolkit)*

**Spec reference:**  
<https://spec.modelcontextprotocol.io/specification/2024-11-05/server/prompts/>

**Pain today**
- Prompt arguments are declared as `[Prompt.Argument]` where `required` is just an optional Bool.
- There is no first-class support for validating the payload that a client provides before building
  `Prompt.Message` content.

**Proposed direction**

Introduce an `MCPPromptTemplate` protocol with a builder that yields messages from typed arguments:

```swift
public protocol MCPPromptTemplate: Sendable {
  associatedtype Arguments

  var prompt: Prompt { get }

  @JSONSchemaBuilder
  var argumentsSchema: some JSONSchemaComponent<Arguments> { get }

  @PromptMessageBuilder
  func makeMessages(using arguments: Arguments) -> [Prompt.Message]
}
```

The `@PromptMessageBuilder` result builder could let authors mix message roles and resource links
without manual array construction:

```swift
struct StandupPrompt: MCPPromptTemplate {
  struct Arguments {
    let yesterday: String
    let today: String
    let blockers: String?
  }

  var prompt: Prompt {
    Prompt(
      name: "daily-standup",
      description: "Collect an async daily update in the team's tone."
    )
  }

  var argumentsSchema: some JSONSchemaComponent<Arguments> {
    JSONObject {
      JSONProperty(key: "yesterday") { JSONString().minLength(4) }.required()
      JSONProperty(key: "today") { JSONString().minLength(4) }.required()
      JSONProperty(key: "blockers") { JSONString().nullable() }
    }
    .map(Arguments.init(yesterday:today:blockers:))
  }

  func makeMessages(using arguments: Arguments) -> [Prompt.Message] {
    Prompt {
      .system("You're a helpful project bot.")
      .user("""
        Yesterday: \(arguments.yesterday)
        Today: \(arguments.today)
        Blockers: \(arguments.blockers ?? "None")
        """)
    }
  }
}
```

The registration helper translates the schema into the existing `Prompt.Argument` array for
`prompts/list`, and exposes a typed `render(arguments:)` API that validates inputs. This is now
available in `MCPPromptTemplate` + `PromptMessages`.

### 3. Sampling (server → client requests)

**Spec reference:**  
<https://modelcontextprotocol.io/docs/concepts/sampling>

**Pain today**
- `CreateSamplingMessage.Parameters.metadata` is `[String: Value]?` with no guidance on shape.
- Building `Sampling.Message` arrays for contextual prompts is verbose.

**Proposed direction**

1. Provide Schemable-friendly wrappers for metadata dictionaries so developers can describe the
   payload.
2. Add a `@SamplingMessageBuilder` result builder that composes message sequences:

```swift
struct CompletionRequestMetadata: Schemable {
  let tone: String
  let maxChapters: Int
}

let metadata = try CompletionRequestMetadata.schema.parseAndValidate(.object(objectValue))
```

```swift
let messages = SamplingMessages {
  Sampling.Message(.system("Summarise the document."))
  Sampling.Message(.userText(context))
  Sampling.Message(.assistantResource(uri: docURI))
}
```

3. When `requestSampling` is eventually implemented on the server, we can layer helpers that convert
   these builders into the SDK’s `Sampling.Message` values.

### 4. Notifications & Custom Methods

**Spec reference:**  
Custom notifications are encouraged in the spec; see the “Extending MCP” guidance.

**Pain today**
- Servers that extend MCP invent their own request/response pairs with arbitrary JSON payloads.
  There’s no ergonomic path to document or validate these messages.

**Proposed direction**

Add lightweight wrappers to `swift-sdk` such as:

```swift
public protocol MCPNotification: Sendable {
  static var name: String { get }

  associatedtype Parameters

  @JSONSchemaBuilder
  static var schema: some JSONSchemaComponent<Parameters> { get }

  static func message(_ parameters: Parameters) throws -> Message<Self>
}
```

That schema would power DocC, sample code, and runtime validation (mirroring how `MCPTool` handles
arguments). For requests, mirror the pattern with an `MCPMethod` protocol.

### 5. Capability Negotiation

Server and client capabilities are currently plain structs with optional fields such as
`Server.Capabilities.Tools(listChanged: Bool?)`.

**Opportunity**
- Offer a builder or macro that synthesises the capability struct while producing a schema that can
  surface “what this server actually supports” in documentation.
- Potential extension: allow capability payloads to declare feature flags that show up in `tools`
  or `resources` metadata.

## Implementation Roadmap

1. **Prototype Resource descriptors**
   - Define `MCPResourceDescriptor`.
   - Update example package with a typed resource to verify ergonomics.
   - Provide migrations showing parity with the vanilla SDK.

2. **Prompt template builders**
   - Design the `@PromptMessageBuilder` DSL.
   - Bridge to `Prompt.Argument` and `Prompt.Message`.
   - Add integration tests that render prompts with invalid arguments (similar to the tool tests).

3. **Sampling helpers**
   - Shape metadata parsing with `JSONSchemaBuilder`.
   - Experiment with message builders that cover text/audio/resource content.

4. **Notification & custom method support**
   - Generalise parsing/validation flow from `MCPTool.call(arguments:)`.
   - Provide `Server.register(notificationHandlers:)` convenience that consumes the new protocol.

5. **Capability DSL**
   - Evaluate whether a macro or builder is the smoothest option.
   - Wire through to `Server.Info` / `Server.Capabilities`.

Each step should keep parity with the spec and include DocC pages that explain the “vanilla vs
builder” story (mirroring the Weather tool example we added to the README).

## Testing Strategy

- Mirror the existing tool tests: unit tests that assert schema generation + integration tests that
  run against a `TestTransport`.
- Add DocC tutorials that synchronise with README snippets.
- Long term, contribute upstream to `swift-sdk` so these helpers ship alongside the official types.

## Open Questions

- How much of this belongs in `swift-mcp-toolkit` vs. the upstream `swift-sdk`?
- Are there opportunities for Swift macros (e.g. `@MCPPrompt`) similar to `@Schemable` to eliminate
  boilerplate further?
- Should schemas for tool outputs (`CallTool.Result.content`) also be builder-driven so clients can
  reason about the shape of responses?

These are intentionally exploratory; feedback from the MCP community will help prioritise the most
useful ergonomics first.
