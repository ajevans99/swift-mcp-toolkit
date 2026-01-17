import MCPToolkit
import Testing

@Schemable
struct CachedToolParameters {
  let input: String
}

struct CachedTool: MCPTool {
  let name = "cached_tool"

  typealias Parameters = CachedToolParameters

  var resultMeta: [String: JSONValue]? {
    ["cached": true, "ttl": 3600]
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    ["Result: \(arguments.input)"]
  }
}

@Schemable
struct CustomToolParameters {
  let input: String
}

struct CustomTool: MCPTool {
  let name = "custom_tool"

  typealias Parameters = CustomToolParameters

  var resultExtraFields: [String: JSONValue]? {
    ["requestId": "req-123", "provider": "custom"]
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    ["Result: \(arguments.input)"]
  }
}

@Schemable
struct SimpleToolParameters {
  let input: String
}

struct SimpleTool: MCPTool {
  let name = "simple_tool"

  typealias Parameters = SimpleToolParameters

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    ["Result: \(arguments.input)"]
  }
}

@Schemable
struct StructuredToolParameters {
  let value: Int
}

@Schemable
struct StructuredToolOutput: Codable, Sendable {
  let doubled: Int
}

struct StructuredToolType: MCPToolWithStructuredOutput {
  let name = "structured_tool"

  typealias Parameters = StructuredToolParameters
  typealias Output = StructuredToolOutput

  var resultMeta: [String: JSONValue]? {
    ["computation": "simple", "cost": 0.001]
  }

  func produceOutput(with arguments: Parameters) async throws(ToolError) -> Output {
    Output(doubled: arguments.value * 2)
  }
}

@Schemable
struct ErrorToolParameters {
  let shouldFail: Bool
}

struct ErrorTool: MCPTool {
  let name = "error_tool"

  typealias Parameters = ErrorToolParameters

  var resultMeta: [String: JSONValue]? {
    ["attempts": 1]
  }

  func call(with arguments: Parameters) async throws(ToolError) -> Content {
    if arguments.shouldFail {
      throw ToolError("Operation failed")
    }
    return ["Success"]
  }
}

@Suite("Result metadata and extra fields")
struct ResultMetadataTests {

  @Test("Tool result includes _meta when provided")
  func testToolResultMeta() async throws {
    let tool = CachedTool()
    let result = try await tool.callToolResult(with: CachedToolParameters(input: "test"))

    #expect(result._meta != nil)
    #expect(result._meta?["cached"] == .bool(true))
    #expect(result._meta?["ttl"] == .int(3600))
  }

  @Test("Tool result includes extraFields when provided")
  func testToolResultExtraFields() async throws {
    let tool = CustomTool()
    let result = try await tool.callToolResult(with: CustomToolParameters(input: "test"))

    #expect(result.extraFields != nil)
    #expect(result.extraFields?["requestId"] == .string("req-123"))
    #expect(result.extraFields?["provider"] == .string("custom"))
  }

  @Test("Tool without metadata returns nil fields")
  func testToolWithoutMetadata() async throws {
    let tool = SimpleTool()
    let result = try await tool.callToolResult(with: SimpleToolParameters(input: "test"))

    #expect(result._meta == nil)
    #expect(result.extraFields == nil)
  }

  @Test("Structured output tool includes metadata")
  func testStructuredOutputWithMetadata() async throws {
    let tool = StructuredToolType()
    let result = try await tool.callToolResult(with: StructuredToolParameters(value: 5))

    #expect(result.structuredContent != nil)
    #expect(result._meta != nil)
    #expect(result._meta?["computation"] == .string("simple"))
    #expect(result._meta?["cost"] == .double(0.001))
  }

  @Test("Error results include metadata")
  func testErrorResultWithMetadata() async throws {
    let tool = ErrorTool()
    let result = try await tool.callToolResult(with: ErrorToolParameters(shouldFail: true))

    #expect(result.isError == true)
    #expect(result._meta != nil)
    #expect(result._meta?["attempts"] == .int(1))
  }
}
