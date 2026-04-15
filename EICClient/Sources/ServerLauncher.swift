import Foundation
import EICShared
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum ServerLauncher {
  static let appName = "MarkEdit InContext"
  nonisolated(unsafe) static var verbose = false

  static func ensureServerRunning() async throws {
    // Remote mode: an EIC_PORT env var means the user has set up a forwarding tunnel.
    // We can't auto-launch the Mac app from the remote side — just verify reachability.
    if let override = ProcessInfo.processInfo.environment["EIC_PORT"], let port = Int(override), port > 0 {
      debug("Remote mode: using EIC_PORT=\(port)")
      if isPortOpen(port) {
        return
      }
      FileHandle.standardError.write(Data("""
        eic: cannot reach \(appName) at 127.0.0.1:\(port).
        Start the app on your Mac and ensure your SSH tunnel forwards that port, e.g.:
          ssh -R \(port):127.0.0.1:\(port) <remote-host>
        (the Mac's current port is in ~/.eic/eic.port)

        """.utf8))
      throw EICError.serverNotReachable
    }

    #if os(macOS)
    // If a port file exists, check if the server is actually reachable
    debug("Checking port file: \(EICSocket.portFilePath)")
    if let port = EICSocket.readPort() {
      debug("Port file contains: \(port)")
      if isPortOpen(port) {
        debug("Port \(port) is open — server is running")
        return
      }
      debug("Port \(port) is not open — server is stale")
    } else {
      debug("No valid port file found")
    }

    // Stale or missing — clean up and launch the app
    EICSocket.removePortFile()
    let appPath = resolveAppPath()
    debug("Launching app: open -a \(appPath)")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", appPath]
    try process.run()
    process.waitUntilExit()

    // Poll for a valid port file
    debug("Polling for server to start...")
    for attempt in 0..<50 {
      if let port = EICSocket.readPort(), isPortOpen(port) {
        debug("Server started on port \(port) (attempt \(attempt + 1))")
        return
      }
      try await Task.sleep(for: .milliseconds(100))
    }

    debug("Server failed to start after 5s")
    throw EICError.serverNotReachable
    #else
    FileHandle.standardError.write(Data("""
      eic: no $EIC_PORT set and this host can't launch \(appName) directly.
      Set EIC_PORT to the forwarded port of the Mac running \(appName).

      """.utf8))
    throw EICError.serverNotReachable
    #endif
  }

  static func resolveAppPath() -> String {
    let explicitPath = "/Applications/\(appName).app"
    if FileManager.default.fileExists(atPath: explicitPath) {
      return explicitPath
    }
    return appName
  }

  static func debug(_ message: String) {
    guard verbose else { return }
    FileHandle.standardError.write(Data("[eic] \(message)\n".utf8))
  }

  private static func isPortOpen(_ port: Int) -> Bool {
    let sock = socket(AF_INET, SOCK_STREAM, 0)
    guard sock >= 0 else { return false }
    defer { close(sock) }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(port).bigEndian
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")

    return withUnsafePointer(to: &addr, {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }) == 0
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
