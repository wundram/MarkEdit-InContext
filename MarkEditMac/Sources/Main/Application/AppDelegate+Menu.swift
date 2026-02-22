//
//  AppDelegate+Menu.swift
//  MarkEditMac
//
//  Created by cyan on 1/15/23.
//

import AppKit
import MarkEditKit

extension AppDelegate: NSMenuDelegate {
  func menuNeedsUpdate(_ menu: NSMenu) {
    switch menu {
    case mainEditMenu:
      reconfigureMainEditMenu(document: currentDocument)
    case mainExtensionsMenu:
      reconfigureMainExtensionsMenu(document: currentDocument)
    case mainWindowMenu:
      reconfigureMainWindowMenu(document: currentDocument)
    default:
      break
    }
  }
}

// MARK: - Private

private extension AppDelegate {
  func reconfigureMainEditMenu(document: EditorDocument?) {
    Task { @MainActor in
      guard let document else {
        return
      }

      editUndoItem?.isEnabled = await document.canUndo
      editRedoItem?.isEnabled = await document.canRedo
      editPasteItem?.isEnabled = NSPasteboard.general.hasText
    }

    editTypewriterItem?.setOn(AppPreferences.Editor.typewriterMode)
  }

  func reconfigureMainExtensionsMenu(document: EditorDocument?) {
    mainExtensionsMenu?.items.forEach {
      let isEnabled = $0.target === NSApp.appDelegate || document != nil
      $0.setEnabledRecursively(isEnabled: isEnabled)
    }
  }

  func reconfigureMainWindowMenu(document: EditorDocument?) {
    windowFloatingItem?.isEnabled = NSApp.keyWindow is EditorWindow
    windowFloatingItem?.setOn(NSApp.keyWindow?.level == .floating)
  }
}

// MARK: - Private

private extension AppDelegate {
  @IBAction func openDocumentsFolder(_ sender: Any?) {
    NSWorkspace.shared.open(URL.documentsDirectory)
  }

  @IBAction func openDevelopmentGuide(_ sender: Any?) {
    NSWorkspace.shared.safelyOpenURL(string: "https://github.com/MarkEdit-app/MarkEdit/wiki/Development")
  }

  @IBAction func openCustomizationGuide(_ sender: Any?) {
    NSWorkspace.shared.safelyOpenURL(string: "https://github.com/MarkEdit-app/MarkEdit/wiki/Customization")
  }

  @IBAction func showHelp(_ sender: Any?) {
    NSWorkspace.shared.safelyOpenURL(string: "https://github.com/MarkEdit-app/MarkEdit/wiki")
  }

  @IBAction func openIssueTracker(_ sender: Any?) {
    NSWorkspace.shared.safelyOpenURL(string: "https://github.com/MarkEdit-app/MarkEdit/issues")
  }

  @IBAction func openVersionHistory(_ sender: Any?) {
    NSWorkspace.shared.safelyOpenURL(string: "https://github.com/MarkEdit-app/MarkEdit/releases")
  }
}
