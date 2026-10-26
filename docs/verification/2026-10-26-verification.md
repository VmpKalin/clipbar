# Verification — 2026-10-26

## Unit tests (macOS host, in-memory SwiftData)

`xcodebuild test -scheme ClipBarTests -destination 'platform=macOS'`

	 Executed 27 tests, with 0 failures (0 unexpected) in 0.189 (0.204) seconds

Covers: classifier (text / link / path / image, hashing), store (dedup + bump, markUsed,
enforceLimit keeps pinned/saved, clearHistory, image file write/delete, onChange),
sections (filter + sort + search), PathResolver (~, file://, escaped spaces, missing path,
terminal directory, display name).

## iOS UI tests (iPhone 17 Pro simulator, iOS 26.2)

`xcodebuild test -scheme ClipBarUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

2 tests, 0 failures. The tests seed UIPasteboard, launch the app, answer the system
"Allow Paste" prompt, and check:

- link captured on launch, shown with host as title (ios-all-after-link.png)
- text and path captured via the toolbar capture button (ios-all-three-items.png)
- tap shows the "Copied" toast
- swipe-right pins; Pinned section shows the item (ios-pinned.png)
- side menu with counts (ios-side-menu.png); Links / Paths sections filter correctly
- Settings sheet (ios-settings.png)
- search filters the list (ios-search-xcode.png)
- image on the pasteboard appears in the Images grid (ios-images-grid.png)

## macOS

Built with `xcodebuild -scheme ClipBar -destination 'platform=macOS'` (ad-hoc signed).
Launched the app, copied a URL, a path, a text with `pbcopy` at 1.5 s intervals, then
read the store with sqlite3: all three were captured with the right kind, plus an image that
was on the clipboard before. Background polling works like Maccy.

## Not verified by automation

- Open in Finder / Open in Terminal (macOS): implemented with NSWorkspace and
  `open -a Terminal <dir>`; the directory selection logic is unit-tested, the GUI action
  was not clicked.
- Control Center button and the home-screen widget: compiled and embedded, not added to
  Control Center in the simulator.
- Running on a physical iPhone needs a development team in `project.yml`.
