//
//  EditorDocument.swift
//  MarkEditMac
//
//  Created by cyan on 12/12/22.

import AppKit
import Foundation
import MarkEditKit
import TextBundle
import EICServer

/**
 Main document used to deal with markdown files and text bundles.

 https://developer.apple.com/documentation/appkit/nsdocument
 */
final class EditorDocument: NSDocument {
  var fileData: Data?
  var spellDocTag: Int?
  var stringValue = ""
  var formatCompleted = false // The result of format content is all good
  var isOutdated = false // The content is outdated, needs an update
  var isReadOnlyMode = false
  var isTerminating = false
  var lastSaveFailed = false
  var lastSaveError: String?

  // Per-document session properties (set by gRPC EditRequest)
  var sessionID: UUID?
  var sessionTitle: String?
  var sessionIsOutputMode = false
  var sessionIsDetached = false
  var sessionIsSudo = false
  var sessionIsRemote = false
  var sessionClientHostname: String?
  var sessionClientUser: String?

  var canUndo: Bool {
    get async {
      if isReadOnlyMode {
        return false
      }

      return (try? await bridge?.history.canUndo()) ?? false
    }
  }

  var canRedo: Bool {
    get async {
      if isReadOnlyMode {
        return false
      }

      return (try? await bridge?.history.canRedo()) ?? false
    }
  }

  var lineEndings: LineEndings? {
    get async {
      try? await bridge?.lineEndings.getLineEndings()
    }
  }

  var baseURL: URL? {
    textBundle != nil ? fileURL : folderURL
  }

  var textFileURL: URL? {
    fileURL?.appending(path: textBundle?.textFileName ?? "", directoryHint: .notDirectory)
  }

  var shouldSaveWhenIdle: Bool {
    false // MarkEdit InContext: no auto-save
  }

  private var autosaveDelayedTask: Task<Void, Never>?
  private var textBundle: TextBundleWrapper?
  private var revertedDate: Date = .distantPast
  private var suggestedTextEncoding: EditorTextEncoding?
  private weak var hostViewController: EditorViewController?

  /**
   File name from the table of contents.
   */
  private var suggestedFilename: String?

  /**
   File name from external apps, such as Shortcuts or URL schemes.
   */
  private var externalFilename: String?

  /**
   Title derived from the first `# ` heading in file content.
   */
  private var titleFromContent: String?

  override func makeWindowControllers() {
    let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
    let sceneIdentifier = NSStoryboard.SceneIdentifier("EditorWindowController")

    guard let windowController = storyboard.instantiateController(withIdentifier: sceneIdentifier) as? EditorWindowController else {
      return
    }

    // Note hostViewController is a weak reference, it must be strongly retained first
    let contentVC = EditorReusePool.shared.dequeueViewController()
    windowController.contentViewController = contentVC

    // Restore the autosaved window frame, which relies on windowFrameAutosaveName
    if let autosavedFrame = windowController.autosavedFrame {
      windowController.window?.setFrame(autosavedFrame, display: false)
    }

    isTerminating = false
    hostViewController = contentVC
    hostViewController?.representedObject = self

    externalFilename = AppDocumentController.suggestedFilename
    AppDocumentController.suggestedFilename = nil

    NSApplication.shared.closeOpenPanels()
    addWindowController(windowController)

    // Sudo sessions get a red titlebar strip as a visual warning
    if sessionIsSudo, let window = windowController.window {
      let accessory = NSTitlebarAccessoryViewController()
      let bar = NSView()
      bar.wantsLayer = true
      bar.layer?.backgroundColor = NSColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1.0).cgColor
      bar.translatesAutoresizingMaskIntoConstraints = false
      bar.heightAnchor.constraint(equalToConstant: 3).isActive = true
      accessory.view = bar
      accessory.layoutAttribute = .bottom
      window.addTitlebarAccessoryViewController(accessory)
    }

    // Remote sessions show the connecting user@host in the window subtitle
    // so it's obvious which machine the edit is operating on.
    if sessionIsRemote, let window = windowController.window {
      let user = sessionClientUser ?? "?"
      let host = sessionClientHostname ?? "?"
      let suffix = sessionIsSudo ? " (sudo)" : ""
      window.subtitle = "\(user)@\(host)\(suffix)"
    }

