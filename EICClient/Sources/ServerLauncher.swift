import Foundation
import EICShared

enum ServerLauncher {
  static let appName = "MarkEdit InContext"

  static func ensureServerRunning() async throws {
    if EICSocket.readPort() != nil {
      return
    }

    // Launch the app
    let appPath = resolveAppPath()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", appPath]
    try process.run()
    process.waitUntilExit()

    // Poll for port file to appear
    for _ in 0..<50 {
      if EICSocket.readPort() != nil {
        return
      }
      try await Task.sleep(for: .milliseconds(100))
    }

    throw EICError.serverNotReachable
  }

  static func resolveAppPath() -> String {
    let explicitPath = "/Applications/\(appName).app"
    if FileManager.default.fileExists(atPath: explicitPath) {
      return explicitPath
    }
    return appName
  }
}

enum EICError: Error, CustomStringConvertible {
  case serverNotReachable
  case rpcFailed(String)

  var description: String {
    switch self {
    case .serverNotReachable:
      return "eic: could not connect to \(ServerLauncher.appName) server"
    case .rpcFailed(let message):
      return "eic: \(message)"
    }
  }
}
