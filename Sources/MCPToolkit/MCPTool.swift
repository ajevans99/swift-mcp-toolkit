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
///   func call(with arguments: Parameters) async throws -> CallTool.Result {
///     .init(content: [.text("Hello, \(arguments.name)!")])
///   }
/// }
/// ```
public protocol MCPTool: Sendable {
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
  /// Arbitrary metadata, useful for OpenAI tooling.
  var meta: [String: JSONValue]? { get }

  /// The JSON Schema definition that is published through `tools/list`.
  @JSONSchemaBuilder
  var parameters: Schema { get }

  /// Handle an MCP tool invocation using fully validated arguments.
  ///
  /// - Parameter arguments: The decoded argument payload that satisfied ``parameters``.
  /// - Returns: A `CallTool.Result` containing rich MCP content rendered back to the caller.
  /// - Throws: Any Swift error that should be surfaced to the client as a transport error.
  func call(with arguments: Parameters) async throws -> CallTool.Result
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
}

extension MCPTool where Parameters: Schemable, Parameters.Schema.Output == Parameters {
  /// Provides a synthesized schema for ``Parameters`` when it conforms to ``Schemable``.
  public var parameters: some JSONSchemaComponent<Parameters> {
    Parameters.schema
  }
}
