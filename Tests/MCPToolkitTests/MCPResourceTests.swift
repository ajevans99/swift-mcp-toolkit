import Foundation
import MCPToolkit
import Testing

struct SimpleTextResource: MCPResource {
  let uri = "text://simple"
  let name: String? = "Simple Text"
  let description: String? = "A simple text resource"

  var content: Content {
    "Hello, world!"
  }
}

struct HTMLWidgetResource: MCPResource {
  let uri = "ui://widget"

  var content: Content {
    ResourceGroup {
      "<!DOCTYPE html>"
      "<html><body>Widget content</body></html>"
    }
    .mimeType("text/html")
  }
}

struct MultiContentResource: MCPResource {
  let uri = "doc://multi"

  var content: Content {
    ResourceGroup {
      "# Markdown Content"
    }
    .mimeType("text/markdown")

    ResourceGroup {
      "<h1>HTML Content</h1>"
    }
    .mimeType("text/html")

    "Plain text content"
  }
}

struct CustomSeparatorResource: MCPResource {
  let uri = "text://custom-separator"

  var content: Content {
    ResourceGroup(separator: ", ") {
      "apple"
      "banana"
      "cherry"
    }
  }
}

@Suite("MCPResource")
struct MCPResourceTests {
  @Test("toResource() generates correct metadata")
  func toResourceProducesValidMetadata() {
    let resource = SimpleTextResource()
    let mcpResource = resource.toResource()

    #expect(mcpResource.uri == "text://simple")
    #expect(mcpResource.name == "Simple Text")
    #expect(mcpResource.description == "A simple text resource")
  }

  @Test("read() returns single content item")
  func readReturnsSingleContent() async throws {
    let resource = SimpleTextResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 1)

