# ClipBar v2 — Mac-only menu bar tool

Date: 2026-10-28

## Decision

The user will use ClipBar only on a MacBook. iOS targets (app, widget, Control Center,
UI tests) are removed; the codebase becomes macOS 26 only. The app is an `LSUIElement`
menu bar utility, like Maccy, opened from the status item or a global hotkey.

## Goals

Everything related to copying, pasting and re-using information lives in one
beautiful Liquid Glass panel:

1. **Clipboard history** — text, links, paths (single and multiple files), images,
   with the source app recorded and shown.
2. **Library** — information the user re-uses: groups (Personal, Work, Templates,
   Dynamic, plus user-created) holding snippets with a title, value and optional keyword.
   Dynamic snippets expand tokens like `{date}`, `{time}`, `{uuid}`, `{clipboard}`.
   "My card" can be imported from the user's own Contacts card.
3. **Contacts** — search system Contacts and copy a phone/email/address in one click.
4. **Quick search** — one search field searches history, Library and Contacts at once.
5. **Actions** — copy, paste directly into the previous app, paste as transformed
   text (UPPER/lower/Title, trim, single line, JSON pretty/minify, URL/Base64
   encode/decode), pin, add to Library, edit, delete, open link, open path in
   Finder/Terminal, copy text from an image (OCR), save image to Downloads.

## Architecture

- `NSStatusItem` + custom `NSPanel` (non-activating style, becomes key) hosting SwiftUI,
  positioned under the status item, closes on resign key / esc.
- Global hotkey via Carbon `RegisterEventHotKey` (default ⇧⌘V, choices in Settings).
- Paste: remember the frontmost app before showing the panel; after a choice, hide the panel,
  re-activate that app and post ⌘V through `CGEvent` (needs Accessibility permission;
  falls back to copy-only with a hint).
- Signed with the user's Apple Development identity so Accessibility / Contacts
  permissions survive rebuilds.
- SwiftData models: `ClipItem` (+ `sourceAppBundleID`, `sourceAppName`),
  `SnippetGroup`, `Snippet`. Additive changes only (lightweight migration).
- Core (unit-tested): classifier + content tags (email, phone, color, JSON, code,
  number), `TextTransform`, `TemplateExpander`, `SearchMatcher` (fuzzy), `SnippetStore`,
  `ClipStore`, `PathResolver`.
- Panel UI: search field, tabs (Clipboard / Library / Contacts), filter chips, list with
  keyboard navigation, preview pane with actions, footer. Inline editor overlay for snippets
  and clip edits (no sheets: a sheet would make the panel resign key).
- Settings window: General (hotkey, paste behaviour, launch at login, history limit),
  Capture (pause, ignored apps), Library (export/import JSON), About.
- Verification: a hidden `--snapshot <dir>` launch mode renders the panel with sample
  data offscreen to PNGs, because screen capture is not permitted for the agent.

## Keyboard

↑/↓ move · ↩ primary action (copy or paste, per setting) · ⌥↩ the other one ·
⌘1…⌘9 pick · ⌘P pin · ⌘L add to Library · ⌘E edit · ⌘⌫ delete · ⌘O open ·
⇥ next tab · esc clears search, then closes.
