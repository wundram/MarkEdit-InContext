import Foundation

public enum EICSocket {
  public static let directoryPath: String = {
    // Use the real home directory, not the sandbox container path.
    // getpwuid returns the actual home even in sandboxed apps.
    let home: String
    if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
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
