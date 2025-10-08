extension MCP.Value {
  init(value: JSONValue) {
    switch value {
    case .null:
      self = .null
    case .boolean(let b):
      self = .bool(b)
    case .number(let n):
      self = .double(n)
    case .integer(let i):
      self = .int(i)
    case .string(let s):
      self = .string(s)
    case .array(let a):
      self = .array(a.map { MCP.Value(value: $0) })
    case .object(let o):
      self = .object(o.mapValues { MCP.Value(value: $0) })
    }
  }
}

extension MCP.Value {
  init(schemaValue: SchemaValue) {
    switch schemaValue {
    case .boolean(let bool):
      self = .bool(bool)
    case .object(let dict):
      self = .object(dict.mapValues { MCP.Value(value: $0) })
    }
  }
}
