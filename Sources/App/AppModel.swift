import AppKit
import Foundation
import Observation
import ServiceManagement
import SwiftData

/// Owns storage, capture and every user-facing action. One instance per app.
@MainActor
@Observable
final class AppModel {
    enum Delivery: String, CaseIterable, Identifiable {
        case copy, paste
        var id: String { rawValue }
        var title: String { self == .copy ? "Copy to clipboard" : "Paste into the active app" }
    }

    struct Toast: Equatable {
        let id = UUID()
        let message: String
        let systemImage: String
    }

    let container: ModelContainer
    let store: ClipStore
    let library: SnippetStore
    let capture: CaptureCoordinator
    let contacts = ContactsProvider()
    /// Set when the persistent store could not be opened and an in-memory one is used instead.
    let storageWarning: String?

    @ObservationIgnored weak var panel: PanelController?
    private(set) var toast: Toast?

    var primaryDelivery: Delivery {
        get { access(keyPath: \.primaryDelivery); return Delivery(rawValue: UserDefaults.standard.string(forKey: "primaryAction") ?? "") ?? .copy }
        set { withMutation(keyPath: \.primaryDelivery) { UserDefaults.standard.set(newValue.rawValue, forKey: "primaryAction") } }
    }

    var secondaryDelivery: Delivery { primaryDelivery == .copy ? .paste : .copy }

    init(inMemory: Bool = false, startCapture: Bool = true) {
        var warning: String?
        let container: ModelContainer
        do {
            container = try Storage.makeModelContainer(inMemory: inMemory)
        } catch {
            warning = "History won't be saved: \(error.localizedDescription)"
            container = try! Storage.makeModelContainer(inMemory: true)
        }
        self.container = container
        self.storageWarning = warning
        let imagesDir = inMemory
            ? FileManager.default.temporaryDirectory.appending(path: "ClipBar-\(UUID().uuidString)")
            : Storage.imagesURL
        let store = ClipStore(context: container.mainContext, images: ImageFileStore(directory: imagesDir))
        self.store = store
        self.library = SnippetStore(context: container.mainContext)
        self.capture = CaptureCoordinator(reader: SystemPasteboardReader(), store: store)
        library.seedDefaultsIfNeeded()
        if startCapture {
            capture.captureNow()
            capture.startPolling()
        }
    }

    // MARK: Delivering content

    func deliver(_ item: ClipItem, as delivery: Delivery? = nil, transform: TextTransform? = nil) {
        if let transform, let text = item.text, let changed = transform.apply(text) {
            PasteboardWriter.write(text: changed)
        } else {
            PasteboardWriter.write(item, images: store.images)
        }
        store.markUsed(item)
        finish(delivery ?? primaryDelivery, title: item.title)
    }

    func deliver(_ snippet: Snippet, as delivery: Delivery? = nil, transform: TextTransform? = nil) {
        var text = expanded(snippet)
        if let transform, let changed = transform.apply(text) { text = changed }
        PasteboardWriter.write(text: text)
        library.markUsed(snippet)
        finish(delivery ?? primaryDelivery, title: snippet.title)
    }

    func deliver(text: String, title: String, as delivery: Delivery? = nil, transform: TextTransform? = nil) {
        var text = text
        if let transform, let changed = transform.apply(text) { text = changed }
        PasteboardWriter.write(text: text)
        finish(delivery ?? primaryDelivery, title: title)
    }

    /// The value a snippet produces right now (dynamic tokens expanded).
    func expanded(_ snippet: Snippet) -> String {
        guard snippet.isDynamic else { return snippet.value }
        let context = TemplateExpander.Context(clipboard: capture.currentClipboardString())
        return TemplateExpander().expand(snippet.value, context: context)
    }

    private func finish(_ delivery: Delivery, title: String) {
        capture.ignoreCurrentPasteboard()
        let target = panel?.previousApp
        panel?.close()
        guard delivery == .paste else { return }
        if !Paster.paste(into: target) {
            Paster.requestTrust()
            notify("Copied. Allow Accessibility to paste automatically.", systemImage: "hand.raised")
        }
    }

    // MARK: History actions

