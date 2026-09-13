import JSONSchema
import JSONSchemaBuilder
import MCP
import OrderedCollections

extension MCPTool {
  /// Converts raw MCP argument values into the strongly typed ``MCPTool/Parameters`` payload.
  ///
  /// This helper is invoked by the `Server.register(tools:)` integration to:
  /// 1. Transform the `[String: MCP.Value]` arguments from `swift-sdk` into ``JSONValue``.
  /// 2. Parse and validate them against the tool's declared schema.
  /// 3. Forward the confirmed payload into ``MCPTool/call(with:)``.
  ///
  /// Any parsing or validation problems are routed through the provided ``ResponseMessaging``
  /// implementation, allowing callers to customize every surface returned to the model.
  ///
  /// - Parameters:
  ///   - arguments: The raw JSON-like dictionary the MCP client provided.
  ///   - messaging: The response messaging provider that should format any failures. Defaults to
  ///     ``DefaultResponseMessaging`` to preserve the toolkit's existing behaviour.
  /// - Returns: Either a successful tool result or an error response describing validation issues.
  /// - Throws: Rethrows errors from result construction, including numeric metadata conversion.
  /// - SeeAlso: https://modelcontextprotocol.io/specification/2025-06-18/server/tools#calling-tools
  public func call<M: ResponseMessaging>(
    arguments: [String: MCP.Value],
    messaging: M = DefaultResponseMessaging()
  ) async throws -> CallTool.Result {
    let params: Parameters
    do {
      let object = try OrderedDictionary(
        uniqueKeysWithValues: arguments.map { ($0.key, try JSONValue(value: $0.value)) }
      )
      params = try parameters.parseAndValidate(.object(object))
    } catch ParseAndValidateIssue.parsingFailed(let parseIssues) {
      return messaging.parsingFailed(
        .init(toolName: name, issues: parseIssues)
      )
    } catch ParseAndValidateIssue.validationFailed(let validationResult) {
      return messaging.validationFailed(
        .init(toolName: name, result: validationResult)
      )
    } catch ParseAndValidateIssue.parsingAndValidationFailed(let parseErrors, let validationResult)
    {
      return messaging.parsingAndValidationFailed(
        .init(
          toolName: name,
          parseIssues: parseErrors,
          validationResult: validationResult
        )
      )
    } catch {
      return messaging.unexpectedError(
        .init(toolName: name, error: error)
      )
    }
    let result = try await callToolResult(with: params)
    if let structuredTool = self as? any MCPToolWithStructuredOutput {
      return structuredTool.validateStructuredOutputResult(
        result,
        messaging: messaging
      )
    }
    return result
  }
}

extension MCPTool {
  /// Creates the `swift-sdk` representation of the tool for `tools/list` responses.
  ///
  /// - Returns: A configured ``MCP/Tool`` populated with the tool's metadata and JSON Schema.
  /// - Throws: A ``JSONNumberLiteral/ConversionError`` if schema or metadata numbers cannot
  ///   be represented by MCP without changing their decimal value.
  /// - SeeAlso: https://modelcontextprotocol.io/specification/2025-06-18/server/tools#listing-tools
  public func toTool() throws -> Tool {
    let outputSchemaValue: MCP.Value?
    if let structuredTool = self as? any MCPToolWithStructuredOutput {
      outputSchemaValue = try MCP.Value(schemaValue: structuredTool.outputSchemaValue)
    } else {
      outputSchemaValue = nil
    }
    return try Tool(
      name: name,
      title: nil,
      description: description,
      inputSchema: .init(schemaValue: parameters.schemaValue),
      annotations: annotations,
      outputSchema: outputSchemaValue,
      _meta: meta.metadata
    )
  }
}