    let textContent = result.contents.first
    #expect(textContent?.text == "Hello, world!")
    #expect(textContent?.uri == "text://simple")
  }

  @Test("read() respects MIME types")
  func readRespectsMimeTypes() async throws {
    let resource = HTMLWidgetResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 1)

    let content = result.contents.first
    #expect(content?.mimeType == "text/html")
    #expect(content?.text?.contains("Widget content") == true)
  }

  @Test("read() handles multiple content items")
  func readHandlesMultipleContent() async throws {
    let resource = MultiContentResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 3)

    let first = result.contents[0]
    #expect(first.text?.contains("# Markdown Content") == true)
    #expect(first.mimeType == "text/markdown")

    let second = result.contents[1]
    #expect(second.text?.contains("<h1>HTML Content</h1>") == true)
    #expect(second.mimeType == "text/html")

    let third = result.contents[2]
    #expect(third.text == "Plain text content")
  }

  @Test("Group uses custom separator")
  func groupUsesCustomSeparator() async throws {
    let resource = CustomSeparatorResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 1)

    let content = result.contents.first
    #expect(content?.text == "apple, banana, cherry")
  }

  @Test("read() handles binary blob content")
  func readHandlesBinaryBlob() async throws {
    struct BinaryResource: MCPResource {
      let uri = "data://image"

      var content: Content {
        // A 1x1 red PNG pixel (base64 encoded)
        let redPixel =
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

        ResourceContentItem.blob(redPixel, mimeType: "image/png")
      }
    }

    let resource = BinaryResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 1)

    let content = result.contents.first
    #expect(content?.blob != nil)
    #expect(content?.text == nil)
    #expect(content?.mimeType == "image/png")
    #expect(content?.uri == "data://image")

    // Verify the blob can be decoded back to Data
    if let blob = content?.blob, let data = Data(base64Encoded: blob) {
      #expect(data.count > 0)
    } else {
      Issue.record("Failed to decode blob back to Data")
    }
  }

  @Test("read() handles mixed text and blob content")
  func readHandlesMixedContent() async throws {
    struct MixedResource: MCPResource {
      let uri = "mixed://content"

      var content: Content {
        ResourceGroup {
          "# Document Header"
          "This document contains an embedded image."
        }
        .mimeType("text/markdown")

        // A 1x1 transparent PNG (base64 encoded)
        ResourceContentItem.blob(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQIW2NgAAIAAAUAAR4f7BQAAAAASUVORK5CYII=",
          mimeType: "image/png"
        )

        ResourceGroup {
          "## Footer"
          "End of document."
        }
        .mimeType("text/markdown")
      }
    }

    let resource = MixedResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 3)

    // First item should be text
    let first = result.contents[0]
    #expect(first.text != nil)
    #expect(first.blob == nil)
    #expect(first.mimeType == "text/markdown")

    // Second item should be blob
    let second = result.contents[1]
    #expect(second.text == nil)
    #expect(second.blob != nil)
    #expect(second.mimeType == "image/png")

    // Third item should be text
    let third = result.contents[2]
    #expect(third.text != nil)
    #expect(third.blob == nil)
    #expect(third.mimeType == "text/markdown")
  }

  @Test("read() uses content item URI when provided")
  func readUsesContentItemURI() async throws {
    struct MultiURIResource: MCPResource {
      let uri = "doc://main"

      var content: Content {
        ResourceGroup {
          "Content from section 1"
        }
        .uri("doc://main/section1")

        ResourceGroup {
          "Content from section 2"
        }
        .uri("doc://main/section2")

        "Content without specific URI"
      }
    }

    let resource = MultiURIResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 3)

    // First item should have its own URI
    let first = result.contents[0]
    #expect(first.uri == "doc://main/section1")

    // Second item should have its own URI
    let second = result.contents[1]
    #expect(second.uri == "doc://main/section2")

    // Third item should fall back to resource URI
    let third = result.contents[2]
    #expect(third.uri == "doc://main")
  }

  @Test("read() falls back to resource URI when content item URI is nil")
  func readFallsBackToResourceURI() async throws {
    struct FallbackResource: MCPResource {
      let uri = "resource://fallback"

      var content: Content {
        "Plain text content without URI"

        ResourceGroup {
          "Group content without URI"
        }
        .mimeType("text/plain")
      }
    }

    let resource = FallbackResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 2)

    // Both items should use the resource URI as fallback
    #expect(result.contents[0].uri == "resource://fallback")
    #expect(result.contents[1].uri == "resource://fallback")
  }

  @Test("ResourceContentItem.uri() sets URI correctly")
  func contentItemURIMethodSetsURI() {
    let item = ResourceContentItem(text: "Test content")
      .uri("custom://uri")

    #expect(item.uri == "custom://uri")
  }

  @Test("ResourceContentItem init with URI parameter")
  func contentItemInitWithURI() {
    let textItem = ResourceContentItem(
      text: "Test text",
      mimeType: "text/plain",
      uri: "text://custom"
    )

    #expect(textItem.uri == "text://custom")
    #expect(textItem.mimeType == "text/plain")

    let blobItem = ResourceContentItem(
      base64Blob: "SGVsbG8=",
      mimeType: "application/octet-stream",
      uri: "blob://custom"
    )

    #expect(blobItem.uri == "blob://custom")
    #expect(blobItem.mimeType == "application/octet-stream")
  }

  @Test("ResourceContentItem.blob() static method with URI")
  func contentItemBlobStaticMethodWithURI() {
    let item = ResourceContentItem.blob(
      "SGVsbG8=",
      mimeType: "application/octet-stream",
      uri: "blob://static"
    )

    #expect(item.uri == "blob://static")
    #expect(item.mimeType == "application/octet-stream")
  }

  @Test("ResourceGroup.uri() sets URI correctly")
  func resourceGroupURIMethodSetsURI() async throws {
    struct GroupURIResource: MCPResource {
      let uri = "doc://parent"

      var content: Content {
        ResourceGroup {
          "Line 1"
          "Line 2"
        }
        .uri("doc://parent/child")
        .mimeType("text/plain")
      }
    }

    let resource = GroupURIResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 1)

    let content = result.contents.first
    #expect(content?.uri == "doc://parent/child")
    #expect(content?.mimeType == "text/plain")
    #expect(content?.text == "Line 1\nLine 2")
  }

  @Test("read() handles blob content with custom URI")
  func readHandlesBlobContentWithCustomURI() async throws {
    struct BlobWithURIResource: MCPResource {
      let uri = "doc://images"

      var content: Content {
        ResourceContentItem.blob(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==",
          mimeType: "image/png",
          uri: "doc://images/red-pixel.png"
        )
      }
    }

    let resource = BlobWithURIResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 1)

    let content = result.contents.first
    #expect(content?.uri == "doc://images/red-pixel.png")
    #expect(content?.mimeType == "image/png")
    #expect(content?.blob != nil)
  }

  @Test("read() handles mixed URIs with fallback")
  func readHandlesMixedURIsWithFallback() async throws {
    struct MixedURIResource: MCPResource {
      let uri = "root://doc"

      var content: Content {
        // Has custom URI
        ResourceGroup {
          "Section A"
        }
        .uri("root://doc/a")

        // No custom URI, should fallback
        ResourceGroup {
          "Section B"
        }

        // Has custom URI
        ResourceContentItem.blob(
          "SGVsbG8=",
          mimeType: "application/octet-stream",
          uri: "root://doc/attachment"
        )

        // No custom URI, should fallback
        "Plain text"
      }
    }

    let resource = MixedURIResource()
    let result = try await resource.read(uri: resource.uri)

    #expect(result.contents.count == 4)

    #expect(result.contents[0].uri == "root://doc/a")
    #expect(result.contents[1].uri == "root://doc")
    #expect(result.contents[2].uri == "root://doc/attachment")
    #expect(result.contents[3].uri == "root://doc")
  }
}

