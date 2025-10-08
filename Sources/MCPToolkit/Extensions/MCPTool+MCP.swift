import Foundation
import JSONSchema
import JSONSchemaBuilder
import MCP

extension MCPTool {
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
