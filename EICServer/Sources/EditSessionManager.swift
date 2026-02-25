import Foundation
import Synchronization
import EICShared

public struct EditSession: Sendable {
  public let id: UUID
  public let request: Eic_V1_EditRequest

  public init(id: UUID = UUID(), request: Eic_V1_EditRequest) {
    self.id = id
    self.request = request
  }
}

public final class EditSessionManager: Sendable {
  public static let shared = EditSessionManager()

  private struct State: Sendable {
    var continuations: [UUID: CheckedContinuation<Eic_V1_EditResponse, Never>] = [:]
  }

  private let state = Mutex<State>(State())

  private init() {}

  public func awaitOutcome(for session: EditSession) async -> Eic_V1_EditResponse {
    if session.request.detach {
      var response = Eic_V1_EditResponse()
      response.outcome = .detached
      return response
    }

    return await withCheckedContinuation { continuation in
      state.withLock { $0.continuations[session.id] = continuation }
    }
  }

  public func notifySaved(sessionID: UUID, content: String) {
    state.withLock { state in
      guard let continuation = state.continuations.removeValue(forKey: sessionID) else { return }
      var response = Eic_V1_EditResponse()
      response.outcome = .saved
      response.content = content
      continuation.resume(returning: response)
    }
  }

  public func notifyDiscarded(sessionID: UUID) {
    state.withLock { state in
      guard let continuation = state.continuations.removeValue(forKey: sessionID) else { return }
      var response = Eic_V1_EditResponse()
      response.outcome = .discarded
      continuation.resume(returning: response)
    }
  }

  public func notifyError(sessionID: UUID, message: String) {
    state.withLock { state in
      guard let continuation = state.continuations.removeValue(forKey: sessionID) else { return }
      var response = Eic_V1_EditResponse()
      response.outcome = .error
      response.errorMessage = message
      continuation.resume(returning: response)
    }
  }

  public func discardAll() {
    state.withLock { state in
      for (_, continuation) in state.continuations {
        var response = Eic_V1_EditResponse()
        response.outcome = .discarded
        continuation.resume(returning: response)
      }
      state.continuations.removeAll()
    }
  }

  public func hasSession(_ sessionID: UUID) -> Bool {
    state.withLock { $0.continuations[sessionID] != nil }
  }
}
