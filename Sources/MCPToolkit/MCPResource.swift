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
  /// Type alias for the content produced by the result builder.
  typealias Content = [ResourceContentItem]

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
public typealias ResourceContentBuilder = ContentBuilder<ResourceContentItem>

extension ContentBuilder where Item == ResourceContentItem {
  /// Builds an expression from a `ResourceGroup`.
  public static func buildExpression(_ group: ResourceGroup) -> ResourceContentItem {
    group.asContentItem()
  }
}

/// Represents a single content item with optional MIME type metadata.
public struct ResourceContentItem: Sendable, ExpressibleByStringLiteral,
  ExpressibleByStringInterpolation
{
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

// MARK: - Group Extension for Resources

/// Specialized version of Group that supports MIME types for resources.
public struct ResourceGroup: Sendable {
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
  public func mimeType(_ type: String) -> ResourceGroup {
    ResourceGroup(lines: lines, separator: separator, mimeType: type)
  }

  fileprivate func asContentItem() -> ResourceContentItem {
    ResourceContentItem(
      text: lines.joined(separator: separator),
      mimeType: mimeType
    )
  }
}
