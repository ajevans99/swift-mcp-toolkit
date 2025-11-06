/// A strongly typed interface for exposing Swift functions as tools in a Model Context Protocol server.
///
/// Conforming types define the JSON Schema for their expected arguments and map incoming `tools/call`
/// requests into native Swift code. This makes it straightforward to build tools with rich metadata
/// and type safety, while remaining fully compatible with the MCP specification.
///
/// Use the [``JSONSchemaBuilder`` DSL or the ``Schemable`` protocol](https://github.com/ajevans99/swift-json-schema) to describe your parameters.
/// Once registered, the tool’s schema and metadata will be surfaced automatically through
/// `tools/list`, and its handler will be invoked on `tools/call`.
///
/// ```swift
/// struct GreetingTool: MCPTool {
///   let name = "greeting"
///
///   @Schemable
///   struct Parameters {
///     let name: String
///   }
///
///   func call(with arguments: Parameters) async throws -> Content {
///     "Hello, \(arguments.name)!"
///   }
/// }
/// ```
public protocol MCPTool: Sendable {
  /// Type alias for the content produced by the result builder.
  typealias Content = [ToolContentItem]

  /// The strongly typed arguments expected when the tool is invoked via `tools/call`.
  associatedtype Parameters
  /// The JSON Schema builder output describing the `Parameters` shape.
  associatedtype Schema: JSONSchemaComponent<Parameters>

  /// The unique identifier exposed to MCP clients.
  var name: String { get }
  /// An optional natural-language description surfaced through `tools/list`.
  var description: String? { get }
  /// Additional metadata that MCP clients may use when prioritising tools.
  var annotations: Tool.Annotations { get }
  /// Arbitrary metadata, useful for OpenAI tooling. This appears in `tools/list`.
  var meta: [String: JSONValue]? { get }

  /// Optional result-level metadata. Override to provide metadata with each tool call result.
  ///
  /// This metadata is included in the `CallTool.Result` as `_meta` and can be used for:
  /// - Caching hints for the client
  /// - Cost or performance information
  /// - Rate limiting details
  ///
  /// ```swift
  /// var resultMeta: [String: JSONValue]? {
  ///   ["cost": 0.01, "cached": true]
  /// }
  /// ```
  var resultMeta: [String: JSONValue]? { get }

  /// Optional extra fields for the result. Override to provide custom fields with each tool call result.
  ///
  /// These fields are included in the `CallTool.Result` alongside standard fields and can be used
  /// for custom protocol extensions or provider-specific data.
  ///
  /// ```swift
  /// var resultExtraFields: [String: JSONValue]? {
  ///   ["provider": "custom", "requestId": "abc123"]
  /// }
  /// ```
  var resultExtraFields: [String: JSONValue]? { get }

  /// The JSON Schema definition that is published through `tools/list`.
  @JSONSchemaBuilder
  var parameters: Schema { get }

  /// Execute the tool with validated arguments and return content.
  ///
  /// Implement this method to define your tool's behavior:
  ///
  /// ```swift
  /// func call(with arguments: Parameters) async throws -> Content {
  ///   "Hello, \(arguments.name)!"
  /// }
  /// ```
  ///
  /// Any errors thrown from this method will automatically be caught and converted to
  /// error responses with `isError: true`. To provide custom error content, throw a ``ToolError``:
  ///
  /// ```swift
  /// func call(with arguments: Parameters) async throws -> Content {
  ///   guard !arguments.name.isEmpty else {
  ///     throw ToolError {
  ///       "Name cannot be empty"
  ///       "Please provide a valid name"
  ///     }
  ///   }
  ///   return ["Hello, \(arguments.name)!"]
  /// }
  /// ```
  ///
  /// - Parameter arguments: The decoded argument payload that satisfied ``parameters``.
  /// - Returns: Content items to return to the caller.
  /// - Throws: Any Swift error. Use ``ToolError`` for custom error content.
  @ToolContentBuilder
  func call(with arguments: Parameters) async throws(ToolError) -> Content

  /// This is called by the MCP server infrastructure and handles automatic error conversion.
  ///
  /// A default implementation is provided that bridges to ``call(with:)`` and wraps errors.
  ///
  /// - Parameter arguments: The decoded argument payload that satisfied ``parameters``.
  /// - Returns: A structured result containing the tool's output.
  /// - Throws: Can throw errors during tool execution, which are wrapped in the result.
  func callToolResult(with arguments: Parameters) async throws -> CallTool.Result
}

