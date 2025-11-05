/// Groups multiple text strings into a single content item.
///
/// Use `Group` to combine multiple strings that should be treated as a single logical content
/// block. Works with both ``MCPResource`` and ``MCPTool`` content.
///
/// ## Example with Resources
///
/// ```swift
/// Group {
///   "<!DOCTYPE html>"
///   "<html>"
///   "<body>Hello!</body>"
///   "</html>"
/// }
/// .mimeType("text/html")
/// ```
///
/// ## Example with Tools
///
/// ```swift
/// Group {
///   "Line 1"
///   "Line 2"
///   "Line 3"
/// }
/// ```
///
/// You can customize the separator used to join the lines:
///
/// ```swift
/// Group(separator: " ") {
///   "Hello"
///   "World"
/// }
/// // Results in: "Hello World"
/// ```
public struct Group<ContentItem>: Sendable where ContentItem: Sendable {
  internal let lines: [String]
  internal let separator: String

  public init(separator: String = "\n", @ArrayBuilder<String> _ content: () -> [String]) {
    self.lines = content()
    self.separator = separator
  }

  /// Internal accessor for the joined text.
  internal var joinedText: String {
    lines.joined(separator: separator)
  }
}

/// A result builder for constructing arrays of strings.
@resultBuilder
public enum ArrayBuilder<Element> {
  public static func buildBlock(_ components: Element...) -> [Element] {
    components
  }

  public static func buildOptional(_ component: [Element]?) -> [Element] {
    component ?? []
  }

  public static func buildEither(first component: [Element]) -> [Element] {
    component
  }

  public static func buildEither(second component: [Element]) -> [Element] {
    component
  }

  public static func buildArray(_ components: [[Element]]) -> [Element] {
    components.flatMap { $0 }
  }
}
