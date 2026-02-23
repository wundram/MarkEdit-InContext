<picture>
  <source media="(prefers-color-scheme: light)" srcset="./Icon.png" width="128">
  <source media="(prefers-color-scheme: dark)" srcset="./Icon-dark.png" width="128">
  <img src="./Icon.png" width="128">
</picture>

# MarkEdit InContext

[![macOS 15+](https://img.shields.io/badge/macOS-15.0+-007bff)](https://github.com/wundram/MarkEdit-InContext)

A CLI-launched, in-context Markdown editor for macOS, forked from [MarkEdit](https://github.com/MarkEdit-app/MarkEdit).

Edit text in context — in the middle of a pipe chain, as a git editor, or as a quick-edit tool. The CLI command `eic` (Edit In Context) opens a file, blocks the terminal until you save or discard, and optionally pipes content through stdin/stdout.

## Why this exists

AI agentic workflows increasingly need human-in-the-loop editing — reviewing a generated commit message, tweaking prompt text, fixing a comment before it's posted. These are small, contextual edits that happen in the middle of a pipeline, not inside a project.

The default tool for this is usually a vi/vim variant, which is a poor fit for casual editing. Full editors like VS Code work, but they open into their own file/folder context — confusing when the file you're editing is a temp file with a random name in `/tmp`. And editing directly in the terminal is fragile; one accidental Enter keypress can submit half-written text.

MarkEdit InContext fills this gap: a native macOS editor that opens fast, blocks the calling process, integrates with pipes and git, and gets out of the way when you're done. It's designed for the edit-and-return pattern, not for project management.

## How it differs from MarkEdit

MarkEdit InContext strips MarkEdit down to a single-purpose tool: edit one file at a time, launched from the terminal.

- **Single-file, CLI-launched** — `eic <file>` opens the file; closing the window quits the app
- **Blocking by default** — the terminal waits until you save (`Cmd+S`) or discard (`Cmd+Q`)
- **Pipe-aware** — reads from stdin, writes to stdout, works in pipe chains
- **Git-ready** — `GIT_EDITOR=eic` works out of the box with auto-detected titles
- **Three operations only** — Save & Exit (`Cmd+S`), Discard & Exit (`Cmd+Q`), Save a Copy (`Cmd+Shift+S`)
- **No autosave** — your file is never written to disk until you explicitly save
- **No tabs, no recent documents, no Dock menu**
- **Same editor core** — CodeMirror 6, themes, syntax highlighting, completions, and all editor settings

## Installation

### Homebrew (recommended)

```sh
brew install --no-quarantine wundram/tap/markedit-in-context
```

The `--no-quarantine` flag skips Gatekeeper since the app is ad-hoc signed (see [Gatekeeper note](#gatekeeper) below).

### Manual

1. Download `MarkEdit-InContext-<version>.zip` from the [latest release](https://github.com/wundram/MarkEdit-InContext/releases/latest)
2. Unzip and move `MarkEdit InContext.app` to `/Applications`
3. Copy `Tools/eic` to somewhere on your `$PATH` (e.g. `/usr/local/bin/eic`)
4. Allow the app in **System Settings > Privacy & Security** on first launch

## Gatekeeper

MarkEdit InContext is ad-hoc signed (`CODE_SIGN_IDENTITY = -`), which means macOS Gatekeeper will block it on first launch. To allow it:

1. Try to open the app — macOS will show a warning
2. Go to **System Settings > Privacy & Security**
3. Click **Open Anyway** next to the MarkEdit InContext message

With Homebrew, `--no-quarantine` skips this entirely.

## Usage

### Basic editing

```sh
# Edit a file (blocks until save or discard)
eic file.md

# Create and edit a new file
eic newfile.md

# Open settings
eic --settings
```

### Piping

```sh
# Stdin to editor, save outputs to stdout
echo "hello" | eic

# Pipe stdin into an existing file, edit, save back to file
echo "extra content" | eic notes.md

# Edit a file, pipe saved content to next command
eic draft.md | wc -w

# Edit without modifying the original, output to stdout
eic --no-save file.md

# Full pipeline
curl -s api/data | eic | jq .
```

### Git integration

```sh
# Use as git editor (auto-detects commit/rebase/merge/tag titles)
GIT_EDITOR=eic git commit
GIT_EDITOR=eic git rebase -i HEAD~3

# Or set globally
git config --global core.editor eic
```

### Window title

```sh
# Set a custom window title
eic --title "Release Notes" changelog.md

# Files starting with "# Heading" auto-detect the title
echo "# My Document" > doc.md && eic doc.md
```

### Non-blocking mode

```sh
# Open and return immediately (fire-and-forget)
eic --detach file.md
```

### CLI reference

```
Usage: eic [options] [file]

Options:
  --settings      Open the settings panel
  --detach        Open and return immediately (don't block)
  --no-save       Edit a copy; on save, output to stdout (original unchanged)
  --title <text>  Set the window title
```

## Screenshots

![Light theme](/Screenshots/01.png)

![Dark theme](/Screenshots/02.png)

## Acknowledgments

Built on [CodeMirror 6](https://codemirror.net/). Forked from [MarkEdit](https://github.com/MarkEdit-app/MarkEdit) by [@wundram](https://github.com/wundram).
