import MCP

/// A result builder that produces ordered `Prompt.Message` collections.
@resultBuilder
public enum PromptMessageBuilder {
  public static func buildBlock(_ components: [Prompt.Message]...) -> [Prompt.Message] {
    components.flatMap { $0 }
  }

  public static func buildArray(_ components: [[Prompt.Message]]) -> [Prompt.Message] {
    components.flatMap { $0 }
  }

  public static func buildOptional(_ component: [Prompt.Message]?) -> [Prompt.Message] {
    component ?? []
  }

  public static func buildEither(first component: [Prompt.Message]) -> [Prompt.Message] {
    component
  }

  public static func buildEither(second component: [Prompt.Message]) -> [Prompt.Message] {
    component
  }

  public static func buildExpression(_ expression: Prompt.Message) -> [Prompt.Message] {
    [expression]
  }

  public static func buildExpression(_ expression: [Prompt.Message]) -> [Prompt.Message] {
    expression
  }

  public static func buildExpression(_ expression: String) -> [Prompt.Message] {
    [.user(.text(text: expression))]
  }
}

/// Builds a list of messages using ``PromptMessageBuilder``.
///
/// This helper enables both synchronous and asynchronous composition of prompt messages:
///
/// ```swift
/// let messages = PromptMessages {
///   "Summarise the latest status update."
///   Prompt.Message.assistant("Sure, working on it!")
/// }
/// ```
///
/// Use the `async` variant when the message body performs asynchronous work.
public func PromptMessages(
  @PromptMessageBuilder _ content: () -> [Prompt.Message]
) -> [Prompt.Message] {
  content()
}

/// Builds messages asynchronously using ``PromptMessageBuilder``.
public func PromptMessages(
  @PromptMessageBuilder _ content: () async throws -> [Prompt.Message]
) async rethrows -> [Prompt.Message] {
  try await content()
}