@Suite("Resource server integration")
struct ResourceServerIntegrationTests {
  @Test("register(resources:) responds to resources/list")
  func serverHandlesResourcesList() async throws {
    let transport = TestTransport()
    let server = Server(name: "Resource Server", version: "1.0.0")
    let resource = SimpleTextResource()

    await server.register(resources: [resource])
    try await server.start(transport: transport)

    do {
      let encoder = JSONEncoder()
      let decoder = JSONDecoder()

      await transport.push(try encoder.encode(ListResources.request(.init())))

      let responses = try await transport.waitForSent(count: 1)
      let data = try #require(responses.first)
      let response = try decoder.decode(Response<ListResources>.self, from: data)
      let result = try response.result.get()
      let registeredResource = try #require(result.resources.first)

      #expect(registeredResource.uri == resource.uri)
      #expect(registeredResource.name == resource.name)
      #expect(registeredResource.description == resource.description)
    } catch {
      await transport.finish()
      await server.stop()
      throw error
    }

    await transport.finish()
    await server.stop()
  }

  @Test("register(resources:) responds to resources/read")
  func serverHandlesResourcesRead() async throws {
    let transport = TestTransport()
    let server = Server(name: "Resource Server", version: "1.0.0")
    let resource = SimpleTextResource()

    await server.register(resources: [resource])
    try await server.start(transport: transport)

    do {
      let encoder = JSONEncoder()
      let decoder = JSONDecoder()

      await transport.push(
        try encoder.encode(ReadResource.request(.init(uri: resource.uri)))
      )

      let responses = try await transport.waitForSent(count: 1)
      let data = try #require(responses.first)
      let response = try decoder.decode(Response<ReadResource>.self, from: data)
      let result = try response.result.get()

      #expect(result.contents.count == 1)

      let content = result.contents.first
      #expect(content?.text == "Hello, world!")
      #expect(content?.uri == resource.uri)
    } catch {
      await transport.finish()
      await server.stop()
      throw error
    }

    await transport.finish()
    await server.stop()
  }
}
