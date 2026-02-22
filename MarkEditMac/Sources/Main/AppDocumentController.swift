//
//  AppDocumentController.swift
//  MarkEditMac
//
//  Created by cyan on 10/14/24.
//

import AppKit
import MarkEditKit

/**
 Subclass of `NSDocumentController` to allow customizations.

 NSDocumentController.shared will be an instance of `AppDocumentController` at runtime.
 */
final class AppDocumentController: NSDocumentController {
  static var suggestedTextEncoding: EditorTextEncoding?
  static var suggestedFilename: String?

  // MarkEdit Modal: prevent creating new documents
  override func newDocument(_ sender: Any?) {
    // No-op: single-file editor
  }

  // MarkEdit Modal: prevent opening additional documents via menu
  override func openDocument(_ sender: Any?) {
    // No-op: single-file editor
  }
}
