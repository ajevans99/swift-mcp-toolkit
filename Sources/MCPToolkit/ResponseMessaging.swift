import Foundation
import JSONSchema
import MCP

/// Describes the set of toolkit-managed responses that can be customized by callers.
public protocol ResponseMessaging: Sendable {
  func unknownTool(_ context: ResponseMessagingUnknownToolContext) -> CallTool.Result
  func missingArguments(_ context: ResponseMessagingMissingArgumentsContext) -> CallTool.Result
  func toolThrew(_ context: ResponseMessagingToolErrorContext) -> CallTool.Result
  func parsingFailed(_ context: ResponseMessagingParsingFailedContext) -> CallTool.Result
  func validationFailed(_ context: ResponseMessagingValidationFailedContext) -> CallTool.Result
  func parsingAndValidationFailed(
    _ context: ResponseMessagingParsingAndValidationFailedContext
  ) -> CallTool.Result
  func unexpectedError(_ context: ResponseMessagingUnexpectedErrorContext) -> CallTool.Result
  func structuredOutputInvalid(
    _ context: ResponseMessagingStructuredOutputInvalidContext
  ) -> CallTool.Result
}

/// Provides the default set of toolkit responses
public struct DefaultResponseMessaging: ResponseMessaging {
  public init() {}

  public func unknownTool(_ context: ResponseMessagingUnknownToolContext) -> CallTool.Result {
    .init(
      content: [.text("Unknown tool: \(context.requestedName)")],
      isError: true
    )
  }

  public func missingArguments(
    _ context: ResponseMessagingMissingArgumentsContext
  ) -> CallTool.Result {
    .init(
      content: [.text("Missing arguments for tool \(context.toolName)")],
      isError: true
    )
  }

  public func toolThrew(_ context: ResponseMessagingToolErrorContext) -> CallTool.Result {
    .init(
      content: [
        .text("Error occurred while calling tool \(context.toolName): \(context.error)")
      ],
      isError: true
    )
  }

  public func parsingFailed(
    _ context: ResponseMessagingParsingFailedContext
  ) -> CallTool.Result {
    let issues = context.issues.map(\.description).joined(separator: "; ")
    return .init(
      content: [
        .text("Failed to parse arguments for tool \(context.toolName): \(issues)")
      ],
      isError: true
    )
  }

  public func validationFailed(
    _ context: ResponseMessagingValidationFailedContext
  ) -> CallTool.Result {
    .init(
      content: [
        .text(
          "Arguments for tool \(context.toolName) failed validation: \(context.result.prettyJSONString())"
        )
      ],
      isError: true
    )
  }

  public func parsingAndValidationFailed(
    _ context: ResponseMessagingParsingAndValidationFailedContext
  ) -> CallTool.Result {
    let parseIssues = context.parseIssues.map(\.description).joined(separator: "; ")
    let validation = context.validationResult.prettyJSONString()
    return .init(
      content: [
        .text(
          "Arguments for tool \(context.toolName) failed parsing and validation. Parsing errors: \(parseIssues). Validation errors: \(validation)"
        )
      ],
      isError: true
    )
  }

  public func unexpectedError(
    _ context: ResponseMessagingUnexpectedErrorContext
  ) -> CallTool.Result {
    .init(
      content: [
        .text(
          "Unexpected error occurred while parsing/validating arguments for tool \(context.toolName): \(context.error)"
        )
      ],
      isError: true
    )
  }

  public func structuredOutputInvalid(
    _ context: ResponseMessagingStructuredOutputInvalidContext
  ) -> CallTool.Result {
    let message: String
    switch context.issue {
    case .decodingFailed(let error):
      message =
        "Failed to decode structured output for tool \(context.toolName): \(error.localizedDescription)"
    case .parsingFailed(let issues):
      let joined = issues.map(\.description).joined(separator: "; ")
      message =
        "Structured output for tool \(context.toolName) failed parsing: \(joined)"
    case .validationFailed(let validationResult):
      message =
        "Structured output for tool \(context.toolName) failed validation: \(validationResult.prettyJSONString())"
    case .parsingAndValidationFailed(let parseIssues, let validationResult):
      let joined = parseIssues.map(\.description).joined(separator: "; ")
      message =
        """
        Structured output for tool \(context.toolName) failed parsing and validation. Parsing errors: \(joined). Validation errors: \(validationResult.prettyJSONString())
        """
    }

    return .init(
      content: [.text(message)],
      isError: true
    )
  }
}

