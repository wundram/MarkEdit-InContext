//
//  Application.swift
//  MarkEditMac
//
//  Created by cyan on 4/24/24.
//

import AppKit
import MarkEditKit

@main
final class Application: NSApplication {
  /// File path passed via command line arguments
  static var launchFilePath: String?
  /// Whether the app was launched with --settings to show preferences only
  static var launchIntoSettings = false
  /// Window title passed via --title command line argument
  static var launchTitle: String?
  /// Whether launched in output mode (stdout/no-save context)
  static var isOutputMode = false
  /// Whether launched in detached mode (--detach context)
  static var isDetached = false

  /// Label for the save/exit action based on launch context
  static var saveActionLabel: String {
    switch (isOutputMode, isDetached) {
    case (false, false): return "Save and Exit"
    case (true, false):  return "Output and Exit"
    case (false, true):  return "Save"
    case (true, true):   return "Output"
    }
  }

  /// Asset name for the save/exit toolbar icon
  static var saveActionIcon: String {
    switch (isOutputMode, isDetached) {
    case (false, false): return "save-and-exit"
    case (true, false):  return "output-and-exit"
    case (false, true):  return "save-detach"
    case (true, true):   return "output-detach"
    }
  }

  var currentEditor: EditorViewController? {
    keyWindow?.contentViewController as? EditorViewController
  }

  static func main() {
    // Parse command line arguments before anything else.
    let args = Array(CommandLine.arguments.dropFirst())

    // Check for --settings flag first
    if args.contains("--settings") {
      launchIntoSettings = true
    } else {
      // Parse --title <value>
      if let titleIndex = args.firstIndex(of: "--title"),
         titleIndex + 1 < args.count {
        launchTitle = args[titleIndex + 1]
      }

      // Parse --context <value> (comma-separated: stdout, detach)
      if let ctxIndex = args.firstIndex(of: "--context"),
         ctxIndex + 1 < args.count {
        let ctx = args[ctxIndex + 1].split(separator: ",").map(String.init)
        isOutputMode = ctx.contains("stdout")
        isDetached = ctx.contains("detach")
      }

      // Filter out known flags and their values to find the file arg
      var i = 0
      while i < args.count {
        if args[i] == "--title" || args[i] == "--context" {
          i += 2 // skip flag + value
        } else if args[i].hasPrefix("-") {
          i += 1 // skip unknown flags
        } else {
          // Resolve to absolute path
          let url = URL(fileURLWithPath: args[i])
          launchFilePath = url.standardizedFileURL.path
          break
        }
      }
    }

    NSObject.swizzleAccessibilityBundlesOnce
    NSMenu.swizzleIsUpdatedExcludingContentTypesOnce
    NSSpellChecker.swizzleInlineCompletionEnabledOnce
    NSSpellChecker.swizzleShowCompletionForCandidateOnce
    NSSpellChecker.swizzleCorrectionIndicatorOnce

    UserDefaults.overwriteTextCheckerOnce()
    AppCustomization.createFiles()

    // Must after AppCustomization.createFiles()
    Bundle.swizzleInfoDictionaryOnce

    let application = Self.shared
    let delegate = AppDelegate()

    application.delegate = delegate

    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
  }

  override func sendAction(_ action: Selector, to target: Any?, from sender: Any?) -> Bool {
    if action == #selector(NSText.paste(_:)) {
      sanitizePasteboard()
    }

    // Ensure lines are fully selected for a better Writing Tools experience
    if #available(macOS 15.1, *), action == sel_getUid("showWritingTools:") {
      Logger.assert(sender is NSMenuItem, "Invalid sender was found")
      Logger.assert(target == nil || (target as? AnyObject)?.className == "WKMenuTarget", "Invalid target was found")

      if MarkEditWritingTools.shouldReselect(withItem: sender) {
        ensureWritingToolsSelectionRect()
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        super.sendAction(action, to: target, from: sender)
      }

      return true
    }

    return super.sendAction(action, to: target, from: sender)
  }
}

// MARK: - Private

private extension Application {
  func sanitizePasteboard() {
    let textContent = currentEditor?.document?.stringValue
    let lineEndings = AppPreferences.General.defaultLineEndings.characters
    NSPasteboard.general.sanitize(lineBreak: textContent?.getLineBreak(defaultValue: lineEndings))
  }

  func ensureWritingToolsSelectionRect() {
    guard let currentEditor else {
      return Logger.assertFail("Invalid keyWindow was found")
    }

    currentEditor.ensureWritingToolsSelectionRect()
  }
}
