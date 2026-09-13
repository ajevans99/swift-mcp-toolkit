import OrderedCollections

extension JSONValue {
  init(value: MCP.Value) throws {
    switch value {
    case .null:
      self = .null
    case .bool(let b):
      self = .boolean(b)
    case .double(let n):
      self = .numberLiteral(try JSONNumberLiteral(n))
    case .int(let i):
      self = .integer(i)
    case .string(let s):
      self = .string(s)
    case .array(let a):
      self = .array(try a.map { try JSONValue(value: $0) })
    case .object(let o):
      self = .object(
        try OrderedDictionary(
          uniqueKeysWithValues: o.map { ($0.key, try JSONValue(value: $0.value)) }
        )
      )
    case .data(let mimeType, let data):
      self = .object([
        "mimeType": mimeType.map { .string($0) } ?? .null,
        "data": .string(data.base64EncodedString()),
      ])
    }
  }
}
