import Foundation
import JSONSchema
import JSONSchemaBuilder
import MCP

extension MCPPromptTemplate {
  /// Validates raw MCP arguments against the template's schema.
  ///
  /// - Parameter values: The untyped dictionary provided by the MCP client.
  /// - Returns: Strongly typed arguments that passed schema validation.
  /// - Throws: ``MCPError.invalidParams`` when parsing or validation fails.
  func parseArguments(
    from values: [String: MCP.Value]?
  ) throws -> Arguments {
    let object = values?.mapValues { JSONValue(value: $0) } ?? [:]
    let validation = Result { try arguments.parseAndValidate(.object(object)) }
    switch validation {
    case .success(let parsed):
      return parsed
    case .failure(let error):
      guard let issue = error as? ParseAndValidateIssue else { throw error }
      throw MCPError.invalidParams(message(for: issue, promptName: name))
    }
  }

  /// Converts the template into the `swift-sdk` prompt metadata structure.
  public func toPrompt() -> Prompt {
    Prompt(
      name: name,
      description: description,
      arguments: makePromptArguments(schemaValue: arguments.schemaValue)
    )
  }

  /// Renders the prompt for a `prompts/get` request.
  ///
  /// - Parameter values: The argument payload supplied by the client.
  /// - Returns: The message list to send in the response.
  /// - Throws: ``MCPError.invalidParams`` when validation fails or rethrows errors from
  ///   ``messages(using:)``.
  public func render(
    arguments values: [String: MCP.Value]?
  ) async throws -> [Prompt.Message] {
    let parsed = try parseArguments(from: values)
    return try await messages(using: parsed)
  }

  private func makePromptArguments(schemaValue: SchemaValue) -> [Prompt.Argument]? {
    guard
      let object = schemaValue.object,
      let properties = object["properties"]?.object
    else { return nil }

    let requiredNames: Set<String> =
      object["required"]?.array?
      .compactMap(\.string)
      .reduce(into: Set<String>()) { $0.insert($1) }
      ?? []

    let arguments: [Prompt.Argument] = properties.map { key, value in
      let propertyObject = value.object ?? [:]
      let description = propertyObject["description"]?.string
      let required = requiredNames.contains(key)

      return Prompt.Argument(
        name: key,
        description: description,
        required: required
      )
    }

    return arguments.isEmpty ? nil : arguments
  }
}

// MARK: - Error Helpers

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

private func message(for issue: ParseAndValidateIssue, promptName: String) -> String {
  switch issue {
  case .parsingFailed(let parseIssues):
    let details = parseIssues.map(\.description).joined(separator: "; ")
    return "Failed to parse arguments for prompt \(promptName): \(details)"
  case .decodingFailed(let error):
    return "Failed to decode arguments for prompt \(promptName): \(error)"
  case .validationFailed(let validationResult):
    return
      "Arguments for prompt \(promptName) failed validation: \(validationResult.prettyJSONString())"
  case .parsingAndValidationFailed(let parseErrors, let validationResult):
    let details = parseErrors.map(\.description).joined(separator: "; ")
    return
      "Arguments for prompt \(promptName) failed parsing and validation. Parsing errors: \(details). Validation errors: \(validationResult.prettyJSONString())"
  }
}
