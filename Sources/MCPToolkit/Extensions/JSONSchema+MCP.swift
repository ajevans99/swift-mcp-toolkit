extension JSONValue {
  init(value: MCP.Value) {
    switch value {
    case .null:
      self = .null
    case .bool(let b):
      self = .boolean(b)
    case .double(let n):
      self = .number(n)
    case .int(let i):
      self = .integer(i)
    case .string(let s):
      self = .string(s)
    case .array(let a):
      self = .array(a.map { JSONValue(value: $0) })
    case .object(let o):
      self = .object(o.mapValues { JSONValue(value: $0) })
    case .data(let mimeType, let data):
      self = .object([
        "mimeType": mimeType.map { .string($0) } ?? .null,
        "data": .string(data.base64EncodedString()),
      ])
    @unknown default:
      self = .null
    }
  }
}
