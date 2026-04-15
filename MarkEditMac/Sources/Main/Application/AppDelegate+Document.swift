//
//  AppDelegate+Document.swift
//  MarkEditMac
//
//  Created by cyan on 1/15/23.
//

import AppKit
import MarkEditKit
import EICServer

@MainActor
extension AppDelegate {
  var currentDocument: EditorDocument? {
    currentEditor?.document
  }

  var currentEditor: EditorViewController? {
    NSApp.currentEditor
  }

  func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
    // MarkEdit InContext: never open untitled files automatically
    false
  }

  func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    // MarkEdit InContext: no dock menu (single-file editor)
    nil
  }

  /// Open a file from the launch path. If the file doesn't exist, open an empty buffer
  /// with the fileURL set so Save creates it.
  func openLaunchFile(path: String, session: EditSession? = nil, title: String? = nil, isOutputMode: Bool = false, isDetached: Bool = false) {
    let fileURL = URL(fileURLWithPath: path)
    (NSApp.delegate as? AppDelegate)?.eicLog("openLaunchFile path=\(path) exists=\(FileManager.default.fileExists(atPath: path)) session=\(session?.id.uuidString ?? "nil")")

    if FileManager.default.fileExists(atPath: path) {
      // Existing file: open it via the document controller
      NSDocumentController.shared.openDocument(withContentsOf: fileURL, display: true) { document, _, error in
        (NSApp.delegate as? AppDelegate)?.eicLog("openDocument callback: doc=\(String(describing: document)) error=\(String(describing: error)) wcs=\(document?.windowControllers.count ?? -1)")
        if let error {
          Logger.log(.error, "Failed to open file: \(error.localizedDescription)")
        }
        if let doc = document as? EditorDocument {
          doc.sessionID = session?.id
          doc.sessionTitle = title
          doc.sessionIsOutputMode = isOutputMode
          doc.sessionIsDetached = isDetached
          // Ensure window is visible and app is frontmost
          doc.showWindows()
          NSApp.activate()
        }
      }
    } else {
      // Nonexistent file: create an empty document with the target fileURL
      let document = EditorDocument()
      document.stringValue = ""
      document.fileURL = fileURL
      document.sessionID = session?.id
      document.sessionTitle = title
      document.sessionIsOutputMode = isOutputMode
      document.sessionIsDetached = isDetached
      NSDocumentController.shared.addDocument(document)
      document.makeWindowControllers()
      document.showWindows()
    }
  }

  func createNewFile(queryDict: [String: String]?) {
    // MarkEdit InContext: URL scheme support for opening files
    if let filePath = queryDict?["path"] ?? queryDict?["filename"] {
      openLaunchFile(path: filePath)
    }
  }

  func openFile(queryDict: [String: String]?) {
    if let filePath = queryDict?["path"] {
      openLaunchFile(path: filePath)
    }
  }

  // Stub for compatibility with menu actions until Phase 4 removes the menu items
  func createNewFile(fileName: String? = nil, initialContent: String? = nil, isIntent: Bool = false) {
    // No-op in MarkEdit InContext
  }
}