/// An error type that tools can throw to provide custom error content.
///
/// Use this error type when you want to return specific error messages with structured content:
///
/// ```swift
/// func call(with arguments: Parameters) async throws -> Content {
///   guard arguments.value > 0 else {
///     throw ToolError {
///       "Invalid input: value must be positive"
///       "Received: \(arguments.value)"
///     }
///   }
///   return ["Success!"]
/// }
/// ```
public struct ToolError: Error, Sendable {
  /// The error content items to return.
  public let content: [ToolContentItem]

  /// Creates a tool error with declarative content.
  ///
  /// - Parameter content: A result builder that produces the error content.
  public init(@ToolContentBuilder content: () -> [ToolContentItem]) {
    self.content = content()
  }

  /// Creates a tool error with a single text message.
  ///
  /// - Parameter message: The error message.
  public init(_ message: String) {
    self.content = [ToolContentItem(text: message)]
  }
}

extension MCPTool {
  /// This is called by the MCP server infrastructure and handles automatic error conversion.
  public func callToolResult(with arguments: Parameters) async throws -> CallTool.Result {
    do {
      let contentItems = try await call(with: arguments) as Content
      return CallTool.Result(
        content: contentItems.map { $0.toToolContent() },
        _meta: resultMeta?.mapValues { MCP.Value(value: $0) },
        extraFields: resultExtraFields?.mapValues { MCP.Value(value: $0) }
      )
    } catch let error {
      return CallTool.Result(
        content: error.content.map { $0.toToolContent() },
        isError: true,
        _meta: resultMeta?.mapValues { MCP.Value(value: $0) },
        extraFields: resultExtraFields?.mapValues { MCP.Value(value: $0) }
      )
    }
  }
}

extension MCPTool {
  /// Default implementation that emits no description.
  public var description: String? {
    nil
  }

  /// Default implementation that emits no annotations.
  public var annotations: Tool.Annotations {
    nil
  }

  /// Default implementation that emits no metadata.
  public var meta: [String: JSONValue]? {
    nil
  }

  /// Default implementation that emits no result-level metadata.
  public var resultMeta: [String: JSONValue]? {
    nil
  }

  /// Default implementation that emits no extra fields.
  public var resultExtraFields: [String: JSONValue]? {
    nil
  }
}

extension MCPTool where Parameters: Schemable, Parameters.Schema.Output == Parameters {
  /// Provides a synthesized schema for ``Parameters`` when it conforms to ``Schemable``.
  public var parameters: some JSONSchemaComponent<Parameters> {
    Parameters.schema
  }
}

// MARK: - Tool Result Building

/// Represents a single content item for tool results.
///
/// This wrapper type provides a convenient way to construct tool content with string literals
/// while avoiding retroactive conformance issues with the MCP SDK's `Tool.Content` type.
public struct ToolContentItem: Sendable, ExpressibleByStringLiteral,
  ExpressibleByStringInterpolation
{
  private let content: Tool.Content

  /// Creates a text content item.
  public init(text: String) {
    self.content = .text(text)
  }

  /// Creates an image content item.
  public init(imageData: String, mimeType: String, metadata: [String: String]? = nil) {
    self.content = .image(data: imageData, mimeType: mimeType, metadata: metadata)
  }

  /// Creates an audio content item.
  public init(audioData: String, mimeType: String) {
    self.content = .audio(data: audioData, mimeType: mimeType)
  }

  /// Creates an embedded resource content item.
  public init(resourceUri: String, mimeType: String, text: String? = nil) {
    self.content = .resource(uri: resourceUri, mimeType: mimeType, text: text)
  }

  /// Creates content from the underlying MCP type.
  public init(_ content: Tool.Content) {
    self.content = content
  }

  public init(stringLiteral value: String) {
    self.content = .text(value)
  }

  /// Converts to the underlying MCP `Tool.Content` type.
  func toToolContent() -> Tool.Content {
    content
  }
}

/// A result builder for constructing tool call result content declaratively.
///
/// Use this builder to create tool content in a more readable, declarative way:
///
/// ```swift
/// func call(with arguments: Parameters) async throws(ToolError) -> Content {
///   "Hello, \(arguments.name)!"
///
///   if arguments.verbose {
///     "Additional details here"
///   }
///
///   ToolContentItem(imageData: data, mimeType: "image/png")
/// }
/// ```
public typealias ToolContentBuilder = ContentBuilder<ToolContentItem>

extension ContentBuilder where Item == ToolContentItem {
  /// Builds an expression from a `Group` of tool content items.
  public static func buildExpression(_ group: Group<ToolContentItem>) -> [ToolContentItem] {
    [ToolContentItem(text: group.joinedText)]
  }
}
