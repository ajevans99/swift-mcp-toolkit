import Foundation
import Logging
import MCP

actor TestTransport: Transport {
  enum Error: Swift.Error {
    case timeout
  }

  nonisolated let logger = Logger(label: "TestTransport")
  private var incomingContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation?
  private var bufferedIncoming: [Data] = []
  private var sentPayloads: [Data] = []

  func connect() async throws {}

  func disconnect() async {
    incomingContinuation?.finish()
    incomingContinuation = nil
  }

  func send(_ data: Data) async throws {
    sentPayloads.append(data)
  }

  func receive() -> AsyncThrowingStream<Data, Swift.Error> {
    AsyncThrowingStream { continuation in
      Task { await self.storeContinuation(continuation) }
    }
  }

  func push(_ data: Data) async {
    if let continuation = incomingContinuation {
      continuation.yield(data)
    } else {
      bufferedIncoming.append(data)
    }
  }

  func waitForSent(count: Int, timeout: Duration = .seconds(1)) async throws -> [Data] {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while sentPayloads.count < count {
      if clock.now >= deadline {
        throw Error.timeout
      }
      try await Task.sleep(for: .milliseconds(10))
    }
    defer { sentPayloads.removeAll() }
    return sentPayloads
  }

  func finish() async {
    incomingContinuation?.finish()
    incomingContinuation = nil
  }

  private func storeContinuation(
    _ continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation
  ) async {
    incomingContinuation = continuation
    bufferedIncoming.forEach { continuation.yield($0) }
    bufferedIncoming.removeAll()
  }
}
