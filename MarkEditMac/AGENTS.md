# MarkEditMac — Agent Guide

This is the main macOS application target (Swift / AppKit).

## Structure

```
Sources/
  Main/           App delegate, entry point
  Editor/         Editor view controllers and views (hosts the WKWebView)
  Settings/       Preferences UI
  Panels/         Find/Replace panels
  Scripting/      AppleScript support
  Shortcuts/      Shortcuts.app integration
  Updater/        Auto-update mechanism
  Extensions/     Swift extensions on Foundation/AppKit types
  ObjC/           Objective-C bridge utilities

Modules/          SPM feature packages (see below)
Resources/        Assets, nibs, plists
```

## Modules (SPM Packages)

Located in `Modules/Sources/`, each is a separate SPM target:

| Module | Purpose |
|--------|---------|
| AppKitControls | Custom macOS UI controls |
| AppKitExtensions | NSView, NSColor, NSFont helpers |
| DiffKit | Text diffing utilities |
| FileVersion | File version management |
| FontPicker | Font selection UI |
| Previewer | Markdown preview rendering |
| SettingsUI | Preferences interface |
| Statistics | Word/character count |
| TextBundle | TextBundle format support |
| TextCompletion | Auto-completion engine |

Tests live in `Modules/Tests/` (scheme: `ModulesTests`).

## Swift Conventions

- **Swift 6.0+** with `StrictConcurrency` enabled.
- **SwiftLint** runs as a build plugin on every target — see `.swiftlint.yml` at repo root.
- **File header format**:
  ```swift
  //
  //  FileName.swift
  //  TargetName
  //
  //  Created by author on date
  ```
- **2-space indentation**. Trailing commas in multiline collections.
- **`private` over `fileprivate`**. No force unwrapping or force casting.
- **`@MainActor`** on UI classes. Strict concurrency throughout.
- **Protocol conformances** go in extensions.
- **Caseless enums** for types hosting only static members.
- **`Self`** over `type(of: self)` and over explicit type names in static context.

## Building

```bash
xcodebuild build -project MarkEdit.xcodeproj -scheme MarkEditMac -destination 'platform=macOS'
```

CoreEditor must be built first (`yarn build` in `CoreEditor/`) — its output is bundled into the app.

## Integration with CoreEditor

The editor UI is a WKWebView loading the Vite-built bundle. Communication flows through:

- **Swift -> Web**: `WebBridge*` classes in `MarkEditKit` call JavaScript functions
- **Web -> Swift**: `EditorModule*` classes in `MarkEditKit` handle incoming messages

See `MarkEditKit/AGENTS.md` for bridge details.
