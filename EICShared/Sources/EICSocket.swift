import Foundation

public enum EICSocket {
  public static let directoryPath: String = {
    // Resolve the real user's home directory, handling three cases:
    // 1. sudo: SUDO_USER is set — look up that user's home via getpwnam
    // 2. Sandboxed app: getpwuid gives real home (not the container)
    // 3. Normal CLI: getpwuid gives the current user's home
    let home: String
    if let sudoUser = ProcessInfo.processInfo.environment["SUDO_USER"],
       let pw = getpwnam(sudoUser), let dir = pw.pointee.pw_dir {
      home = String(cString: dir)
    } else if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
      home = String(cString: dir)
    } else {
      home = NSHomeDirectory()
    }
    return "\(home)/.eic"
  }()

  public static let portFilePath: String = {
    return "\(directoryPath)/eic.port"
  }()

  public static func ensureDirectoryExists() throws {
    try FileManager.default.createDirectory(
      atPath: directoryPath,
      withIntermediateDirectories: true
    )
  }

  public static func writePort(_ port: Int) throws {
    try ensureDirectoryExists()
    try "\(port)".write(toFile: portFilePath, atomically: true, encoding: .utf8)
  }

  public static func readPort() -> Int? {
    guard let content = try? String(contentsOfFile: portFilePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
          let port = Int(content) else {
      return nil
    }
    return port
  }

  public static func removePortFile() {
    try? FileManager.default.removeItem(atPath: portFilePath)
  }
}
