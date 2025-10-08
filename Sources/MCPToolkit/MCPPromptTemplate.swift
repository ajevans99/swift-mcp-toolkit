import JSONSchema
import JSONSchemaBuilder
import MCP

/// A typed abstraction over MCP prompt definitions.
///
/// Conformers declare the JSON Schema for their arguments and produce ordered prompt messages
/// when clients issue `prompts/get` requests. This mirrors ``MCPTool`` for tool calls, and
/// enables specification-aligned metadata when responding to `prompts/list`.
public protocol MCPPromptTemplate: Sendable {
  associatedtype Arguments
  associatedtype Schema: JSONSchemaComponent<Arguments>

  /// The unique identifier exposed through `prompts/list`.
  var name: String { get }
  /// An optional natural-language description for the prompt.
  var description: String? { get }

  /// The JSON Schema definition describing the template arguments.
  @JSONSchemaBuilder
  var arguments: Schema { get }

  /// Produce the messages that will be returned to the client.
  ///
  /// - Parameter arguments: Validated arguments that satisfied ``arguments``.
  /// - Returns: A collection of `Prompt.Message` values.
  /// - Throws: Any errors that should surface to the caller as MCP errors.
  func messages(using arguments: Arguments) async throws -> [Prompt.Message]
}

extension MCPPromptTemplate {
  /// Default implementation that omits the description.
  public var description: String? { nil }
}

extension MCPPromptTemplate where Arguments: Schemable, Arguments.Schema.Output == Arguments {
  /// Supplies a schema automatically when ``Arguments`` uses the ``Schemable`` macro.
  public var arguments: some JSONSchemaComponent<Arguments> {
    Arguments.schema
  }
}
