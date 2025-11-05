import Foundation

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
  /// - Returns: A `ReadResource.Result` containing the resource's content.
  /// - Throws: Rethrows any errors from the resource's `content` getter.
  public func read() async throws -> ReadResource.Result {
    let items = try await content

    // Convert all content items to Resource.Content
    let contents: [Resource.Content] = items.map { item in
      .text(
        item.text,
        uri: uri,
        mimeType: item.mimeType ?? mimeType
      )
    }

    return ReadResource.Result(contents: contents)
  }
}
