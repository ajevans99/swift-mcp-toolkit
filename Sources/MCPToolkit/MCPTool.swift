public protocol MCPTool: Sendable {
  associatedtype Parameters
  associatedtype Schema: JSONSchemaComponent<Parameters>

  var name: String { get }
  var description: String? { get }
  var annotations: Tool.Annotations { get }

  @JSONSchemaBuilder
  var parameters: Schema { get }

  func call(with arguments: Parameters) async throws -> CallTool.Result
}

extension MCPTool {
  public var description: String? {
    nil
  }

  public var annotations: Tool.Annotations {
    nil
  }
}

extension MCPTool where Parameters: Schemable, Parameters.Schema.Output == Parameters {
  public var parameters: some JSONSchemaComponent<Parameters> {
    Parameters.schema
  }
}
