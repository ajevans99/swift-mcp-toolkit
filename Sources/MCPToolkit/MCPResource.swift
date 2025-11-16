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

  /// Optional result-level metadata. Override to provide metadata with each resource read result.
  ///
  /// This metadata is included in the `ReadResource.Result` as `_meta` and can be used for:
  /// - Caching hints for the client
  /// - Last modified timestamps
  /// - Version information
  ///
  /// ```swift
  /// var resultMeta: [String: JSONValue]? {
  ///   ["lastModified": "2024-01-15T10:30:00Z", "version": 2]
  /// }
  /// ```
  var resultMeta: [String: JSONValue]? { get }

  /// Optional extra fields for the result. Override to provide custom fields with each resource read result.
  ///
  /// These fields are included in the `ReadResource.Result` alongside standard fields and can be used
  /// for custom protocol extensions or provider-specific data.
  ///
  /// ```swift
  /// var resultExtraFields: [String: JSONValue]? {
  ///   ["provider": "custom", "etag": "abc123"]
  /// }
  /// ```
  var resultExtraFields: [String: JSONValue]? { get }

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

  /// Default implementation that emits no result-level metadata.
  public var resultMeta: [String: JSONValue]? {
    nil
  }

  /// Default implementation that emits no extra fields.
  public var resultExtraFields: [String: JSONValue]? {
    nil
  }
}

// MARK: - Content Building

/// A result builder for constructing resource content declaratively.
public typealias ResourceContentBuilder = ContentBuilder<ResourceContentItem>

extension ContentBuilder where Item == ResourceContentItem {
  /// Builds an expression from a `ResourceGroup`.
  public static func buildExpression(_ group: ResourceGroup) -> [ResourceContentItem] {
    [group.asContentItem()]
  }
}

/// Represents a single content item with optional MIME type metadata.
public struct ResourceContentItem: Sendable, ExpressibleByStringLiteral,
  ExpressibleByStringInterpolation
{
  /// The type of content this item contains.
  public enum ContentType: Sendable {
    /// Text content.
    case text(String)
    /// Binary content encoded as a base64 string.
    case blob(String)
  }

  public let content: ContentType
  public var mimeType: String?
  public var uri: String?

  /// Creates a text content item.
  public init(text: String, mimeType: String? = nil, uri: String? = nil) {
    self.content = .text(text)
    self.mimeType = mimeType
    self.uri = uri
  }

  /// Creates a binary content item from a base64-encoded string.
  ///
  /// - Parameters:
  ///   - base64Blob: The binary data encoded as a base64 string.
  ///   - mimeType: The MIME type of the binary content.
  ///   - uri: Optional URI for this specific content item.
  public init(base64Blob: String, mimeType: String, uri: String? = nil) {
    self.content = .blob(base64Blob)
    self.mimeType = mimeType
    self.uri = uri
  }

  public init(stringLiteral value: String) {
    self.content = .text(value)
    self.mimeType = nil
    self.uri = nil
  }

  /// Sets the MIME type for this content item.
  public func mimeType(_ type: String) -> ResourceContentItem {
    var copy = self
    copy.mimeType = type
    return copy
  }

  /// Sets the URI for this content item.
  public func uri(_ uri: String) -> ResourceContentItem {
    var copy = self
    copy.uri = uri
    return copy
  }

  private init(content: ContentType, mimeType: String?, uri: String?) {
    self.content = content
    self.mimeType = mimeType
    self.uri = uri
  }
}

extension ResourceContentItem {
  /// Creates a binary blob content item from a base64-encoded string.
  ///
  /// Common use case for images, PDFs, and other binary data:
  ///
  /// ```swift
  /// let imageData = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
  /// let item = ResourceContentItem.blob(imageData, mimeType: "image/png")
  /// ```
  ///
  /// - Parameters:
  ///   - base64Data: The binary data encoded as a base64 string.
  ///   - mimeType: The MIME type of the binary content.
  ///   - uri: Optional URI for this specific content item.
  /// - Returns: A new resource content item containing the binary blob.
  public static func blob(_ base64Data: String, mimeType: String, uri: String? = nil)
    -> ResourceContentItem
  {
    ResourceContentItem(base64Blob: base64Data, mimeType: mimeType, uri: uri)
  }
}

// MARK: - Group Extension for Resources

/// Specialized version of Group that supports MIME types for resources.
public struct ResourceGroup: Sendable {
  private let lines: [String]
  private let separator: String
  private var mimeType: String?
  private var uri: String?

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
    var copy = self
    copy.mimeType = type
    return copy
  }

  /// Sets the URI for this group of content.
  public func uri(_ uri: String) -> ResourceGroup {
    var copy = self
    copy.uri = uri
    return copy
  }

  public func asContentItem() -> ResourceContentItem {
    ResourceContentItem(
      text: lines.joined(separator: separator),
      mimeType: mimeType,
      uri: uri
    )
  }
}
