<picture>
  <source media="(prefers-color-scheme: light)" srcset="./Icon.png" width="128">
  <source media="(prefers-color-scheme: dark)" srcset="./Icon-dark.png" width="128">
  <img src="./Icon.png" width="128">
</picture>

# MarkEdit Modal

[![macOS 15+](https://img.shields.io/badge/macOS-15.0+-007bff)](https://github.com/nicwundram/MarkEdit-modal)

A CLI-launched modal Markdown editor for macOS, forked from [MarkEdit](https://github.com/MarkEdit-app/MarkEdit).

## How it differs from MarkEdit

MarkEdit Modal strips MarkEdit down to a single-purpose tool: edit one Markdown file at a time, launched from the terminal.

- **Single-file, CLI-launched** — `mem <file>` opens the file; closing the window quits the app
- **Three operations only** — Save & Exit (`Cmd+S`), Discard & Exit (`Cmd+Q`), Save a Copy (`Cmd+Shift+S`)
- **No autosave** — your file is never written to disk until you explicitly save
- **No tabs, no recent documents, no Dock menu**
- **No updater, Shortcuts, or AppleScript**
- **Same editor core** — CodeMirror 6, themes, syntax highlighting, completions, and all editor settings

## Installation

### Homebrew (recommended)

```sh
brew install --no-quarantine nicwundram/tap/markedit-modal
```

The `--no-quarantine` flag skips Gatekeeper since the app is ad-hoc signed (see [Gatekeeper note](#gatekeeper) below).

### Manual

1. Download `MarkEdit-Modal-<version>.zip` from the [latest release](https://github.com/nicwundram/MarkEdit-modal/releases/latest)
2. Unzip and move `MarkEdit Modal.app` to `/Applications`
3. Copy `Tools/mem` to somewhere on your `$PATH` (e.g. `/usr/local/bin/mem`)
4. Allow the app in **System Settings > Privacy & Security** on first launch

## Gatekeeper

MarkEdit Modal is ad-hoc signed (`CODE_SIGN_IDENTITY = -`), which means macOS Gatekeeper will block it on first launch. To allow it:

1. Try to open the app — macOS will show a warning
2. Go to **System Settings > Privacy & Security**
3. Click **Open Anyway** next to the MarkEdit Modal message

With Homebrew, `--no-quarantine` skips this entirely. For seamless distribution without this step, an Apple Developer ID certificate + notarization would be needed.

## Usage

```sh
# Edit an existing file
mem file.md

# Create and edit a new file
mem newfile.md

# Open settings
mem --settings
```

When no arguments are given, `mem` prints usage help.

## Screenshots

![Light theme](/Screenshots/01.png)

![Dark theme](/Screenshots/02.png)

## Acknowledgments

Built on [CodeMirror 6](https://codemirror.net/). Forked from [MarkEdit](https://github.com/MarkEdit-app/MarkEdit) by [@aspect-build](https://github.com/nicwundram).
