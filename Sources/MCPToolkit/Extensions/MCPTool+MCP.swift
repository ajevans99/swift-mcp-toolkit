import JSONSchema
import JSONSchemaBuilder
import MCP

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
  /// - Throws: Rethrows errors produced by ``MCPTool/call(with:)``.
  /// - SeeAlso: https://modelcontextprotocol.io/specification/2025-06-18/server/tools#calling-tools
  public func call<M: ResponseMessaging>(
    arguments: [String: MCP.Value],
    messaging: M = DefaultResponseMessaging()
  ) async throws -> CallTool.Result {
    let object = arguments.mapValues { JSONValue(value: $0) }
    let params: Parameters
    do {
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
    return try await call(with: params)
  }
}

extension MCPTool {
  /// Creates the `swift-sdk` representation of the tool for `tools/list` responses.
  ///
  /// - Returns: A configured ``MCP/Tool`` populated with the tool's metadata and JSON Schema.
  /// - SeeAlso: https://modelcontextprotocol.io/specification/2025-06-18/server/tools#listing-tools
  public func toTool() -> Tool {
    Tool(
      name: name,
      description: description,
      inputSchema: .init(schemaValue: parameters.schemaValue),
      annotations: annotations
    )
  }
}
