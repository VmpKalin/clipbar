# ClipBar Clipboard Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Maccy-style clipboard history app for iOS 26 + macOS 26 with Liquid Glass UI, sections (All/Pinned/Saved/Frequent/Images/Links/Paths), widget + Control Center on iOS, and Open in Finder/Terminal for paths on macOS.

**Architecture:** One XcodeGen project. Platform-neutral core (`Sources/Core`) holds the SwiftData model, store, classifier and path helpers and is compiled into the app and a macOS unit-test target. Platform code lives behind `#if os(...)`. UI is SwiftUI with `.glassEffect`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, WidgetKit, AppIntents, XcodeGen, XCTest. Deployment: iOS 26.0, macOS 26.0.

Spec: `docs/superpowers/specs/2026-10-25-clipboard-manager-design.md`

---

## File structure

```
project.yml                                  XcodeGen spec (targets: ClipBar, ClipBarWidget, ClipBarTests)
Sources/Core/ClipItem.swift                  SwiftData @Model + ClipKind
Sources/Core/ClipPayload.swift               Captured payload + ClipClassifier + hashing
Sources/Core/ClipStore.swift                 ingest / markUsed / pin / save / delete / clear / enforceLimit
Sources/Core/ClipSection.swift               Section enum + predicate/sort helpers
Sources/Core/ImageFileStore.swift            PNG + thumbnail files in App Group
Sources/Core/PathResolver.swift              expand ~, strip file://, terminal dir
Sources/Core/AppGroup.swift                  container URL + ModelContainer factory
Sources/App/ClipBarApp.swift                 @main, scenePhase capture hook
Sources/App/Pasteboard/PasteboardReader.swift   protocol + UIKit/AppKit impls
Sources/App/Pasteboard/PasteboardWriter.swift   protocol + impls
Sources/App/Pasteboard/CaptureCoordinator.swift reader -> store
Sources/App/PathActions.swift                Finder/Terminal (macOS), Files (iOS)
Sources/App/Views/RootView.swift             split view (mac/iPad) or drawer (iPhone)
Sources/App/Views/SideMenuView.swift
Sources/App/Views/HistoryListView.swift
Sources/App/Views/ClipRowView.swift
Sources/App/Views/ImageGridView.swift
Sources/App/Views/SettingsView.swift
Sources/App/Views/OnboardingView.swift
Sources/App/Resources/Info.plist, ClipBar.entitlements, Assets.xcassets
Sources/Widget/ClipBarWidgetBundle.swift     RecentClipsWidget + OpenClipBarControl
Sources/Widget/Info.plist, ClipBarWidget.entitlements
Tests/ClipClassifierTests.swift
Tests/ClipStoreTests.swift
Tests/PathResolverTests.swift
```

Bundle ids: `com.aholoiad.clipbar`, widget `com.aholoiad.clipbar.widget`, App Group `group.com.aholoiad.clipbar`. Code signing: automatic, team left empty (simulator + local mac run with ad-hoc signing).

---

### Task 1: Project scaffold

- [ ] Write `project.yml` with three targets, deployment targets iOS 26.0 / macOS 26.0, SWIFT_VERSION 6, App Group entitlements on app + widget, `supportedDestinations: [iOS, macOS]` for the app, widget iOS only, tests macOS only (host-less, link Core sources directly).
- [ ] Create minimal `ClipBarApp.swift` showing `Text("ClipBar")`, Info.plists, Assets with AppIcon placeholder.
- [ ] Run `xcodegen generate` then `xcodebuild -scheme ClipBar -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` and `-destination 'platform=macOS' build`. Expected: BUILD SUCCEEDED both.
- [ ] Commit "chore: scaffold ClipBar project".

### Task 2: Model + classifier (TDD)

- [ ] Test `ClipClassifierTests`: `"hello"` → `.text`; `"https://apple.com/x"` → `.link`; `"/Users/a/b.txt"` → `.filePath`; `"~/Desktop"` → `.filePath`; `"file:///tmp/x"` → `.filePath`; `"/a\n/b"` (two lines) → `.text`; image data → `.image`; same text gives same `contentHash`, different text different hash.
- [ ] Implement `ClipKind`, `ClipItem` (@Model), `ClipPayload.init(text:)`, `ClipPayload.init(imageData:)`, `ClipClassifier.kind(forText:)`, SHA-256 via CryptoKit.
- [ ] Run tests, pass, commit "feat: clip model and classifier".

### Task 3: ClipStore (TDD, in-memory ModelContainer)

- [ ] Tests: ingest creates item; ingest of same hash does not duplicate and bumps `createdAt`; `markUsed` increments `useCount` and sets `lastUsedAt`; `enforceLimit(2)` on 4 unpinned keeps newest 2; `enforceLimit` never removes pinned/saved; `clearHistory` keeps pinned+saved; `delete` removes image file via injected `ImageFileStore` pointing to a temp dir.
- [ ] Implement `ClipStore` as `@MainActor final class` over `ModelContext`, `ImageFileStore` with temp-dir init for tests.
- [ ] Implement `ClipSection` with `fetchDescriptor(search:)` returning sorted/filtered items for each section (Pinned first in All; Frequent sorted by useCount desc).
- [ ] Tests pass, commit "feat: clip store with dedup, limit, sections".

