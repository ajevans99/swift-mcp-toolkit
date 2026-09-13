extension MCP.Value {
  init(value: JSONValue) throws {
    switch value {
    case .null:
      self = .null
    case .boolean(let b):
      self = .bool(b)
    case .numberLiteral(let number):
      if number.isZero, number.rawValue.hasPrefix("-") {
        self = .double(-Double.zero)
      } else if number.isInteger,
        number >= JSONNumberLiteral(Int.min), number <= JSONNumberLiteral(Int.max)
      {
        self = .int(try number.integerValue())
      } else {
        let double = try number.doubleValue()
        // MCP has no lossless decimal case. Do not silently round schema bounds or metadata.
        guard try JSONNumberLiteral(double) == number else {
          throw JSONNumberLiteral.ConversionError.inexactConversion
        }
        self = .double(double)
      }
    case .string(let s):
      self = .string(s)
    case .array(let a):
      self = .array(try a.map { try MCP.Value(value: $0) })
    case .object(let o):
      self = .object(
        try Dictionary(uniqueKeysWithValues: o.map { ($0.key, try MCP.Value(value: $0.value)) })
      )
    }
  }
}

extension MCP.Value {
  init(schemaValue: SchemaValue) throws {
    switch schemaValue {
    case .boolean(let bool):
      self = .bool(bool)
    case .object(let dict):
      self = .object(
        try Dictionary(uniqueKeysWithValues: dict.map { ($0.key, try MCP.Value(value: $0.value)) })
      )
    }
  }
}