/// A convenience factory that allows callers to override a subset of messaging behaviours.
public enum ResponseMessagingFactory {
  /// Mutable container for configuring response overrides.
  public struct Overrides: Sendable {
    public typealias Handler<Context> = @Sendable (Context) -> CallTool.Result

    public var unknownTool: Handler<ResponseMessagingUnknownToolContext>?
    public var missingArguments: Handler<ResponseMessagingMissingArgumentsContext>?
    public var toolThrew: Handler<ResponseMessagingToolErrorContext>?
    public var parsingFailed: Handler<ResponseMessagingParsingFailedContext>?
    public var validationFailed: Handler<ResponseMessagingValidationFailedContext>?
    public var parsingAndValidationFailed:
      Handler<ResponseMessagingParsingAndValidationFailedContext>?
    public var unexpectedError: Handler<ResponseMessagingUnexpectedErrorContext>?
    public var structuredOutputInvalid:
      Handler<ResponseMessagingStructuredOutputInvalidContext>?

    public init() {}
  }

  /// Creates a response messaging implementation starting from ``DefaultResponseMessaging``
  /// and applying the provided overrides.
  public static func defaultWithOverrides(
    _ configure: (inout Overrides) -> Void
  ) -> some ResponseMessaging {
    var overrides = Overrides()
    configure(&overrides)

    let base = DefaultResponseMessaging()
    return ClosureResponseMessaging(
      unknownTool: overrides.unknownTool ?? base.unknownTool,
      missingArguments: overrides.missingArguments ?? base.missingArguments,
      toolThrew: overrides.toolThrew ?? base.toolThrew,
      parsingFailed: overrides.parsingFailed ?? base.parsingFailed,
      validationFailed: overrides.validationFailed ?? base.validationFailed,
      parsingAndValidationFailed: overrides.parsingAndValidationFailed
        ?? base.parsingAndValidationFailed,
      unexpectedError: overrides.unexpectedError ?? base.unexpectedError,
      structuredOutputInvalid:
        overrides.structuredOutputInvalid ?? base.structuredOutputInvalid
    )
  }
}

private struct ClosureResponseMessaging: ResponseMessaging {
  typealias Handler<Context> = @Sendable (Context) -> CallTool.Result

  let unknownToolHandler: Handler<ResponseMessagingUnknownToolContext>
  let missingArgumentsHandler: Handler<ResponseMessagingMissingArgumentsContext>
  let toolThrewHandler: Handler<ResponseMessagingToolErrorContext>
  let parsingFailedHandler: Handler<ResponseMessagingParsingFailedContext>
  let validationFailedHandler: Handler<ResponseMessagingValidationFailedContext>
  let parsingAndValidationFailedHandler: Handler<ResponseMessagingParsingAndValidationFailedContext>
  let unexpectedErrorHandler: Handler<ResponseMessagingUnexpectedErrorContext>
  let structuredOutputInvalidHandler: Handler<ResponseMessagingStructuredOutputInvalidContext>

  init(
    unknownTool: @escaping Handler<ResponseMessagingUnknownToolContext>,
    missingArguments: @escaping Handler<ResponseMessagingMissingArgumentsContext>,
    toolThrew: @escaping Handler<ResponseMessagingToolErrorContext>,
    parsingFailed: @escaping Handler<ResponseMessagingParsingFailedContext>,
    validationFailed: @escaping Handler<ResponseMessagingValidationFailedContext>,
    parsingAndValidationFailed:
      @escaping Handler<
        ResponseMessagingParsingAndValidationFailedContext
      >,
    unexpectedError: @escaping Handler<ResponseMessagingUnexpectedErrorContext>,
    structuredOutputInvalid:
      @escaping Handler<ResponseMessagingStructuredOutputInvalidContext>
  ) {
    self.unknownToolHandler = unknownTool
    self.missingArgumentsHandler = missingArguments
    self.toolThrewHandler = toolThrew
    self.parsingFailedHandler = parsingFailed
    self.validationFailedHandler = validationFailed
    self.parsingAndValidationFailedHandler = parsingAndValidationFailed
    self.unexpectedErrorHandler = unexpectedError
    self.structuredOutputInvalidHandler = structuredOutputInvalid
  }

