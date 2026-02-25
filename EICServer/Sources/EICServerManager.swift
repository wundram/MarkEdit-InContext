import Foundation
import Synchronization
import GRPCCore
import GRPCNIOTransportHTTP2
import EICShared

public final class EICServerManager: Sendable {
  // swiftlint:disable:next weak_delegate
  private let delegate: any EICServiceDelegate
  private let serverTask = Mutex<Task<Void, Never>?>(nil)

  public init(delegate: any EICServiceDelegate) {
    self.delegate = delegate
  }

  private func debugLog(_ message: String) {
    let path = EICSocket.directoryPath + "/debug.log"
    let line = "\(Date()): \(message)\n"
    if let handle = FileHandle(forWritingAtPath: path) {
      handle.seekToEndOfFile()
      handle.write(Data(line.utf8))
      handle.closeFile()
    } else {
      try? EICSocket.ensureDirectoryExists()
      try? line.write(toFile: path, atomically: true, encoding: .utf8)
    }
  }

  public func start() {
    debugLog("start() called")
    serverTask.withLock { existing in
      guard existing == nil else {
        debugLog("Server already running")
        return
      }
      existing = Task { await self.runServer() }
      debugLog("Server task created")
    }
  }

  public func stop() {
    serverTask.withLock { task in
      task?.cancel()
      task = nil
    }
    EditSessionManager.shared.discardAll()
    EICSocket.removePortFile()
  }

  private func runServer() async {
    do {
      debugLog("Starting gRPC server on TCP localhost...")
      try EICSocket.ensureDirectoryExists()
      EICSocket.removePortFile()

      let transport = GRPCNIOTransportHTTP2.HTTP2ServerTransport.Posix(
        address: .ipv4(host: "127.0.0.1", port: 0),
        transportSecurity: .plaintext
      )

      let service = EICServiceImpl(delegate: delegate)
      let server = GRPCServer(transport: transport, services: [service])

      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          try await server.serve()
        }

        // Wait for the server to bind and get the actual port
        if let address = try await server.listeningAddress,
           let ipv4 = address.ipv4 {
          let port = ipv4.port
          debugLog("Server listening on 127.0.0.1:\(port)")
          try EICSocket.writePort(port)
          debugLog("Port \(port) written to \(EICSocket.portFilePath)")
        }
      }

      debugLog("server.serve() returned normally")
    } catch is CancellationError {
      debugLog("Server cancelled (normal shutdown)")
    } catch {
      debugLog("Server error: \(error)")
      if !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        if !Task.isCancelled {
          await runServer()
        }
      }
    }
  }
}
