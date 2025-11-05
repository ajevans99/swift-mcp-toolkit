import Foundation

/// A strongly typed interface for exposing resources in a Model Context Protocol server.
///
/// Conforming types define the URI for their resource and provide content using a declarative
/// result builder syntax. This makes it straightforward to build resources with rich content
/// while remaining fully compatible with the MCP specification.
///
/// ## Example: A Simple HTML Widget Resource
///
/// ```swift
/// struct WidgetResource: MCPResource {
///   let uri = "ui://widget/myWidget.html"
///   let name: String? = "My Widget"
///   let description: String? = "A simple HTML widget"
///
///   var content: Content {
///     Group {
///       "<!DOCTYPE html>"
///       "<html><body>"
///       "Hello from widget!"
///       "</body></html>"
///     }
///     .mimeType("text/html")
///   }
/// }
/// ```
///
/// ## Multiple Content Blocks
///
/// Resources can provide multiple content blocks, each with their own MIME type:
///
/// ```swift
/// struct DocumentResource: MCPResource {
///   let uri = "doc://readme"
///
///   var content: Content {
///     Group {
///       "# README"
///       "This is the content."
///     }
///     .mimeType("text/markdown")
///
///     Group {
///       "<h1>README</h1>"
///       "<p>This is the content.</p>"
///     }
///     .mimeType("text/html")
///   }
/// }
/// ```
public protocol MCPResource: Sendable {
  /// The unique URI that identifies this resource.
  var uri: String { get }
  /// An optional human-readable name for the resource.
  var name: String? { get }
  /// An optional description of what the resource provides.
  var description: String? { get }
  /// Optional MIME type hint for the primary content.
  var mimeType: String? { get }

  /// The content provided by this resource, built using a declarative result builder.
  @ResourceContentBuilder
  var content: Content { get async throws }
}

extension MCPResource {
  /// Default implementation that emits no name.
  public var name: String? {
    nil
  }

  /// Default implementation that emits no description.
  public var description: String? {
    nil
  }

  /// Default implementation that emits no MIME type.
  public var mimeType: String? {
    nil
  }
}

// MARK: - Content Building

/// A result builder for constructing resource content declaratively.
@resultBuilder
public enum ResourceContentBuilder {
  public static func buildBlock(_ components: ResourceContentItem...) -> [ResourceContentItem] {
    components
  }

  public static func buildExpression(_ item: ResourceContentItem) -> ResourceContentItem {
    item
  }

  public static func buildExpression(_ group: Group) -> ResourceContentItem {
    group.asContentItem()
  }

  public static func buildOptional(_ component: [ResourceContentItem]?) -> [ResourceContentItem] {
    component ?? []
  }

  public static func buildEither(first component: [ResourceContentItem]) -> [ResourceContentItem] {
    component
  }

  public static func buildEither(second component: [ResourceContentItem]) -> [ResourceContentItem] {
    component
  }

  public static func buildArray(_ components: [[ResourceContentItem]]) -> [ResourceContentItem] {
    components.flatMap { $0 }
  }
}

/// Represents a single content item with optional MIME type metadata.
public struct ResourceContentItem: Sendable, ExpressibleByStringLiteral {
  public let text: String
  public let mimeType: String?

  public init(text: String, mimeType: String? = nil) {
    self.text = text
    self.mimeType = mimeType
  }

  public init(stringLiteral value: String) {
    self.text = value
    self.mimeType = nil
  }

  /// Sets the MIME type for this content item.
  public func mimeType(_ type: String) -> ResourceContentItem {
    ResourceContentItem(text: text, mimeType: type)
  }
}

/// Groups multiple text strings into a single content item, optionally with a MIME type.
///
/// Use `Group` to combine multiple strings that should be treated as a single logical content
/// block with the same MIME type.
///
/// ## Example
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
/// You can customize the separator used to join the lines:
///
/// ```swift
/// Group(separator: " ") {
///   "Hello"
///   "World"
/// }
/// // Results in: "Hello World"
/// ```
public struct Group: Sendable {
  private let lines: [String]
  private let separator: String
  private let mimeType: String?

  public init(separator: String = "\n", @ArrayBuilder<String> _ content: () -> [String]) {
    self.lines = content()
    self.separator = separator
    self.mimeType = nil
  }

  private init(lines: [String], separator: String, mimeType: String?) {
    self.lines = lines
    self.separator = separator
    self.mimeType = mimeType
  }

  /// Sets the MIME type for this group of content.
  public func mimeType(_ type: String) -> Group {
    Group(lines: lines, separator: separator, mimeType: type)
  }

  fileprivate func asContentItem() -> ResourceContentItem {
    ResourceContentItem(
      text: lines.joined(separator: separator),
      mimeType: mimeType
    )
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

/// Type alias for the content produced by the result builder.
public typealias Content = [ResourceContentItem]