    #if DEBUG
      if ProcessInfo.processInfo.environment["DEBUG_TAKING_SCREENSHOTS"] == "YES" {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          windowController.window?.setFrameSize(CGSize(width: 720, height: 480))
          windowController.window?.center()
        }
      }
    #endif
  }

  func waitUntilSaveCompleted(userInitiated: Bool = false, delay: TimeInterval = 0.6) async {
    await withCheckedContinuation { continuation in
      saveContent(userInitiated: userInitiated) {
        continuation.resume()
      }
    }

    // It takes sometime to actually save the document
    await withCheckedContinuation { continuation in
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        continuation.resume()
      }
    }
  }

  func saveContent(sender: Any? = nil, userInitiated: Bool = false, completion: (() -> Void)? = nil) {
    Task { @MainActor in
      let saveAction = {
        super.save(sender)
        completion?()
      }

      if isOutdated || (userInitiated && needsFormatting) {
        updateContent(userInitiated: userInitiated, saveAction: saveAction)
      } else {
        saveAction()

        if userInitiated {
          markContentClean()
        }
      }
    }
  }

  func autosaveDelayed(seconds: Double = 0.25) {
    autosaveDelayedTask?.cancel()
    autosaveDelayedTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(seconds))
      if !Task.isCancelled {
        try? await self?.autosave(withImplicitCancellability: false)
      }
    }
  }

  func updateContent(userInitiated: Bool = false, saveAction: @escaping (() -> Void) = {}) {
    Task { @MainActor in
      await updateContent(userInitiated: userInitiated)
      saveAction()
    }
  }

  func prepareSpellDocTag() {
    guard spellDocTag == nil else {
      return
    }

    spellDocTag = NSSpellChecker.uniqueSpellDocumentTag()
  }
}

// MARK: - Overridden

extension EditorDocument {
  override class var autosavesInPlace: Bool {
    false
  }

  override class func canConcurrentlyReadDocuments(ofType type: String) -> Bool {
    true
  }

  override var fileURL: URL? {
    get {
      super.fileURL
    }
    set {
      let wasDraft = super.fileURL == nil && newValue != nil
      super.fileURL = newValue

      // Newly created files should have a clean state
      if wasDraft {
        Task { @MainActor in
          markContentDirty(false)
          hostViewController?.handleFileURLChange()
        }
      }
    }
  }

  override var displayName: String? {
    get {
      // Per-session title from gRPC request, or legacy --title flag
      if let title = sessionTitle ?? Application.launchTitle {
        return title
      }

      // Title from first-line # heading
      if let title = titleFromContent {
        return title
      }

      // Default file name for new drafts, pre-filled in the save panel
      if fileURL == nil, let newFileName = suggestedFilename ?? externalFilename {
        return newFileName
      }

      return super.displayName
    }
    set {
      super.displayName = newValue
    }
  }

  override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
    true
  }

  override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
    // MarkEdit InContext: always allow close without save dialog (discard-and-exit)
    if let shouldCloseSelector {
      let delegateObject = delegate as AnyObject
      let method = unsafeBitCast(
        delegateObject.method(for: shouldCloseSelector),
        to: (@convention(c) (AnyObject, Selector, NSDocument, Bool, UnsafeMutableRawPointer?) -> Void).self
      )
      method(delegateObject, shouldCloseSelector, self, true, contextInfo)
    }
  }

  override func close() {
    super.close()

    if let spellDocTag {
      NSSpellChecker.shared.closeSpellDocument(withTag: spellDocTag)
    }
  }

  override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
    // Include all markdown and plaintext types, but prioritize the configured default
    let exportedTypes = NewFilenameExtension.allCases
      .sorted { lhs, _ in
        lhs.rawValue == AppPreferences.General.newFilenameExtension.rawValue
      }
      .map { $0.exportedType }

    // Enable *.textbundle only when we have the bundle, typically for a duplicated draft
    return textBundle == nil ? exportedTypes : ["org.textbundle.package"] + exportedTypes
  }

  override func fileNameExtension(forType typeName: String, saveOperation: NSDocument.SaveOperationType) -> String? {
    if typeName.isTextBundle {
      return "textbundle"
    }

    return NewFilenameExtension.preferredExtension(for: typeName).rawValue
  }

  override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
    if let defaultDirectory = AppRuntimeConfig.defaultSaveDirectory {
      // Overriding savePanel.directoryURL does not work as intended
      NSDocumentController.shared.setOpenPanelDirectory(defaultDirectory)
    }

    if textBundle == nil {
      savePanel.accessoryView = EditorSaveOptionsView.wrapper(for: .savePanel) { [weak self, weak savePanel] result in
        switch result {
        case .fileExtension(let value):
          savePanel?.enforceUniformType(value.uniformType)
        case .textEncoding(let value):
          self?.suggestedTextEncoding = value
        }
      }
    } else {
      savePanel.accessoryView = nil
    }

    suggestedTextEncoding = nil
    savePanel.allowsOtherFileTypes = true
    return super.prepareSavePanel(savePanel)
  }
}

// MARK: - Reading and Writing

