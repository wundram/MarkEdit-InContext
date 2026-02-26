import Foundation
import GRPCCore
import EICShared

@MainActor
public protocol EICServiceDelegate: AnyObject, Sendable {
  func openEditSession(_ session: EditSession) async
  func openSettings()
  func quitApp()
}

public struct EICServiceImpl: Eic_V1_EditorService.SimpleServiceProtocol, Sendable {
  private let delegate: any EICServiceDelegate
  private let sessionManager: EditSessionManager

  public init(delegate: any EICServiceDelegate, sessionManager: EditSessionManager = .shared) {
    self.delegate = delegate
    self.sessionManager = sessionManager
  }

  public func edit(
    request: Eic_V1_EditRequest,
    context: ServerContext
  ) async throws -> Eic_V1_EditResponse {
    let session = EditSession(request: request)
    await delegate.openEditSession(session)
    let response = await sessionManager.awaitOutcome(for: session)
    return response
  }

  public func openSettings(
    request: Eic_V1_OpenSettingsRequest,
    context: ServerContext
  ) async throws -> Eic_V1_OpenSettingsResponse {
    await delegate.openSettings()
    return Eic_V1_OpenSettingsResponse()
  }

  public func quit(
    request: Eic_V1_QuitRequest,
    context: ServerContext
  ) async throws -> Eic_V1_QuitResponse {
    // Schedule quit after the response is sent so the client receives it
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(50))
      self.delegate.quitApp()
    }
    return Eic_V1_QuitResponse()
  }

  public func ping(
    request: Eic_V1_PingRequest,
    context: ServerContext
  ) async throws -> Eic_V1_PingResponse {
    var response = Eic_V1_PingResponse()
    response.version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    return response
  }
}
