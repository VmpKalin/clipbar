# ClipBar

Maccy-style clipboard history for iPhone, iPad and Mac, built with SwiftUI and Liquid Glass (iOS 26 / macOS 26).

- Everything you copy is kept: text, links, file paths, images.
- Sections in the side menu: All · Pinned · Saved · Frequent · Images · Links · Paths.
- Tap an item to put it back on the clipboard. Swipe right to pin, swipe left to delete, long-press for more.
- macOS: watches the clipboard in the background; path items offer **Open in Finder** / **Open in Terminal**; ⌘1…⌘9 copy the first nine items.
- iOS: reads the clipboard every time the app becomes active. Add the **ClipBar** button to Control Center or the Recent Clips widget to open it in one tap. Set *Settings → ClipBar → Paste from Other Apps → Allow* to avoid the system prompt.

## Build

Requires Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
```

Then open `ClipBar.xcodeproj`, or from the terminal:

```bash
xcodebuild -scheme ClipBar -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

```bash
xcodebuild -scheme ClipBar -destination 'platform=macOS' build
```

To run on a real iPhone, set your team in `project.yml` (`DEVELOPMENT_TEAM`) and regenerate.

## Tests

Unit tests (core logic, macOS host):

```bash
xcodebuild test -scheme ClipBarTests -destination 'platform=macOS'
```

UI tests (drive the app in the simulator, answer the paste prompt, check sections):

```bash
xcodebuild test -scheme ClipBarUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Layout

```
Sources/Core    model (SwiftData), store, sections, classifier, path resolver, image files
Sources/App     app entry, pasteboard reader/writer, capture coordinator, SwiftUI views
Sources/Widget  Recent Clips widget + Control Center button (iOS)
Tests           unit tests        UITests   XCUITest
docs/superpowers/specs, plans     design spec and implementation plan
```
