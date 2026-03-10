# Notepad++ macOS Parity Matrix

Legend:

- `DONE`: implemented in current macOS baseline
- `PARTIAL`: some behavior exists, not equivalent yet
- `TODO`: not implemented yet

## Core editing

- Multi-tab editing: `DONE`
- Open/save workflows: `DONE`
- Dirty tracking and save prompts: `DONE`
- Undo/redo and clipboard actions: `PARTIAL` (provided by Scintilla/action chain, needs full command parity validation)
- Encoding detection/management parity: `PARTIAL` (UTF-8/UTF-16 LE/UTF-16 BE conversions added, full Notepad++ matrix pending)
- EOL conversion and controls: `DONE` (CRLF/LF/CR conversion and active mode state)

## Search

- Find / Find next / Find previous: `DONE`
- Replace: `DONE` (search dialog + scoped replace flows for open docs)
- Find in files: `DONE` (panel scope for project files + standalone folder scan)
- Full Search dialog modes (regex, mark, scoped options): `PARTIAL` (implemented core modes; advanced Notepad++ sub-modes still pending)
- Go to line: `DONE`

## Language support

- Lexer-based highlighting: `DONE`
- Complete language menu and per-language settings: `TODO`
- Theme/parsing parity with Notepad++ defaults: `PARTIAL`

## View/UI

- Line numbers + fold margin: `DONE`
- Word wrap/whitespace/EOL visibility toggles: `DONE`
- Project panel + function list sidebar: `PARTIAL`
- Status bar + toolbar: `PARTIAL`
- Preferences dialogs and persistent UI settings: `PARTIAL`

## Advanced Notepad++ features

- Session management and restore: `PARTIAL` (tab/session restore with unsaved untitled content + project roots)
- Macro recording/playback compatibility: `PARTIAL` (Scintilla macro step capture/replay + named macro save/load via `~/.nppmac/shortcuts.xml`)
- Plugin manager and plugin API compatibility layer: `PARTIAL` (dynamic loading scaffold + API version + command entrypoints)
- External tools/run menu, shortcuts mapper parity: `TODO`
- Compare, project panel, function list parity: `TODO`

## Packaging

- Apple Silicon build target path: `DONE`
- Signing, notarization, installer packaging: `TODO`