extension EditorDocument {
  override func read(from data: Data, ofType typeName: String) throws {
    DispatchQueue.global(qos: .userInitiated).async {
      let newValue = {
        if let encoding = AppDocumentController.suggestedTextEncoding {
          return encoding.decode(data: data)
        }

        let encoding = AppPreferences.General.defaultTextEncoding
        return encoding.decode(data: data, guessEncoding: true)
      }()

      // Extract title from first-line heading (# Title)
      let extractedTitle: String? = {
        guard let firstLine = newValue.components(separatedBy: .newlines).first,
              firstLine.hasPrefix("# ") else {
          return nil
        }
        let title = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
      }()

      DispatchQueue.main.async {
        self.fileData = data
        self.stringValue = newValue
        self.titleFromContent = extractedTitle
        self.hostViewController?.representedObject = self
      }
    }
  }

  // MarkEdit InContext: save behavior depends on session state and Option key.
  // Option key held → always save without closing (detach override).
  // Detached session → save without closing.
  // RPC session → sync content from editor, send back via gRPC (no disk write).
  // Legacy (no session) → save to disk and close.
  override func save(_ sender: Any?) {
    let optionHeld = NSEvent.modifierFlags.contains(.option)
    let isDetached = sessionIsDetached || Application.isDetached
    let shouldClose = !isDetached && !optionHeld

    if sessionID != nil {
      // RPC session: sync content from editor and send back via gRPC, no disk I/O
      Task { @MainActor in
        await updateContent(userInitiated: true)
        if shouldClose {
          notifySessionSaved()
          close()
        }
      }
    } else {
      // Legacy path: save to disk
      lastSaveFailed = false
      lastSaveError = nil
      saveContent(sender: sender, userInitiated: true) { [weak self] in
        guard let self else { return }
        if shouldClose {
          if self.lastSaveFailed {
            Task { @MainActor in
              let errorMessage = self.lastSaveError ?? "The file could not be saved."
              let response = await self.hostViewController?.showAlert(
                title: "Save Failed",
                message: errorMessage,
                buttons: ["Close Anyway", "Stay Open"]
              )
              if response == .alertFirstButtonReturn {
                self.close()
              }
            }
          } else {
            self.close()
          }
        }
      }
    }
  }

  override func autosave(withImplicitCancellability implicitlyCancellable: Bool) async throws {
    // MarkEdit InContext: autosave is disabled (explicit save only)
  }

  /// Save a Copy: present NSSavePanel, write to chosen path, keep editing original
  @IBAction func saveCopy(_ sender: Any?) {
    Task { @MainActor in
      // Sync content from WebView first
      await updateContent(userInitiated: true)

      let savePanel = NSSavePanel()
      savePanel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.md"
      savePanel.allowedContentTypes = [.plainText]
      savePanel.allowsOtherFileTypes = true

      guard let window = hostViewController?.view.window else {
        return
      }

      let response = await savePanel.beginSheetModal(for: window)
      guard response == .OK, let targetURL = savePanel.url else {
        return
      }

      do {
        let fileType = self.fileType ?? "net.daringfireball.markdown"
        try writeSafely(to: targetURL, ofType: fileType, for: .saveToOperation)
      } catch {
        Logger.log(.error, "Save a Copy failed: \(error.localizedDescription)")
      }
    }
  }

  override func data(ofType typeName: String) throws -> Data {
    let encoding = suggestedTextEncoding ?? AppPreferences.General.defaultTextEncoding
    return encoding.encode(string: stringValue) ?? stringValue.toData() ?? Data()
  }

  override func presentedItemDidChange() {
    guard let fileURL, let fileType else {
      return
    }

    // Only under certain conditions we need this flow,
    // e.g., editing in VS Code won't trigger the regular data(ofType...) reload
    DispatchQueue.main.async {
      do {
        // For text bundles, use the text.markdown file inside it
        let filePath = self.textBundle?.textFilePath(baseURL: fileURL) ?? fileURL.path
        let modificationDate = try FileManager.default.attributesOfItem(atPath: filePath)[.modificationDate] as? Date

        if let modificationDate, modificationDate > (self.fileModificationDate ?? .distantPast) {
          self.fileModificationDate = modificationDate
          try self.revert(toContentsOf: fileURL, ofType: fileType)
        }
      } catch {
        Logger.log(.error, error.localizedDescription)
      }
    }
  }

  override func revert(toContentsOf url: URL, ofType typeName: String) throws {
    revertedDate = .now
    try super.revert(toContentsOf: url, ofType: typeName)
  }
}

// MARK: - Text Bundle

extension EditorDocument {
  override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
    guard typeName.isTextBundle else {
      return try super.read(from: fileWrapper, ofType: typeName)
    }

