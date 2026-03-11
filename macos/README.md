# Notepad++ macOS (Apple Silicon) Preview

This repository now includes a native macOS editor baseline built on:

- `Scintilla` Cocoa view (`scintilla/cocoa`)
- `Lexilla` lexer library (`lexilla`)
- Cocoa app shell (`scintilla/cocoa/ScintillaTest`)

The goal is feature progression toward Notepad++ behavior while staying native on macOS/Apple Silicon.

## Implemented in this baseline

- Multiple tabs
- New/Open/Save/Save As/Revert/Close document actions
- Unsaved changes prompts on close/quit
- Find, Find Next, Find Previous
- Replace (replace all occurrences)
- Find in Files (directory recursive search results tab)
- Go to Line
- Search dialog with regex/match-case/whole-word/mark and scope selection (current doc, open docs, project files)
- Line numbers margin
- Code folding margin and markers
- Syntax highlighting by file extension (via Lexilla)
- Word wrap, whitespace visibility, EOL visibility toggles
- EOL conversion (CRLF/LF/CR)
- Encoding conversion targets (UTF-8 / UTF-16 LE / UTF-16 BE)
- Session persistence and restore across launches
- Sidebar with Project panel and Function List panel
- Preferences window (session/toolbar/status/sidebar/default editor options)
- Main toolbar actions (file, search, sidebar, macro controls)
- Macro recording and playback (Scintilla macro notifications + named macro library persisted to `~/.nppmac/shortcuts.xml`)
- Plugin scaffold (dynamic `.dylib` loading + API version boundary + command menu model)
- Caret line/column in window title

Session data is currently persisted in macOS user defaults (`NPPMacSessionV2` key).
Plugin scaffold API: `macos/include/NppMacPluginAPI.h`.

## Source files changed

- `scintilla/cocoa/ScintillaTest/AppController.h`
- `scintilla/cocoa/ScintillaTest/AppController.mm`

## Build and run on Apple Silicon

1. Install full Xcode (not just Command Line Tools).
2. Open:
   - `scintilla/cocoa/ScintillaTest/ScintillaTest.xcodeproj`
3. Select an Apple Silicon target (`My Mac (Apple Silicon)`), then build and run.

Or use CLI after full Xcode is installed:

```bash
cd scintilla/cocoa/ScintillaTest
xcodebuild -project ScintillaTest.xcodeproj -scheme ScintillaTest -configuration Debug -arch arm64
```

Or run the helper script from repo root:

```bash
./macos/build.sh
```

Build script options:

- override scheme: `SCHEME=ScintillaTest ./macos/build.sh`
- release build (production): `CONFIGURATION=Release ./macos/build.sh`
- dedicated production script: `./macos/build-production.sh`
- signed production build: `SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./macos/build-production.sh`

It produces:

- Debug app: `macos/build/Notepad++-preview.app`
- Debug zip: `macos/build/Notepad++-mac-preview.zip`
- Release app: `macos/build/Notepad++.app`
- Release zip: `macos/build/Notepad++-mac-production.zip`

## Notes

- This is a functional native baseline, not a full parity replacement yet.
- Full Notepad++ parity (plugins ecosystem, all dialogs, macro recorder/playback behavior, session restore model, etc.) needs staged implementation.
- See `macos/PARITY.md` for current status.
