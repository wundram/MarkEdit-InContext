import ArgumentParser
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import EICShared
#if canImport(proc_context)
import proc_context
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@main
struct EICCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "eic",
    abstract: "Edit a file in MarkEdit InContext. Blocks until save or discard."
  )

  @Option(name: .long, help: "Set the window title")
  var title: String?

  @Option(name: .long, help: "Override hostname shown in the editor window (defaults to $EIC_CLIENT_NAME or $HOSTNAME)")
  var name: String?

  @Flag(name: .shortAndLong, help: "Show debug output on stderr")
  var verbose = false

  @Flag(name: .long, help: "Show version information")
  var version = false

  @Flag(name: .long, help: "Edit a copy; on save, output to stdout (original unchanged)")
  var noSave = false

  @Flag(name: .long, help: "Open and return immediately (don't block)")
  var detach = false

  @Flag(name: .long, help: "Open the settings panel")
  var settings = false

  @Flag(name: .long, help: "Print EDITOR/GIT_EDITOR exports")
  var env = false

  @Flag(name: .long, help: "Quit the running app")
  var quit = false

  @Argument(help: "File to edit")
  var file: String?

  func run() async throws {
    ServerLauncher.verbose = verbose

    // --version: show client and server versions
    if version {
      print("eic 0.4.0 (client)")
      if let port = EICSocket.readPort() {
        do {
          let serverVersion: String = try await Self.withGRPCClient(port: port) { client in
            let response = try await client.ping(Eic_V1_PingRequest())
            return response.version.isEmpty ? "unknown" : response.version
          }
          print("\(ServerLauncher.appName) \(serverVersion) (server)")
        } catch {
          print("\(ServerLauncher.appName) (server not reachable)")
        }
      } else {
        print("\(ServerLauncher.appName) (server not running)")
      }
      return
    }

    // --env: print exports and exit
    if env {
      print("export EDITOR=eic")
      print("export GIT_EDITOR=eic")
      return
    }

    // Detect pipes
    let stdinPiped = !isatty(STDIN_FILENO).boolValue
    let stdoutPiped = !isatty(STDOUT_FILENO).boolValue

    // --settings: launch app with settings and exit
    if settings {
      try await ServerLauncher.ensureServerRunning()
      try await withClient { client in
        _ = try await client.openSettings(Eic_V1_OpenSettingsRequest())
      }
      return
    }

    // --quit: terminate the running app
    if quit {
      try await withClient { client in
        _ = try await client.quit(Eic_V1_QuitRequest())
      }
      return
    }

    // Need at least a file or stdin
    guard file != nil || stdinPiped else {
      throw CleanExit.helpRequest(self)
    }

    // Resolve file to absolute path
    var absolutePath: String?
    if let file {
      let url = URL(fileURLWithPath: file, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
      absolutePath = url.standardizedFileURL.path
    }

    // Auto-title phase 1: explicit flag, git context, pipe context
    var resolvedTitle = title
    if resolvedTitle == nil, let absolutePath {
      resolvedTitle = GitAutoTitle.detect(filePath: absolutePath)
    }
    #if canImport(proc_context)
    if resolvedTitle == nil, let ctx = proc_context_get() {
      if ctx.pointee.stdin_is_pipe != 0 || ctx.pointee.stdout_is_pipe != 0 {
        let procTitle = String(cString: ctx.pointee.title)
        if !procTitle.isEmpty {
          resolvedTitle = procTitle
          ServerLauncher.debug("proc_context title: \(procTitle)")
        }
      }
    }
    #endif

    // Read stdin if piped
    var stdinContent: String?
    if stdinPiped {
      stdinContent = readStdin()
    }

    // CLI owns all file I/O. Read file content and send via gRPC.
    var initialContent = ""
    if let stdinContent {
      if let absolutePath, !noSave, FileManager.default.fileExists(atPath: absolutePath) {
        let fileContent = (try? String(contentsOfFile: absolutePath, encoding: .utf8)) ?? ""
        initialContent = fileContent + stdinContent
      } else {
        initialContent = stdinContent
      }
    } else if let absolutePath, FileManager.default.fileExists(atPath: absolutePath) {
      initialContent = (try? String(contentsOfFile: absolutePath, encoding: .utf8)) ?? ""
    }

    // Auto-title phase 2: content heading, then basename/stdin fallbacks
    if resolvedTitle == nil {
      resolvedTitle = contentHeading(initialContent)
    }
    if resolvedTitle == nil, let absolutePath {
      resolvedTitle = URL(fileURLWithPath: absolutePath).lastPathComponent
    }
    if resolvedTitle == nil && stdinPiped {
      resolvedTitle = "stdin"
    }

    // Ensure server is running
    try await ServerLauncher.ensureServerRunning()

    // Client identity — for the editor window's remote-session UI.
    let env = ProcessInfo.processInfo.environment
    let isRemote = env["EIC_PORT"] != nil || env["SSH_CONNECTION"] != nil || env["SSH_CLIENT"] != nil
    let resolvedHostname: String = {
      if let name, !name.isEmpty { return name }
      if let n = env["EIC_CLIENT_NAME"], !n.isEmpty { return n }
      var buf = [CChar](repeating: 0, count: 256)
      if gethostname(&buf, buf.count) == 0 {
        return String(cString: buf)
      }
      return env["HOSTNAME"] ?? ""
    }()
    let resolvedUser: String = {
      if let sudoUser = env["SUDO_USER"], !sudoUser.isEmpty { return sudoUser }
      if let u = env["USER"], !u.isEmpty { return u }
      if let u = env["LOGNAME"], !u.isEmpty { return u }
      if let pw = getpwuid(geteuid())?.pointee.pw_name {
        return String(cString: pw)
      }
      return ""
    }()

    // Build the edit request — content goes via gRPC, no file path needed by the app
    let request: Eic_V1_EditRequest = {
      var r = Eic_V1_EditRequest()
      r.filePath = absolutePath ?? ""
      r.title = resolvedTitle ?? ""
      r.initialContent = initialContent
      r.noSave = noSave
      r.detach = detach
      r.stdoutPiped = stdoutPiped
      r.sudo = env["SUDO_USER"] != nil || geteuid() == 0
      r.clientHostname = resolvedHostname
      r.clientUser = resolvedUser
      r.clientIsRemote = isRemote
      return r
    }()

    ServerLauncher.debug("Edit RPC: file=\(request.filePath), title=\(request.title), noSave=\(request.noSave), detach=\(request.detach), sudo=\(request.sudo), contentLen=\(request.initialContent.count)")

    // Send the RPC — blocks until user saves or discards
    let response: Eic_V1_EditResponse = try await withClient { client in
      try await client.edit(request)
    }

    ServerLauncher.debug("Response: outcome=\(response.outcome)")

    // Handle response — CLI writes content back to disk
    switch response.outcome {
    case .saved:
      if stdoutPiped || noSave {
        // Output to stdout
        print(response.content, terminator: "")
        ServerLauncher.debug("Wrote \(response.content.count) chars to stdout")
      } else if let absolutePath {
        // Write content back to the file
        try response.content.write(toFile: absolutePath, atomically: true, encoding: .utf8)
        ServerLauncher.debug("Wrote \(response.content.count) chars to \(absolutePath)")
      }

    case .discarded:
      ServerLauncher.debug("Discarded — exiting with code 1")
      throw ExitCode(1)

    case .error:
      let message = response.errorMessage.isEmpty ? "Save failed" : response.errorMessage
      FileHandle.standardError.write(Data("eic: \(message)\n".utf8))
      throw ExitCode(1)

    case .detached:
      ServerLauncher.debug("Detached — returning immediately")
      break

    case .UNRECOGNIZED, .unspecified:
      break
    }
  }

  private func contentHeading(_ content: String) -> String? {
    guard let newline = content.firstIndex(of: "\n") else {
      return headingText(from: content)
    }
    return headingText(from: content[content.startIndex..<newline])
  }

  private func headingText(from line: some StringProtocol) -> String? {
    guard line.hasPrefix("#") else { return nil }
    let stripped = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
    guard !stripped.isEmpty else { return nil }
    if stripped.count > 80 {
      return String(stripped.prefix(77)) + "…"
    }
    return stripped
  }

  private func readStdin() -> String {
    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while true {
      let bytesRead = read(STDIN_FILENO, buffer, bufferSize)
      if bytesRead <= 0 { break }
      data.append(buffer, count: bytesRead)
    }

    return String(data: data, encoding: .utf8) ?? ""
  }

  private func withClient<T: Sendable>(
    _ body: @Sendable @escaping (Eic_V1_EditorService.Client<GRPCNIOTransportHTTP2.HTTP2ClientTransport.Posix>) async throws -> T
  ) async throws -> T {
    // Prefer an explicit port from the environment — needed for remote (SSH-tunneled) sessions
    // where the port file on the Mac server isn't visible on the client host.
    if let override = ProcessInfo.processInfo.environment["EIC_PORT"], let port = Int(override), port > 0 {
      ServerLauncher.debug("Connecting to gRPC server on EIC_PORT=\(port)")
      return try await Self.withGRPCClient(port: port, body)
    }
    guard let port = EICSocket.readPort() else {
      throw EICError.serverNotReachable
    }
    ServerLauncher.debug("Connecting to gRPC server on port \(port)")
    return try await Self.withGRPCClient(port: port, body)
  }

  private static func withGRPCClient<T: Sendable>(
    port: Int,
    _ body: @Sendable @escaping (Eic_V1_EditorService.Client<GRPCNIOTransportHTTP2.HTTP2ClientTransport.Posix>) async throws -> T
  ) async throws -> T {
    let transport = try HTTP2ClientTransport.Posix(
      target: .ipv4(host: "127.0.0.1", port: port),
      transportSecurity: .plaintext
    )
    let grpcClient = GRPCClient(transport: transport)
    let client = Eic_V1_EditorService.Client(wrapping: grpcClient)

    return try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        try await grpcClient.runConnections()
        throw CancellationError()
      }

      group.addTask {
        let result = try await body(client)
        grpcClient.beginGracefulShutdown()
        return result
      }

      guard let result = try await group.next() else {
        throw EICError.rpcFailed("No response from server")
      }
      group.cancelAll()
      return result
    }
  }
}

private extension Int32 {
  var boolValue: Bool { self != 0 }
}
