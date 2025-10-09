import Foundation
import MCP
import Vapor

typealias HTTPRequest = Vapor.Request
typealias HTTPResponse = Vapor.Response

/// Transport implementation that bridges the MCP `Transport` protocol to Vapor's
/// Streamable HTTP facilities.
public actor VaporStreamableHTTPTransport: Transport {
  public nonisolated let logger: Logger

  private let messageStream: AsyncThrowingStream<Data, Swift.Error>
  private let messageContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation

  private var isConnected = false
  private var isClosed = false
  private var pendingInboundMessages: [Data] = []

  private struct Connection {
    enum Kind {
      case request
      case outbound
    }

    let id: UUID
    let kind: Kind
    var pendingRequestIDs: Set<MessageID>
    let continuation: AsyncStream<Data>.Continuation
  }

  private var connections: [UUID: Connection] = [:]
  private var idToConnection: [MessageID: UUID] = [:]

  /// Creates a transport that can service Vapor HTTP handlers.
  /// - Parameter logger: Optional logger used for transport diagnostics.
  public init(logger: Logger? = nil) {
    self.logger = logger ?? Logger(label: "mcp.transport.vapor")

    var continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation!
    self.messageStream = AsyncThrowingStream { continuation = $0 }
    self.messageContinuation = continuation
  }

  public func connect() async throws {
    guard !isClosed else {
      throw MCPError.connectionClosed
    }
    guard !isConnected else { return }

    isConnected = true
    logger.debug("Vapor streamable HTTP transport connected")

    if !pendingInboundMessages.isEmpty {
      pendingInboundMessages.forEach { messageContinuation.yield($0) }
      pendingInboundMessages.removeAll(keepingCapacity: false)
    }
  }

  public func disconnect() async {
    guard !isClosed else { return }
    isClosed = true
    isConnected = false
    pendingInboundMessages.removeAll(keepingCapacity: false)

    messageContinuation.finish()
    await closeAllConnections()
    logger.debug("Vapor streamable HTTP transport disconnected")
  }

  public func receive() -> AsyncThrowingStream<Data, Swift.Error> {
    messageStream
  }

  public func send(_ data: Data) async throws {
    guard !isClosed else {
      throw MCPError.connectionClosed
    }

    let envelopes = try JSONRPCEnvelope.parse(data: data)
    await deliver(envelopes: envelopes)
  }

  // MARK: - Incoming HTTP handlers

  /// Handles a Streamable HTTP `POST` request by forwarding the payload into the MCP server.
  /// - Parameter req: Incoming Vapor request.
  /// - Returns: A streaming response when the payload contains requests needing replies, otherwise `202 Accepted`.
  /// - Throws: ``Abort`` errors for malformed requests or decoding failures propagated from ``JSONRPCEnvelope`` parsing.
  func handlePost(_ req: HTTPRequest) async throws -> HTTPResponse {
    guard
      var body = req.body.data,
      let raw = body.readData(length: body.readableBytes)
    else {
      throw Abort(.badRequest, reason: "Empty body")
    }

    let envelopes = try JSONRPCEnvelope.parse(data: raw)
    let requestIDs = envelopes.requestIdentifiers

    let response: HTTPResponse
    if !requestIDs.isEmpty {
      response = await openRequestStream(for: requestIDs)
    } else {
      response = HTTPResponse(status: .accepted)
    }

    try enqueueInboundMessage(raw)
    return response
  }

  /// Handles a Streamable HTTP `GET` request by opening an SSE channel for outbound server messages.
  /// - Returns: A streaming response that delivers server-originated JSON-RPC payloads.
  func handleGet(_ req: HTTPRequest) async -> HTTPResponse {
    await openOutboundStream()
  }

  // MARK: - Helpers

  private func enqueueInboundMessage(_ data: Data) throws {
    if isClosed {
      throw MCPError.connectionClosed
    }

    if isConnected {
      messageContinuation.yield(data)
    } else {
      pendingInboundMessages.append(data)
    }
  }

  private func openRequestStream(for ids: Set<MessageID>) async -> HTTPResponse {
    let connectionID = UUID()
    let (stream, continuation) = AsyncStream<Data>.makeStream()
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeConnection(connectionID) }
    }

    let connection = Connection(
      id: connectionID,
      kind: .request,
      pendingRequestIDs: ids,
      continuation: continuation
    )

    connections[connectionID] = connection
    for id in ids {
      idToConnection[id] = connectionID
    }

    return makeSSEResponse(stream: stream)
  }

  private func openOutboundStream() async -> HTTPResponse {
    let connectionID = UUID()
    let (stream, continuation) = AsyncStream<Data>.makeStream()
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeConnection(connectionID) }
    }

    let connection = Connection(
      id: connectionID,
      kind: .outbound,
      pendingRequestIDs: [],
      continuation: continuation
    )

    connections[connectionID] = connection
    return makeSSEResponse(stream: stream)
  }

  private func makeSSEResponse(stream: AsyncStream<Data>) -> HTTPResponse {
    let response = HTTPResponse(status: .ok)
    response.headers.add(name: .contentType, value: "text/event-stream; charset=utf-8")
    response.headers.add(name: .cacheControl, value: "no-store")
    response.headers.add(name: .connection, value: "keep-alive")

    response.body = .init(asyncStream: { writer in
      let allocator = ByteBufferAllocator()
      do {
        for await payload in stream {
          var buffer = allocator.buffer(capacity: payload.count + 10)
          buffer.writeString("data: ")
          if let jsonString = String(data: payload, encoding: .utf8) {
            buffer.writeString(jsonString)
          } else {
            buffer.writeData(payload)
          }
          buffer.writeString("\n\n")
          try await writer.write(.buffer(buffer))
        }
        try await writer.write(.end)
      } catch {
        try await writer.write(.error(error))
      }
    })

    return response
  }

  private func removeConnection(_ id: UUID) async {
    guard let connection = connections.removeValue(forKey: id) else {
      return
    }

    if connection.kind == .request {
      for identifier in connection.pendingRequestIDs {
        idToConnection.removeValue(forKey: identifier)
      }
    }
  }

  private func closeAllConnections() async {
    let active = connections
    connections.removeAll(keepingCapacity: false)
    idToConnection.removeAll(keepingCapacity: false)

    for (_, connection) in active {
      connection.continuation.finish()
    }
  }

  private func deliver(envelopes: [JSONRPCEnvelope]) async {
    var grouped: [UUID: (payloads: [Any], resolved: Set<MessageID>)] = [:]
    var broadcast: [Any] = []
    var broadcastResponseIDs: Set<MessageID> = []

    for envelope in envelopes {
      switch envelope.kind {
      case .response(let id):
        if let connectionID = idToConnection[id] {
          var entry = grouped[connectionID, default: ([], [])]
          entry.payloads.append(envelope.object)
          entry.resolved.insert(id)
          grouped[connectionID] = entry
        } else {
          broadcast.append(envelope.object)
          broadcastResponseIDs.insert(id)
        }
      case .request, .notification:
        broadcast.append(envelope.object)
      }
    }

    for (id, entry) in grouped {
      guard let connection = connections[id] else { continue }
      if let data = encodePayloads(entry.payloads) {
        connection.continuation.yield(data)
      }

      if connection.kind == .request {
        var updated = connection
        updated.pendingRequestIDs.subtract(entry.resolved)
        if updated.pendingRequestIDs.isEmpty {
          connections.removeValue(forKey: id)
          for resolved in entry.resolved {
            idToConnection.removeValue(forKey: resolved)
          }
          updated.continuation.finish()
        } else {
          connections[id] = updated
          for resolved in entry.resolved {
            idToConnection.removeValue(forKey: resolved)
          }
        }
      }
    }

    guard !broadcast.isEmpty else { return }
    if let data = encodePayloads(broadcast) {
      for (_, connection) in connections where connection.kind == .outbound {
        connection.continuation.yield(data)
      }

      if !broadcastResponseIDs.isEmpty {
        for id in broadcastResponseIDs {
          idToConnection.removeValue(forKey: id)
        }
      }
    }
  }

  private func encodePayloads(_ payloads: [Any]) -> Data? {
    do {
      if payloads.count == 1, let object = payloads.first {
        return try JSONSerialization.data(withJSONObject: object)
      } else {
        return try JSONSerialization.data(withJSONObject: payloads)
      }
    } catch {
      logger.error("Failed to encode JSON payloads: \(error.localizedDescription)")
      return nil
    }
  }
}