    textBundle = try TextBundleWrapper(fileWrapper: fileWrapper)
    try read(from: textBundle?.data ?? Data(), ofType: typeName)
  }

  override func write(to url: URL, ofType typeName: String) throws {
    do {
      if typeName.isTextBundle {
        let fileWrapper = try? textBundle?.fileWrapper(with: try data(ofType: typeName))
        try fileWrapper?.write(to: url, originalContentsURL: nil)
      } else {
        try super.write(to: url, ofType: typeName)
      }
    } catch {
      lastSaveFailed = true
      lastSaveError = error.localizedDescription
      Logger.log(.error, "Save failed: \(error.localizedDescription)")
      throw error
    }
  }

  override func duplicate() throws -> NSDocument {
    guard textBundle != nil, let fileURL else {
      return try super.duplicate()
    }

    return try NSDocumentController.shared.duplicateDocument(
      withContentsOf: fileURL,
      copying: true,
      displayName: fileURL.deletingPathExtension().lastPathComponent
    )
  }
}

// MARK: - Printing

extension EditorDocument {
  @IBAction override func printDocument(_ sender: Any?) {
    guard let window = hostViewController?.view.window else {
      return
    }

    // Ideally we should be able to print WKWebView,
    // but it doesn't work well because of the lazily rendering strategy used in CodeMirror.
    //
    // For now let's just print plain text,
    // we don't expect printing to be used a lot.

    Task { @MainActor in
      // Alignment
      printInfo.isHorizontallyCentered = true
      printInfo.isVerticallyCentered = false

      // Sizing
      let width = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
      let height = printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin
      let frame = CGRect(x: 0, y: 0, width: width, height: height)

      // Rendering
      let textView = NSTextView(frame: frame)
      textView.string = await hostViewController?.editorText ?? stringValue
      textView.sizeToFit()

      let operation = NSPrintOperation(view: textView)
      operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }
  }
}

// MARK: - Session Manager

extension EditorDocument {
  func notifySessionSaved() {
    guard let sessionID else { return }
    EditSessionManager.shared.notifySaved(sessionID: sessionID, content: stringValue)
    self.sessionID = nil
  }

  func notifySessionDiscarded() {
    guard let sessionID else { return }
    EditSessionManager.shared.notifyDiscarded(sessionID: sessionID)
    self.sessionID = nil
  }

  func notifySessionError(_ message: String) {
    guard let sessionID else { return }
    EditSessionManager.shared.notifyError(sessionID: sessionID, message: message)
    self.sessionID = nil
  }
}

// MARK: - Private

private extension EditorDocument {
  var bridge: WebModuleBridge? {
    hostViewController?.bridge
  }

  var hasBeenReverted: Bool {
    Date.now.timeIntervalSince(revertedDate) < 1
  }

  var needsFormatting: Bool {
    guard !formatCompleted else {
      return false
    }

    return AppPreferences.Assistant.insertFinalNewline || AppPreferences.Assistant.trimTrailingWhitespace
  }

  func updateContent(userInitiated: Bool = false) async {
    let insertFinalNewline = AppPreferences.Assistant.insertFinalNewline
    let trimTrailingWhitespace = AppPreferences.Assistant.trimTrailingWhitespace

    // Format when saving files, only if at least one option is enabled
    if insertFinalNewline || trimTrailingWhitespace {
      formatCompleted = (try? await bridge?.format.formatContent(
        insertFinalNewline: insertFinalNewline,
        trimTrailingWhitespace: trimTrailingWhitespace,
        userInitiated: userInitiated
      )) ?? false
    }

    if let editorText = await hostViewController?.editorText {
      stringValue = editorText

      DispatchQueue.global(qos: .utility).async {
        let fileData = editorText.toData() ?? Data()
        let directory = AppCustomization.debugDirectory.fileURL
        try? fileData.write(to: directory.appending(path: "last-edited.md"))
      }
    }

    // If the content contains headings, use the first one to override the displayName
    if fileURL == nil, let heading = await hostViewController?.tableOfContents?.first {
      suggestedFilename = heading.title
    } else {
      suggestedFilename = nil
    }

    isOutdated = false
    unblockUserInteraction()

    if userInitiated {
      markContentClean()
    }
  }

  func markContentClean() {
    bridge?.history.markContentClean()
  }

  @objc func confirmsChanges(_ document: EditorDocument, shouldClose: Bool) {
    guard shouldClose else {
      return // Cancelled
    }

    let performClose = {
      // isReleasedWhenClosed is not initially set to true to prevent crashes when deleting drafts.
      // However, we need to release the window in the confirmsChanges function;
      // otherwise, it will cause a memory leak.
      document.windowControllers.forEach {
        $0.window?.isReleasedWhenClosed = true
      }

      document.close()
    }

    if document.hasBeenReverted || !document.isDocumentEdited {
      // Reverted or no unsaved changes
      performClose()
    } else {
      // Delay this for two reasons:
      //  1. To make it clear to users that their changes are saved
      //  2. To avoid leftover .sb copies when a document is closed too quickly
      let closeDelayed = {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: performClose)
      }

      // Saved
      document.saveContent(userInitiated: true, completion: closeDelayed)
    }
  }
}
