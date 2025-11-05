import Foundation
import Testing

@testable import MCPToolkit

struct SimpleTextResource: MCPResource {
  let uri = "text://simple"
  let name: String? = "Simple Text"
  let description: String? = "A simple text resource"

  var content: Content {
    "Hello, world!"
  }
}

struct HTMLWidgetResource: MCPResource {
  let uri = "ui://widget/myWidget.html"
  let name: String? = "My Widget"
  let mimeType: String? = "text/html"

  var content: Content {
    Group {
      "<!DOCTYPE html>"
      "<html><body>Widget content</body></html>"
    }
    .mimeType("text/html")
  }
}

struct MultiContentResource: MCPResource {
  let uri = "doc://multi"

  var content: Content {
    Group {
      "# Markdown Content"
    }
    .mimeType("text/markdown")

    Group {
      "<h1>HTML Content</h1>"
    }
    .mimeType("text/html")

    "Plain text content"
  }
}

struct CustomSeparatorResource: MCPResource {
  let uri = "text://custom-separator"

  var content: Content {
    Group(separator: ", ") {
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
    let result = try await resource.read()

    #expect(result.contents.count == 1)

    let textContent = result.contents.first
    #expect(textContent?.text == "Hello, world!")
    #expect(textContent?.uri == "text://simple")
  }

  @Test("read() respects MIME types")
  func readRespectsMimeTypes() async throws {
    let resource = HTMLWidgetResource()
    let result = try await resource.read()

    #expect(result.contents.count == 1)

    let content = result.contents.first
    #expect(content?.mimeType == "text/html")
    #expect(content?.text?.contains("Widget content") == true)
  }

  @Test("read() handles multiple content items")
  func readHandlesMultipleContent() async throws {
    let resource = MultiContentResource()
    let result = try await resource.read()

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
    let result = try await resource.read()

    #expect(result.contents.count == 1)

    let content = result.contents.first
    #expect(content?.text == "apple, banana, cherry")
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
