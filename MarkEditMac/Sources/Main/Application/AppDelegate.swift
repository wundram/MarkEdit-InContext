//
//  AppDelegate.swift
//  MarkEditMac
//
//  Created by cyan on 12/12/22.

import AppKit
import AppKitExtensions
import SettingsUI
import MarkEditKit
import EICServer
import EICShared

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, EICServiceDelegate {
  @IBOutlet weak var mainFileMenu: NSMenu?
  @IBOutlet weak var mainEditMenu: NSMenu?
  @IBOutlet weak var mainWindowMenu: NSMenu?

  @IBOutlet weak var editCommandsMenu: NSMenu?
  @IBOutlet weak var editTableOfContentsMenu: NSMenu?
  @IBOutlet weak var editFontMenu: NSMenu?
  @IBOutlet weak var editFindMenu: NSMenu?
  @IBOutlet weak var textFormatMenu: NSMenu?
  @IBOutlet weak var formatHeadersMenu: NSMenu?

  @IBOutlet weak var editUndoItem: NSMenuItem?
  @IBOutlet weak var editRedoItem: NSMenuItem?
  @IBOutlet weak var editPasteItem: NSMenuItem?
  @IBOutlet weak var editGotoLineItem: NSMenuItem?
  @IBOutlet weak var editReadOnlyItem: NSMenuItem?
  @IBOutlet weak var editStatisticsItem: NSMenuItem?
  @IBOutlet weak var editTypewriterItem: NSMenuItem?
  @IBOutlet weak var formatBulletItem: NSMenuItem?
  @IBOutlet weak var formatNumberingItem: NSMenuItem?
  @IBOutlet weak var formatTodoItem: NSMenuItem?
  @IBOutlet weak var formatCodeItem: NSMenuItem?
  @IBOutlet weak var formatCodeBlockItem: NSMenuItem?
  @IBOutlet weak var formatMathItem: NSMenuItem?
  @IBOutlet weak var formatMathBlockItem: NSMenuItem?
  @IBOutlet weak var windowFloatingItem: NSMenuItem?
  @IBOutlet weak var saveMenuItem: NSMenuItem?

  private var appearanceObservation: NSKeyValueObservation?
  private var settingsWindowController: NSWindowController?
  private(set) var serverManager: EICServerManager?

  func applicationWillFinishLaunching(_ notification: Notification) {
    EditorReusePool.shared.warmUp()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.appearance = AppPreferences.General.appearance.resolved()
    appearanceObservation = NSApp.observe(\.effectiveAppearance) { _, _ in
      Task { @MainActor in
        AppTheme.current.updateAppearance()
      }
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidResignKey(_:)),
      name: NSWindow.didResignKeyNotification,
      object: nil
    )

    // App level setting for "Ask to keep changes when closing documents"
    if let closeAlwaysConfirmsChanges = AppRuntimeConfig.closeAlwaysConfirmsChanges {
      UserDefaults.standard.set(closeAlwaysConfirmsChanges, forKey: NSCloseAlwaysConfirmsChanges)
    } else {
      UserDefaults.standard.removeObject(forKey: NSCloseAlwaysConfirmsChanges)
    }

    // Update menu item title based on launch context
    saveMenuItem?.title = Application.saveActionLabel

    // MarkEdit InContext: open settings or file from command line
    if Application.launchIntoSettings {
      showPreferences(nil)
    } else if let filePath = Application.launchFilePath {
      openLaunchFile(path: filePath)
    }

    // Install uncaught exception handler
    AppExceptionCatcher.install()

    // Start gRPC server for CLI communication
    let manager = EICServerManager(delegate: self)
    self.serverManager = manager
    manager.start()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // App stays running as a persistent server
    false
  }

  func applicationShouldTerminate(_ application: NSApplication) -> NSApplication.TerminateReply {
    // Drain all pending edit sessions so CLI clients receive their discard responses
    // before we tear down the gRPC server.
    EditSessionManager.shared.discardAll()

    Task { @MainActor in
      // Give NIO time to flush the responses to connected clients
      try? await Task.sleep(for: .milliseconds(200))
      self.serverManager?.stop()
      NSApp.reply(toApplicationShouldTerminate: true)
    }

    return .terminateLater
  }

  func applicationWillTerminate(_ notification: Notification) {
    EICSocket.removePortFile()
  }

  func shouldOpenOrCreateDocument() -> Bool {
    if let settingsWindow = settingsWindowController?.window {
      // We don't open or create documents when the settings pane is the key and visible
      return !(settingsWindow.isKeyWindow && settingsWindow.isVisible)
    }

    return true
  }
}

// MARK: - URL Handling

extension AppDelegate {
  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      switch components?.host {
      case "new-file":
        // eic://new-file?filename=Untitled&initial-content=Hello
        createNewFile(queryDict: components?.queryDict)
      case "open":
        // eic://open or eic://open?path=Untitled.md
        openFile(queryDict: components?.queryDict)
      default:
        break
      }
    }
  }
}

// MARK: - EICServiceDelegate

extension AppDelegate {
  func eicLog(_ message: String) {
    let path = EICSocket.directoryPath + "/debug.log"
    let line = "\(Date()) [AppDelegate]: \(message)\n"
    if let handle = FileHandle(forWritingAtPath: path) {
      handle.seekToEndOfFile()
      handle.write(Data(line.utf8))
      handle.closeFile()
    } else {
      try? line.write(toFile: path, atomically: true, encoding: .utf8)
    }
  }

  func openEditSession(_ session: EditSession) async {
    eicLog("openEditSession called, id=\(session.id)")
    let request = session.request
    let title = request.title.isEmpty ? nil : request.title

    // All file I/O is handled by the CLI. The app only works with content in memory.
    let document = EditorDocument()
    document.stringValue = request.initialContent
    document.sessionID = session.id
    document.sessionTitle = title
    document.sessionIsOutputMode = request.stdoutPiped || request.noSave
    document.sessionIsDetached = request.detach
    document.sessionIsSudo = request.sudo
    NSDocumentController.shared.addDocument(document)
    document.makeWindowControllers()
    document.showWindows()
    NSApp.activate()
  }

  func openSettings() {
    showPreferences(nil)
  }

  func quitApp() {
    NSApp.terminate(nil)
  }
}

// MARK: - Private

private extension AppDelegate {
  @objc func windowDidResignKey(_ notification: Notification) {
    // To reduce the glitches between switching windows,
    // close openPanel once we don't have any key windows.
    //
    // Delay because there's no keyWindow during window transitions.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      if NSApp.windows.allSatisfy({ !$0.isKeyWindow }) {
        NSApp.closeOpenPanels()
      }
    }
  }

  @IBAction func showPreferences(_ sender: Any?) {
    if settingsWindowController == nil {
      settingsWindowController = SettingsRootViewController.withTabs([
        .editor,
        .assistant,
        .general,
        .window,
      ])

      // The window size relies on the SwiftUI content view size, it takes time
      DispatchQueue.main.async {
        self.settingsWindowController?.showWindow(self)
      }
    } else {
      settingsWindowController?.showWindow(self)
    }
  }

  @IBAction func openSettingsJSON(_ sender: Any?) {
    NSWorkspace.shared.open(AppCustomization.settings.fileURL)
  }
}
