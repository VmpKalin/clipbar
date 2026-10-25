import Foundation
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
protocol PasteboardReader: AnyObject {
    /// Returns the pasteboard content when its change count differs from the last seen one.
    func readIfChanged() -> ClipPayload?
    /// Records the current change count so the next `readIfChanged` returns nil (used after
    /// the app itself writes to the pasteboard).
    func markCurrentAsSeen()
}

private let lastSeenKey = "pasteboard.lastSeenChangeCount"

#if os(iOS)
@MainActor
final class SystemPasteboardReader: PasteboardReader {
    private var lastSeen: Int = UserDefaults.standard.object(forKey: lastSeenKey) as? Int ?? -1

    func readIfChanged() -> ClipPayload? {
        let pb = UIPasteboard.general
        guard pb.changeCount != lastSeen else { return nil }
        remember(pb.changeCount)
        if pb.hasImages {
            if let data = pb.data(forPasteboardType: UTType.png.identifier) { return ClipPayload(imageData: data) }
            if let data = pb.image?.pngData() { return ClipPayload(imageData: data) }
        }
        if pb.hasStrings || pb.hasURLs {
            if let s = pb.string, !s.isEmpty { return ClipPayload(text: s) }
            if let u = pb.url { return ClipPayload(text: u.absoluteString) }
        }
        return nil
    }

    func markCurrentAsSeen() { remember(UIPasteboard.general.changeCount) }

    private func remember(_ count: Int) {
        lastSeen = count
        UserDefaults.standard.set(count, forKey: lastSeenKey)
    }
}
#else
@MainActor
final class SystemPasteboardReader: PasteboardReader {
    private var lastSeen: Int = UserDefaults.standard.object(forKey: lastSeenKey) as? Int ?? -1
    private static let transientTypes: [NSPasteboard.PasteboardType] = [
        .init("org.nspasteboard.TransientType"),
        .init("org.nspasteboard.ConcealedType"),
        .init("com.agilebits.onepassword"),
    ]

    func readIfChanged() -> ClipPayload? {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastSeen else { return nil }
        remember(pb.changeCount)
        let types = pb.types ?? []
        if types.contains(where: { Self.transientTypes.contains($0) }) { return nil }

        if let data = pb.data(forType: .png) { return ClipPayload(imageData: data) }
        if let tiff = pb.data(forType: .tiff),
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            return ClipPayload(imageData: png)
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first {
            return ClipPayload(text: first.path(percentEncoded: false))
        }
        if let s = pb.string(forType: .string), !s.isEmpty { return ClipPayload(text: s) }
        return nil
    }

    func markCurrentAsSeen() { remember(NSPasteboard.general.changeCount) }

    private func remember(_ count: Int) {
        lastSeen = count
        UserDefaults.standard.set(count, forKey: lastSeenKey)
    }
}
#endif
