/// A convenience protocol for tools that want to describe and validate structured output payloads
/// alongside their textual content.
///
/// Conform to this protocol when your tool needs to return structured data that can be validated
/// against a JSON Schema, in addition to or instead of plain textual content. The protocol
/// automatically handles encoding, validation, and packaging of your output into MCP-compliant
/// responses.
///
/// Use the [``JSONSchemaBuilder`` DSL or the ``Schemable`` protocol](https://github.com/ajevans99/swift-json-schema)
/// to describe your output schema. The framework will validate the produced output against this
/// schema before returning it to the client.
///
/// ## Example: A Weather Tool with Structured Output
///
/// ```swift
/// struct WeatherTool: MCPToolWithStructuredOutput {
///   let name = "get_weather"
///   let description = "Fetch current weather conditions for a location"
///
///   @Schemable
///   struct Parameters {
///     let location: String
///     let units: String? = "celsius"
///   }
///
///   @Schemable
///   struct Output {
///     let temperature: Double
///     let conditions: String
///     let humidity: Int
///   }
///
///   func produceOutput(with arguments: Parameters) async throws -> Output {
///     // Fetch weather data from an external API
///     let data = try await weatherService.fetch(
///       location: arguments.location,
///       units: arguments.units ?? "celsius"
///     )
///
///     return Output(
///       temperature: data.temp,
///       conditions: data.description,
///       humidity: data.humidityPercent
///     )
///   }
///
///   func content(for output: Output) throws -> [Tool.Content] {
///     [.text("Current temperature: \(output.temperature)°, \(output.conditions)")]
///   }
/// }
/// ```
///
/// The tool's structured output is automatically validated against the `Output` schema and
/// included in the response alongside any textual content.
public protocol MCPToolWithStructuredOutput: MCPTool {
  associatedtype Output: Codable & Sendable
  associatedtype OutputSchema: JSONSchemaComponent<Output>

  /// The JSON Schema definition describing the tool's structured output.
  @JSONSchemaBuilder
  var outputSchema: OutputSchema { get }

  /// Produce the strongly-typed output payload for a call.
  ///
  /// Implementers should return the Swift representation of their structured result. The default
  /// ``MCPTool/call(with:)`` implementation will encode it into MCP content and validate it against
  /// ``outputSchema`` before returning to the client.
  func produceOutput(with arguments: Parameters) async throws -> Output

  /// Allow conformers to attach additional textual or media content to the `CallTool.Result`.
  ///
  /// The default implementation returns an empty list, yielding a purely structured response.
  func content(for output: Output) throws -> [Tool.Content]

  /// Validates the structured output prior to returning it to the client.
  ///
  /// Conformers typically do not override this, but it is declared on the protocol so callers can
  /// customize the messaging if desired.
  func validateStructuredOutputResult<M: ResponseMessaging>(
    _ result: CallTool.Result,
    messaging: M
  ) -> CallTool.Result
}

extension MCPToolWithStructuredOutput {
  public func content(for output: Output) throws -> [Tool.Content] {
    []
  }

  /// Default implementation that bridges ``produceOutput`` into the expected MCP result container.
  public func call(with arguments: Parameters) async throws -> CallTool.Result {
    let output = try await produceOutput(with: arguments)
    return try makeResult(from: output)
  }

  /// Packages the structured output and attaches any additional content.
  public func makeResult(from output: Output, isError: Bool? = nil) throws -> CallTool.Result {
    try CallTool.Result(
      content: try content(for: output),
      structuredContent: output,
      isError: isError
    )
  }

  public func validateStructuredOutputResult<M: ResponseMessaging>(
    _ result: CallTool.Result,
    messaging: M
  ) -> CallTool.Result {
    guard let structuredContent = result.structuredContent else {
      return result
    }

    let jsonValue = JSONValue(value: structuredContent)
    do {
      _ = try outputSchema.parseAndValidate(jsonValue)
      return result
    } catch let issue {
      return messaging.structuredOutputInvalid(
        .init(toolName: name, issue: issue)
      )
    }
  }

  public var outputSchemaValue: SchemaValue {
    outputSchema.schemaValue
  }
}

extension MCPToolWithStructuredOutput
where Output: Schemable, Output.Schema.Output == Output {
  /// Provides a synthesized schema for ``Output`` when it conforms to ``Schemable``.
  public var outputSchema: some JSONSchemaComponent<Output> {
    Output.schema
  }
}