  func unknownTool(_ context: ResponseMessagingUnknownToolContext) -> CallTool.Result {
    unknownToolHandler(context)
  }

  func missingArguments(
    _ context: ResponseMessagingMissingArgumentsContext
  ) -> CallTool.Result {
    missingArgumentsHandler(context)
  }

  func toolThrew(_ context: ResponseMessagingToolErrorContext) -> CallTool.Result {
    toolThrewHandler(context)
  }

  func parsingFailed(
    _ context: ResponseMessagingParsingFailedContext
  ) -> CallTool.Result {
    parsingFailedHandler(context)
  }

  func validationFailed(
    _ context: ResponseMessagingValidationFailedContext
  ) -> CallTool.Result {
    validationFailedHandler(context)
  }

  func parsingAndValidationFailed(
    _ context: ResponseMessagingParsingAndValidationFailedContext
  ) -> CallTool.Result {
    parsingAndValidationFailedHandler(context)
  }

  func unexpectedError(
    _ context: ResponseMessagingUnexpectedErrorContext
  ) -> CallTool.Result {
    unexpectedErrorHandler(context)
  }

  func structuredOutputInvalid(
    _ context: ResponseMessagingStructuredOutputInvalidContext
  ) -> CallTool.Result {
    structuredOutputInvalidHandler(context)
  }
}

// MARK: - Context Types

public struct ResponseMessagingUnknownToolContext: Sendable {
  /// The tool name requested by the client.
  public let requestedName: String

  public init(requestedName: String) {
    self.requestedName = requestedName
  }
}

public struct ResponseMessagingMissingArgumentsContext: Sendable {
  /// The tool whose invocation was missing arguments.
  public let toolName: String

  public init(toolName: String) {
    self.toolName = toolName
  }
}

public struct ResponseMessagingToolErrorContext: Sendable {
  /// The tool whose invocation threw an error.
  public let toolName: String
  /// The thrown error.
  public let error: any Error

  public init(toolName: String, error: any Error) {
    self.toolName = toolName
    self.error = error
  }
}

public struct ResponseMessagingParsingFailedContext: Sendable {
  /// The tool whose arguments failed to parse.
  public let toolName: String
  /// The issues emitted by the parser.
  public let issues: [ParseIssue]

  public init(toolName: String, issues: [ParseIssue]) {
    self.toolName = toolName
    self.issues = issues
  }
}

public struct ResponseMessagingValidationFailedContext: Sendable {
  /// The tool whose arguments failed validation.
  public let toolName: String
  /// The validation result describing the failure.
  public let result: ValidationResult

  public init(toolName: String, result: ValidationResult) {
    self.toolName = toolName
    self.result = result
  }
}

public struct ResponseMessagingParsingAndValidationFailedContext: Sendable {
  /// The tool whose arguments failed both parsing and validation.
  public let toolName: String
  /// The parsing issues encountered.
  public let parseIssues: [ParseIssue]
  /// The validation failures encountered.
  public let validationResult: ValidationResult

  public init(
    toolName: String,
    parseIssues: [ParseIssue],
    validationResult: ValidationResult
  ) {
    self.toolName = toolName
    self.parseIssues = parseIssues
    self.validationResult = validationResult
  }
}

public struct ResponseMessagingStructuredOutputInvalidContext: Sendable {
  /// The tool whose structured output failed validation.
  public let toolName: String
  /// The parse or validation issue that occurred.
  public let issue: ParseAndValidateIssue

  public init(toolName: String, issue: ParseAndValidateIssue) {
    self.toolName = toolName
    self.issue = issue
  }
}

public struct ResponseMessagingUnexpectedErrorContext: Sendable {
  /// The tool whose arguments triggered an unexpected error.
  public let toolName: String
  /// The unexpected error that occurred.
  public let error: any Error

  public init(toolName: String, error: any Error) {
    self.toolName = toolName
    self.error = error
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
