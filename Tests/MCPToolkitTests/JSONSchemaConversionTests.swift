import Foundation
import Testing

@testable import MCPToolkit

@Suite("JSON Schema numeric conversion")
struct JSONSchemaConversionTests {
  @Test(arguments: [
    ("0", 0), ("1.0", 1), ("1e2", 100),
    ("9007199254740993", 9_007_199_254_740_993),
    (String(Int.min), Int.min), (String(Int.max), Int.max),
    ("9223372036854775807.0", Int.max),
    ("-9.223372036854775808e18", Int.min),
  ])
  func integersRemainExact(token: String, expected: Int) throws {
    let value = try MCP.Value(value: JSONValue.parse(token))
    guard case .int(let integer) = value else {
      Issue.record("Expected an MCP integer for \(token), got \(value)")
      return
    }
    #expect(integer == expected)
  }

  @Test(arguments: ["0.1", "9.270", "-1.25", "1e20", "1e-300"])
  func doublesPreserveDecimalValue(token: String) throws {
    let original = try JSONValue.parse(token)
    let value = try MCP.Value(value: original)
    guard case .double(let double) = value else {
      Issue.record("Expected an MCP double for \(token)")
      return
    }
    #expect(double.isFinite)
    #expect(try JSONValue(value: value) == original)
  }

  @Test(arguments: ["-0", "-0.0", "-0e1000"])
  func negativeZeroRetainsSign(token: String) throws {
    let value = try MCP.Value(value: JSONValue.parse(token))
    guard case .double(let double) = value else {
      Issue.record("Expected an MCP double for negative zero")
      return
    }
    #expect(double == 0)
    #expect(double.sign == .minus)
    #expect(try JSONValue(value: value).numberLiteral?.rawValue == "-0.0")
  }

  @Test(arguments: [
    "9223372036854775808", "-9223372036854775809", "18446744073709551615",
    "0.10000000000000001", "9007199254740993.5",
  ])
  func rejectsDecimalPrecisionLoss(token: String) throws {
    let value = try JSONValue.parse(token)
    #expect(throws: JSONNumberLiteral.ConversionError.inexactConversion) {
      try MCP.Value(value: value)
    }
  }

  @Test(arguments: ["1e1000", "-1e1000", "1e-1000", "-1e-1000"])
  func rejectsOverflowAndUnderflow(token: String) throws {
    let value = try JSONValue.parse(token)
    #expect(throws: JSONNumberLiteral.ConversionError.outOfRange) {
      try MCP.Value(value: value)
    }
  }

  @Test(arguments: [
    Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude,
    Double(Int.min), Double(Int.max), Double(Int.max).nextDown, 0.1, -0.0,
  ])
  func finiteMCPDoublesRoundTrip(double: Double) throws {
    let json = try JSONValue(value: .double(double))
    let value = try MCP.Value(value: json)
    switch value {
    case .double(let result):
      #expect(result == double)
      #expect(result.sign == double.sign)
    case .int(let result):
      #expect(Double(result) == double)
    default:
      Issue.record("Expected a numeric MCP value")
    }
  }

  @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
  func nonfiniteDoublesThrowRecursively(double: Double) {
    let value: MCP.Value = .object(["nested": .array([.double(double)])])
    #expect(throws: JSONNumberLiteral.ConversionError.nonFinite) {
      try JSONValue(value: value)
    }
  }

  @Test func nestedValuesAndDataKeepTheirShape() throws {
    let json = try JSONValue.parse(
      #"{"values":[null,true,"text",9223372036854775807,0.1],"empty":{}}"#
    )
    #expect(try JSONValue(value: MCP.Value(value: json)) == json)
    #expect(try MCP.Value(schemaValue: .boolean(false)) == .bool(false))
    #expect(
      try JSONValue(value: .data(mimeType: "text/plain", Data("hi".utf8)))
        == .object(["mimeType": "text/plain", "data": "aGk="])
    )
    let invalid = try JSONValue.parse(#"{"nested":[1e1000]}"#)
    #expect(throws: JSONNumberLiteral.ConversionError.outOfRange) {
      try MCP.Value(value: invalid)
    }
  }

  @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
  func invalidArgumentsUseMessaging(double: Double) async throws {
    let messaging = ResponseMessagingFactory.defaultWithOverrides {
      $0.unexpectedError = { context in
        #expect(context.error as? JSONNumberLiteral.ConversionError == .nonFinite)
        return .init(
          content: [.text(text: "numeric conversion failed", annotations: nil, _meta: nil)],
          isError: true
        )
      }
    }
    let result = try await AdditionTool().call(
      arguments: ["left": .double(double), "right": .int(1)],
      messaging: messaging
    )
    #expect(result.isError == true)
    #expect(
      result.content == [.text(text: "numeric conversion failed", annotations: nil, _meta: nil)]
    )
  }

  @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
  func invalidStructuredOutputUsesMessaging(double: Double) async throws {
    let result = try await NumericStructuredTool(value: .double(double)).call(arguments: [:])
    #expect(result.isError == true)
    #expect(result.structuredContent == nil)
    #expect(result._meta?["cached"] == .bool(true))
    guard case .text(let text, _, _) = result.content.first else {
      Issue.record("Expected an explicit structured output error")
      return
    }
    #expect(text.contains("Failed to decode structured output"))
  }

  @Test func schemaAndMetadataErrorsPropagate() async throws {
    let huge = try JSONNumberLiteral("1e1000")
    #expect(throws: JSONNumberLiteral.ConversionError.outOfRange) {
      try NumericSchemaTool(minimum: huge).toTool()
    }
    #expect(throws: JSONNumberLiteral.ConversionError.outOfRange) {
      try NumericStructuredTool(value: .int(0), minimum: huge).toTool()
    }
    let metadata: [String: JSONValue] = ["nested": .array([.numberLiteral(huge)])]
    let tool = NumericMetadataTool(meta: metadata, resultMeta: metadata)
    #expect(throws: JSONNumberLiteral.ConversionError.outOfRange) {
      try tool.toTool()
    }
    await #expect(throws: JSONNumberLiteral.ConversionError.outOfRange) {
      try await tool.call(arguments: [:])
    }
    let resource = NumericMetadataResource(resultMeta: metadata)
    await #expect(throws: JSONNumberLiteral.ConversionError.outOfRange) {
      try await resource.read(uri: resource.uri)
    }
  }

  @Test(arguments: [false, true])
  func invalidMetadataCannotBecomeASuccessResult(shouldFail: Bool) async throws {
    let metadata: [String: JSONValue] = ["number": try JSONValue.parse("1e1000")]
    let tool = NumericMetadataTool(meta: nil, resultMeta: metadata, shouldFail: shouldFail)
    await #expect(throws: JSONNumberLiteral.ConversionError.outOfRange) {
      try await tool.call(arguments: [:])
    }
    let structuredTool = NumericStructuredMetadataTool(
      resultMeta: metadata,
      shouldFail: shouldFail
    )
    await #expect(throws: JSONNumberLiteral.ConversionError.outOfRange) {
      try await structuredTool.call(arguments: [:])
    }
  }

  @Test func serverReportsConversionFailures() async throws {
    let metadata: [String: JSONValue] = ["number": try JSONValue.parse("1e1000")]
    let tool = NumericMetadataTool(meta: metadata, resultMeta: metadata)
    let transport = TestTransport()
    let server = Server(name: "Numeric Test Server", version: "1.0.0")
    await server.register(tools: [tool])
    try await server.start(transport: transport)

    do {
      let encoder = JSONEncoder()
      let decoder = JSONDecoder()
      await transport.push(try encoder.encode(ListTools.request(.init())))
      let listResponses = try await transport.waitForSent(count: 1)
      let listResponse = try decoder.decode(
        Response<ListTools>.self,
        from: #require(listResponses.first)
      )
      #expect(throws: (any Error).self) { try listResponse.result.get() }

      await transport.push(
        try encoder.encode(CallTool.request(.init(name: tool.name, arguments: [:])))
      )
      let callResponses = try await transport.waitForSent(count: 1)
      let callResponse = try decoder.decode(
        Response<CallTool>.self,
        from: #require(callResponses.first)
      )
      #expect(try callResponse.result.get().isError == true)
    } catch {
      await transport.finish()
      await server.stop()
      throw error
    }
    await transport.finish()
    await server.stop()
  }
}

