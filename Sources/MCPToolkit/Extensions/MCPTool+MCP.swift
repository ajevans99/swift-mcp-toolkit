import Foundation
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
  /// Any parsing or validation problems are wrapped in a `CallTool.Result` containing
  /// [`Tool.Content.text`](https://github.com/modelcontextprotocol/swift-sdk/blob/main/Sources/MCP/Server/Tools.swift),
  /// matching the expectations laid out in the MCP "Calling Tools" spec.
  ///
  /// - Parameter arguments: The raw JSON-like dictionary the MCP client provided.
  /// - Returns: Either a successful tool result or an error response describing validation issues.
  /// - Throws: Rethrows errors produced by ``MCPTool/call(with:)``.
  /// - SeeAlso: https://modelcontextprotocol.io/specification/2025-06-18/server/tools#calling-tools
  public func call(arguments: [String: MCP.Value]) async throws -> CallTool.Result {
    let object = arguments.mapValues { JSONValue(value: $0) }
    let params: Parameters
    do {
      params = try parameters.parseAndValidate(.object(object))
    } catch ParseAndValidateIssue.parsingFailed(let parseIssues) {
      return .init(
        content: [.text("Failed to parse arguments for tool \(name): \(parseIssues.description)")],
        isError: true
      )
    } catch ParseAndValidateIssue.validationFailed(let validationResult) {
      return .init(
        content: [
          .text(
            "Arguments for tool \(name) failed validation: \(validationResult.prettyJSONString())"
          )
        ],
        isError: true
      )
    } catch ParseAndValidateIssue.parsingAndValidationFailed(let parseErrors, let validationResult)
    {
      return .init(
        content: [
          .text(
            "Arguments for tool \(name) failed parsing and validation. Parsing errors: \(parseErrors.description). Validation errors: \(validationResult.prettyJSONString())"
          )
        ],
        isError: true
      )
    } catch {
      return .init(
        content: [
          .text(
            "Unexpected error occurred while parsing/validating arguments for tool \(name): \(error)"
          )
        ],
        isError: true
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

// MARK: - Error Printing

extension Array where Element == ParseIssue {
  fileprivate var description: String {
    self.map(\.description).joined(separator: "; ")
  }
}

extension ValidationResult {
  fileprivate func prettyJSONString() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(self) else {
      return #"{"error": "failed to encode ValidationResult"}"#
    }
    return String(data: data, encoding: .utf8) ?? #"{"error": "utf8 conversion failed"}"#
  }
}
