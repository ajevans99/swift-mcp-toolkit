import Foundation

// MARK: - Resource.Content Extension

extension Resource.Content {
  /// Creates a `Resource.Content` with a base64-encoded blob.
  ///
  /// This is a convenience method for creating blob content when you already have
  /// base64-encoded data as a string. The SDK's `.binary()` method expects `Data`,
  /// so this method decodes the base64 string and uses that API.
  ///
  /// - Parameters:
  ///   - base64Data: The base64-encoded string of the binary data.
  ///   - uri: The resource URI.
  ///   - mimeType: Optional MIME type of the resource.
  /// - Returns: A `Resource.Content` configured with the blob data.
  /// - Note: If the base64 string is invalid, this will use the `.binary()` method
  ///         with empty Data as a fallback.
  public static func blob(_ base64Data: String, uri: String, mimeType: String? = nil) -> Self {
    guard let data = Data(base64Encoded: base64Data) else {
      // Fallback to empty data if decoding fails
      return .binary(Data(), uri: uri, mimeType: mimeType)
    }
    return .binary(data, uri: uri, mimeType: mimeType)
  }
}

// MARK: - MCPResource Extension

extension MCPResource {
  /// Creates the `swift-sdk` representation of the resource for `resources/list` responses.
  ///
  /// - Returns: A configured `Resource` populated with the resource's metadata.
  /// - SeeAlso: https://modelcontextprotocol.io/specification/2025-06-18/server/resources
  public func toResource() -> Resource {
    Resource(
      name: name ?? uri,
      uri: uri,
      description: description,
      mimeType: mimeType
    )
  }

  /// Reads the resource content and converts it to MCP's `ReadResource.Result` format.
  ///
  /// - Parameter uri: The URI being read (should match `self.uri`).
  /// - Returns: A `ReadResource.Result` containing the resource's content.
  /// - Throws: Rethrows any errors from the resource's `content` getter.
  public func read(uri: String) async throws -> ReadResource.Result {
    let contents = try await self.content
    let resourceContents = contents.map { item in
      switch item.content {
      case .text(let text):
        return Resource.Content.text(text, uri: uri, mimeType: item.mimeType)
      case .blob(let base64Data):
        return Resource.Content.blob(base64Data, uri: uri, mimeType: item.mimeType)
      }
    }
    return ReadResource.Result(contents: resourceContents)
  }
}