### Task 4: PathResolver (TDD)

- [ ] Tests: `resolve("~/")` → home URL; `resolve("file:///tmp")` → `/tmp`; `resolve("/definitely/missing")` → nil; `terminalDirectory(for: fileURL)` → parent; for dir → itself.
- [ ] Implement, pass, commit "feat: path resolver".

### Task 5: Pasteboard capture + write (platform code)

- [ ] `PasteboardReader` protocol: `func readIfChanged() -> ClipPayload?`. UIKit impl uses `UIPasteboard.general.changeCount`, prefers image (`.image` → PNG data) then string. AppKit impl mirrors with `NSPasteboard.general` (`.png`/`.tiff` → PNG via NSBitmapImageRep, then `.string`).
- [ ] `PasteboardWriter`: `write(item:)` sets string or image; after writing, records changeCount into reader via shared `PasteboardState` so capture skips own writes.
- [ ] `CaptureCoordinator` (@MainActor, @Observable): `captureNow()`; macOS `startPolling()` with a 0.5 s Timer.
- [ ] Wire in `ClipBarApp`: iOS `onChange(of: scenePhase)` → `.active` → captureNow; macOS startPolling on launch. Build both platforms, commit "feat: pasteboard capture".

### Task 6: UI

- [ ] `RootView`: `@State selection: ClipSection = .all`; macOS/iPad → `NavigationSplitView(sidebar: SideMenuView, detail: HistoryListView)`; iPhone → `ZStack` with `HistoryListView` + drawer overlay (`SideMenuView` in `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))`, offset animation, drag gesture from leading edge, dim background).
- [ ] `SideMenuView`: list of sections with SF Symbols and counts (`@Query` count per section), Settings button.
- [ ] `HistoryListView`: `.searchable`, `@Query` driven by section+search via `init(section:search:)`, swipe actions, context menu, tap → `writer.write` + haptic + `store.markUsed`. Images section uses `ImageGridView` (LazyVGrid 3 columns). Toolbar: menu button (iPhone), title = section name; `.toolbarBackground` glass default on iOS 26.
- [ ] `ClipRowView`: per-kind layout from spec; monospaced if text contains no spaces-run >3 words or starts with `$`, `./`, `-`.
- [ ] macOS: `.keyboardShortcut` ⌘1…⌘9 over hidden buttons copying visible items.
- [ ] `SettingsView`: `@AppStorage("historyLimit")` picker (100/500/1000/0=unlimited), Clear History with confirmation, iOS paste-permission hint with `Link` to `UIApplication.openSettingsURLString`, About.
- [ ] `OnboardingView`: shown once (`@AppStorage("didOnboard")`) explaining the flow (iOS only).
- [ ] Build both, run in simulator, commit "feat: history UI with side menu".

### Task 7: Path actions

- [ ] macOS `PathActions.openInFinder(url)` → `NSWorkspace.shared.activateFileViewerSelecting([url])` for files, `NSWorkspace.shared.open(url)` for dirs; `openInTerminal(url)` → `Process` running `/usr/bin/open -a Terminal <dir>`.
- [ ] iOS `PathActions.filesAppURL(for:)` → `shareddocuments://` + path; `UIApplication.shared.open`.
- [ ] Context menu entries shown only for `.filePath` items whose `PathResolver.resolve` is non-nil.
- [ ] Build, commit "feat: open paths in Finder/Terminal/Files".

### Task 8: Widget + Control Center (iOS)

- [ ] `RecentClipsWidget` TimelineProvider reads App Group ModelContainer, shows 3 newest items (text truncated, image thumbnail). `widgetURL(URL("clipbar://open"))`.
- [ ] `OpenClipBarIntent: AppIntent` with `openAppWhenRun = true`; `OpenClipBarControl: ControlWidget` button using it.
- [ ] App: `onOpenURL` no-op (capture runs on active anyway). URL scheme in Info.plist.
- [ ] Reload timelines after ingest (`WidgetCenter.shared.reloadAllTimelines()` on iOS).
- [ ] Build iOS, commit "feat: widget and control center".

### Task 9: Verification

- [ ] `xcodebuild test -scheme ClipBarTests -destination 'platform=macOS'` → all pass.
- [ ] iOS: boot iPhone 17 Pro, install, `xcrun simctl pbcopy` several values, relaunch app each time, screenshot list; pin/delete via UI; screenshot Images section with a pasted image (`simctl pbcopy` of PNG not supported → use a UI test hook? Instead use in-app debug: not in v1; images verified on macOS).
- [ ] macOS: launch app, copy text/URL/path/image in Terminal/Finder, verify history, verify Open in Finder / Terminal.
- [ ] Record results in `docs/superpowers/plans/2026-10-25-verification.md`, commit.
