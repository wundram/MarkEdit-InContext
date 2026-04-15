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

  // MarkEdit InContext: disable recent documents tracking entirely
  override var maximumRecentDocumentCount: Int { 0 }

  override func noteNewRecentDocument(_ document: NSDocument) {
    // No-op: don't track recent documents
  }

  override func noteNewRecentDocumentURL(_ url: URL) {
    // No-op: don't track recent documents
  }

  override init() {
    super.init()
    clearRecentDocuments(nil)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    clearRecentDocuments(nil)
  }

  // MarkEdit InContext: prevent creating new documents
  override func newDocument(_ sender: Any?) {
    // No-op: single-file editor
  }

  // MarkEdit InContext: prevent opening additional documents via menu
  override func openDocument(_ sender: Any?) {
    // No-op: single-file editor
  }

  override func openDocument(
    withContentsOf url: URL,
    display displayDocument: Bool,
    completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void
  ) {
    Task { @MainActor in
      // Ensure the reuse pool has a fully loaded editor before opening the document
      await EditorReusePool.shared.prepareViewController()

      super.openDocument(
        withContentsOf: url,
        display: displayDocument,
        completionHandler: completionHandler
      )
    }
  }
}