private struct JSONRPCEnvelope {
  enum Kind {
    case request(MessageID)
    case notification
    case response(MessageID)
  }

  let kind: Kind
  let object: Any

  static func parse(data: Data) throws -> [JSONRPCEnvelope] {
    let json = try JSONSerialization.jsonObject(with: data)

    if let dictionary = json as? [String: Any] {
      guard let envelope = makeEnvelope(object: dictionary) else {
        return []
      }
      return [envelope]
    }

    guard let array = json as? [[String: Any]] else {
      throw MCPError.parseError("Invalid JSON-RPC payload")
    }

    return array.compactMap { makeEnvelope(object: $0) }
  }

  private static func makeEnvelope(object: [String: Any]) -> JSONRPCEnvelope? {
    if object["method"] != nil {
      if let idValue = object["id"], let identifier = MessageID(json: idValue) {
        return JSONRPCEnvelope(kind: .request(identifier), object: object)
      }
      return JSONRPCEnvelope(kind: .notification, object: object)
    }

    if let idValue = object["id"], let identifier = MessageID(json: idValue) {
      return JSONRPCEnvelope(kind: .response(identifier), object: object)
    }

    return nil
  }

  var requestIdentifiers: Set<MessageID> {
    switch kind {
    case .request(let id):
      return [id]
    case .notification, .response:
      return []
    }
  }
}

extension Collection where Element == JSONRPCEnvelope {
  fileprivate var requestIdentifiers: Set<MessageID> {
    reduce(into: Set<MessageID>()) { partialResult, envelope in
      partialResult.formUnion(envelope.requestIdentifiers)
    }
  }
}

private struct MessageID: Hashable {
  enum Storage: Hashable {
    case string(String)
    case int(Int64)
  }

  let storage: Storage

  init?(json: Any) {
    if let string = json as? String {
      self.storage = .string(string)
    } else if let int = json as? Int64 {
      self.storage = .int(int)
    } else if let int = json as? Int {
      self.storage = .int(Int64(int))
    } else if let double = json as? Double {
      self.storage = .int(Int64(double))
    } else {
      return nil
    }
  }
}