private struct NumericSchemaTool: MCPTool {
  let name = "numeric-schema"
  let minimum: JSONNumberLiteral

  var parameters: some JSONSchemaComponent<Double> {
    JSONNumber().minimum(minimum)
  }

  func call(with arguments: Double) async throws(ToolError) -> Content {
    "\(arguments)"
  }
}

private struct NumericStructuredTool: MCPToolWithStructuredOutput {
  let name = "numeric-structured"
  let value: MCP.Value
  var minimum = JSONNumberLiteral(0)

  var parameters: some JSONSchemaComponent<Void> { JSONObject {} }
  var outputSchema: some JSONSchemaComponent<Double> { JSONNumber().minimum(minimum) }

  func produceOutput(with arguments: Void) async throws(ToolError) -> Double { 0 }

  func callToolResult(with arguments: Void) async throws -> CallTool.Result {
    .init(
      content: [],
      structuredContent: Optional.some(value),
      _meta: Metadata(additionalFields: ["cached": .bool(true)])
    )
  }
}

private struct NumericMetadataTool: MCPTool {
  let name = "numeric-metadata"
  let meta: [String: JSONValue]?
  let resultMeta: [String: JSONValue]?
  var shouldFail = false

  var parameters: some JSONSchemaComponent<Void> { JSONObject {} }

  func call(with arguments: Void) async throws(ToolError) -> Content {
    if shouldFail { throw ToolError("Failed") }
    return ["OK"]
  }
}

private struct NumericStructuredMetadataTool: MCPToolWithStructuredOutput {
  let name = "numeric-structured-metadata"
  let resultMeta: [String: JSONValue]?
  let shouldFail: Bool

  var parameters: some JSONSchemaComponent<Void> { JSONObject {} }
  var outputSchema: some JSONSchemaComponent<Double> { JSONNumber() }

  func produceOutput(with arguments: Void) async throws(ToolError) -> Double {
    if shouldFail { throw ToolError("Failed") }
    return 0.5
  }
}

private struct NumericMetadataResource: MCPResource {
  let uri = "text://numeric-metadata"
  let resultMeta: [String: JSONValue]?
  var content: Content { "OK" }
}
