import AppKit
import Foundation

@MainActor
enum PasteboardWriter {
    /// Puts a history item back on the system pasteboard.
    static func write(_ item: ClipItem, images: ImageFileStore, pasteboard: NSPasteboard = .general) {
        switch item.kind {
        case .image:
            pasteboard.clearContents()
            if let name = item.imageFileName, let data = try? Data(contentsOf: images.url(for: name)) {
                pasteboard.setData(data, forType: .png)
                if let tiff = NSImage(data: data)?.tiffRepresentation {
                    pasteboard.setData(tiff, forType: .tiff)
                }
            }
        case .filePath:
            let text = item.text ?? ""
            let urls = PathResolver.resolveAll(text)
            pasteboard.clearContents()
            if !urls.isEmpty { pasteboard.writeObjects(urls as [NSURL]) }
            pasteboard.setString(text, forType: .string)
        case .link:
            pasteboard.clearContents()
            let text = item.text ?? ""
            pasteboard.setString(text, forType: .string)
            pasteboard.setString(text, forType: .URL)
        case .text:
            write(text: item.text ?? "", pasteboard: pasteboard)
        }
    }

    static func write(text: String, pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
