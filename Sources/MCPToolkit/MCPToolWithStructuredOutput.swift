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
///   func produceOutput(with arguments: Parameters) async throws(ToolError) -> Output {
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
///   func content(for output: Output) throws(ToolError) -> Content {
///     "Current temperature: \(output.temperature)°"
///     "Conditions: \(output.conditions)"
///     "Humidity: \(output.humidity)%"
///   }
/// }
/// ```
///
/// ## How It Works
///
/// 1. **Produce Output**: Implement ``produceOutput(with:)`` to generate your structured data
/// 2. **Add Content**: Optionally implement ``content(for:)`` to provide human-readable text
/// 3. **Automatic Validation**: The output is validated against your ``outputSchema``
/// 4. **Combined Result**: Both structured data and text content are returned together
///
/// The structured output is automatically included in the tool response and validated against
/// your output schema. If validation fails, an error response is returned to the client.
public protocol MCPToolWithStructuredOutput: MCPTool {
  associatedtype Output: Codable & Sendable
  associatedtype OutputSchema: JSONSchemaComponent<Output>

  /// The JSON Schema definition describing the tool's structured output.
  @JSONSchemaBuilder
  var outputSchema: OutputSchema { get }

  /// Produce the strongly-typed output payload for a call.
  ///
  /// Implement this method to return your tool's structured data. The framework will
  /// automatically encode it, validate it against ``outputSchema``, and include it in
  /// the response.
  ///
  /// ```swift
  /// func produceOutput(with arguments: Parameters) async throws(ToolError) -> Output {
  ///   let data = try await fetchWeatherData(for: arguments.location)
  ///   return Output(
  ///     temperature: data.temp,
  ///     conditions: data.description,
  ///     humidity: data.humidity
  ///   )
  /// }
  /// ```
  ///
  /// - Parameter arguments: The validated parameters from the tool call.
  /// - Returns: The structured output data.
  /// - Throws: ``ToolError`` for validation failures or other errors.
  func produceOutput(with arguments: Parameters) async throws(ToolError) -> Output

  /// Provide additional human-readable content alongside the structured output.
  ///
  /// Use the result builder to return content declaratively. The default implementation
  /// returns an empty array, so override this only if you want to include text content:
  ///
  /// ```swift
  /// func content(for output: Output) throws(ToolError) -> Content {
  ///   "Temperature: \(output.temperature)°"
  ///   "Conditions: \(output.conditions)"
  /// }
  /// ```
  ///
  /// - Parameter output: The structured output produced by ``produceOutput(with:)``.
  /// - Returns: Content items to include in the response.
  /// - Throws: ``ToolError`` if content generation fails.
  @ToolContentBuilder
  func content(for output: Output) throws(ToolError) -> Content

  /// Validates the structured output prior to returning it to the client.
  ///
  /// This method is called automatically by the framework after ``produceOutput(with:)``
  /// succeeds. It validates the output against ``outputSchema`` and returns an error
  /// response if validation fails.
  ///
  /// You typically don't need to override this method. It's exposed on the protocol
  /// to allow customization of validation behavior if needed.
  ///
  /// - Parameters:
  ///   - result: The result containing the structured output to validate.
  ///   - messaging: The messaging provider for formatting error responses.
  /// - Returns: The validated result, or an error result if validation fails.
  func validateStructuredOutputResult<M: ResponseMessaging>(
    _ result: CallTool.Result,
    messaging: M
  ) -> CallTool.Result
}

extension MCPToolWithStructuredOutput {
  /// Default implementation returns no content, yielding a purely structured response.
  public func content(for output: Output) throws(ToolError) -> Content {
    []
  }

  /// Default implementation that produces content from the structured output.
  ///
  /// This bridges ``produceOutput(with:)`` and ``content(for:)`` to satisfy the
  /// ``MCPTool`` protocol requirement. You don't normally need to override this.
  public func call(with arguments: Parameters) async throws(ToolError) -> Content {
    let output = try await produceOutput(with: arguments)
    return try content(for: output)
  }

  /// Internal method that packages structured output into a CallTool.Result.
  ///
  /// This method is called by the framework to combine your structured output
  /// and text content into a single response. It handles error conversion and
  /// ensures both the structured data and content are properly packaged.
  ///
  /// You can override this if you need complete control over result generation,
  /// but this is rarely necessary.
  public func callToolResult(with arguments: Parameters) async throws -> CallTool.Result {
    do {
      let output = try await produceOutput(with: arguments)
      let contentItems = try content(for: output)
      return try CallTool.Result(
        content: contentItems.map { $0.toToolContent() },
        structuredContent: output
      )
    } catch let error as ToolError {
      return CallTool.Result(
        content: error.content.map { $0.toToolContent() },
        isError: true
      )
    }
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