    func togglePin(_ item: ClipItem) { store.togglePin(item) }
    func delete(_ item: ClipItem) { store.delete(item) }
    func clearHistory() { store.clearHistory() }
    func updateText(_ item: ClipItem, to text: String) { store.updateText(item, to: text) }

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFileName.map { store.images.url(for: $0) }
    }

    func copyTextFromImage(_ item: ClipItem) {
        guard let url = imageURL(for: item) else { return }
        notify("Recognizing text…", systemImage: "text.viewfinder")
        Task {
            do {
                let text = try await ImageTools.recognizeText(at: url)
                guard !text.isEmpty else {
                    notify("No text found in the image", systemImage: "text.viewfinder")
                    return
                }
                let clip = store.ingest(ClipPayload(text: text, sourceAppBundleID: item.sourceAppBundleID,
                                                    sourceAppName: item.sourceAppName))
                PasteboardWriter.write(text: text)
                capture.ignoreCurrentPasteboard()
                if let clip { panel?.state.select(.clip(clip.id)) }
                notify("Text copied from image", systemImage: "checkmark.circle")
            } catch {
                notify("Text recognition failed", systemImage: "exclamationmark.triangle")
            }
        }
    }

    /// Adds a generated image to the history, copies it and selects it.
    private func publishImage(_ data: Data, from item: ClipItem?, message: String) {
        guard let clip = store.ingest(ClipPayload(imageData: data, sourceAppBundleID: item?.sourceAppBundleID,
                                                  sourceAppName: item?.sourceAppName)) else {
            notify("Could not store the image", systemImage: "exclamationmark.triangle")
            return
        }
        PasteboardWriter.write(clip, images: store.images)
        capture.ignoreCurrentPasteboard()
        panel?.state.select(.clip(clip.id), scroll: true)
        notify(message, systemImage: "checkmark.circle")
    }

    func removeBackground(_ item: ClipItem) {
        guard let url = imageURL(for: item) else { return }
        notify("Removing background…", systemImage: "person.and.background.dotted")
        Task {
            do {
                publishImage(try await ImageTools.removeBackground(at: url), from: item, message: "Background removed and copied")
            } catch {
                notify("No subject found to cut out", systemImage: "exclamationmark.triangle")
            }
        }
    }

    func scanCodes(_ item: ClipItem) {
        guard let url = imageURL(for: item) else { return }
        Task {
            let codes = (try? await ImageTools.detectCodes(at: url)) ?? []
            guard !codes.isEmpty else {
                notify("No QR code or barcode found", systemImage: "qrcode.viewfinder")
                return
            }
            let text = codes.joined(separator: "\n")
            let clip = store.ingest(ClipPayload(text: text, sourceAppBundleID: item.sourceAppBundleID,
                                                sourceAppName: item.sourceAppName))
            PasteboardWriter.write(text: text)
            capture.ignoreCurrentPasteboard()
            if let clip { panel?.state.select(.clip(clip.id), scroll: true) }
            notify(codes.count == 1 ? "Code content copied" : "\(codes.count) codes copied", systemImage: "qrcode.viewfinder")
        }
    }

    func makeQRCode(text: String, from item: ClipItem?) {
        do {
            publishImage(try ImageTools.qrCode(for: text), from: item, message: "QR code copied")
        } catch {
            notify("Text is too long for a QR code", systemImage: "exclamationmark.triangle")
        }
    }

    func copyAsDataURL(_ item: ClipItem) {
        guard let url = imageURL(for: item), let dataURL = try? ImageTools.dataURL(forPNGAt: url) else { return }
        PasteboardWriter.write(text: dataURL)
        capture.ignoreCurrentPasteboard()
        notify("Copied as data URL (\(ByteCountFormatter.string(fromByteCount: Int64(dataURL.utf8.count), countStyle: .file)))",
               systemImage: "chevron.left.forwardslash.chevron.right")
    }

    func saveImageToDownloads(_ item: ClipItem) {
        guard let url = imageURL(for: item) else { return }
        do {
            let saved = try ImageTools.saveToDownloads(url)
            NSWorkspace.shared.activateFileViewerSelecting([saved])
            panel?.close()
        } catch {
            notify("Could not save the image", systemImage: "exclamationmark.triangle")
        }
    }

    func open(_ item: ClipItem) {
        switch item.kind {
        case .link:
            if let t = item.text, let url = URL(string: t) { NSWorkspace.shared.open(url) }
        case .filePath:
            if let url = PathActions.resolvedURLs(for: item).first { PathActions.openWithDefaultApp(url) }
        case .image:
            if let url = imageURL(for: item) { NSWorkspace.shared.open(url) }
        case .text:
            if let t = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: t), url.scheme != nil {
                NSWorkspace.shared.open(url)
            }
        }
        panel?.close()
    }

    func revealInFinder(_ item: ClipItem) {
        PathActions.openInFinder(PathActions.resolvedURLs(for: item))
        panel?.close()
    }

    func openInTerminal(_ item: ClipItem) {
        if let url = PathActions.resolvedURLs(for: item).first { PathActions.openInTerminal(url) }
        panel?.close()
    }

    // MARK: Library

    @discardableResult
    func addToLibrary(title: String, value: String, keyword: String, group: SnippetGroup) -> Snippet {
        let s = library.addSnippet(title: title, value: value, keyword: keyword, to: group)
        notify("Saved to \(group.name)", systemImage: "books.vertical")
        return s
    }

    /// Adds the user's own Contacts card to the Personal group, one snippet per field.
    func importMyCard() async {
        if contacts.access != .granted { await contacts.requestAccess() }
        guard let me = await contacts.meCard() else {
            notify("No “My Card” found in Contacts", systemImage: "person.crop.circle.badge.questionmark")
            return
        }
        let group = library.group(named: "Personal") ?? library.addGroup(name: "Personal", symbol: "person.crop.circle")
        var added = 0
        let existing = Set(group.snippets.map(\.value))
        if !me.name.isEmpty, !existing.contains(me.name) {
            library.addSnippet(title: "Name", value: me.name, to: group); added += 1
        }
        for field in me.fields where !existing.contains(field.value) {
            let title = field.label.isEmpty ? field.kind.rawValue.capitalized : "\(field.kind.rawValue.capitalized) (\(field.label))"
            library.addSnippet(title: title, value: field.value, to: group)
            added += 1
        }
        notify(added > 0 ? "Imported \(added) fields from your card" : "Your card is already in Personal",
               systemImage: "person.crop.circle.badge.checkmark")
    }

    // MARK: Feedback

    func notify(_ message: String, systemImage: String) {
        let toast = Toast(message: message, systemImage: systemImage)
        self.toast = toast
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if self.toast == toast { self.toast = nil }
        }
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        get { access(keyPath: \.launchAtLogin); return SMAppService.mainApp.status == .enabled }
        set {
            withMutation(keyPath: \.launchAtLogin) {
                do {
                    if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                } catch {
                    notify("Could not change login item: \(error.localizedDescription)", systemImage: "exclamationmark.triangle")
                }
            }
        }
    }
}
