//
//  AppDelegate+Document.swift
//  MarkEditMac
//
//  Created by cyan on 1/15/23.
//

import AppKit
import MarkEditKit

@MainActor
extension AppDelegate {
  var currentDocument: EditorDocument? {
    currentEditor?.document
  }

  var currentEditor: EditorViewController? {
    (NSApp as? Application)?.currentEditor
  }

  func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
    // MarkEdit Modal: never open untitled files automatically
    false
  }

  func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    // MarkEdit Modal: no dock menu (single-file editor)
    nil
  }

  /// Open a file from the launch path. If the file doesn't exist, open an empty buffer
  /// with the fileURL set so Save creates it.
  func openLaunchFile(path: String) {
    let fileURL = URL(fileURLWithPath: path)

    if FileManager.default.fileExists(atPath: path) {
      // Existing file: open it via the document controller
      NSDocumentController.shared.openDocument(withContentsOf: fileURL, display: true) { _, _, error in
        if let error {
          Logger.log(.error, "Failed to open file: \(error.localizedDescription)")
        }
      }
    } else {
      // Nonexistent file: create an empty document with the target fileURL
      let document = EditorDocument()
      document.stringValue = ""
      document.fileURL = fileURL
      NSDocumentController.shared.addDocument(document)
      document.makeWindowControllers()
      document.showWindows()
    }
  }

  func createNewFile(queryDict: [String: String]?) {
    // MarkEdit Modal: URL scheme support for opening files
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
    // No-op in MarkEdit Modal
  }
}
