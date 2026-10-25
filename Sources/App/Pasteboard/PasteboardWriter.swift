import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
enum PasteboardWriter {
    /// Puts the item back on the system pasteboard.
    static func write(_ item: ClipItem, images: ImageFileStore) {
        #if os(iOS)
        let pb = UIPasteboard.general
        switch item.kind {
        case .image:
            if let name = item.imageFileName, let data = try? Data(contentsOf: images.url(for: name)),
               let image = UIImage(data: data) {
                pb.image = image
            }
        case .link:
            if let t = item.text, let url = URL(string: t) {
                pb.setValue(url, forPasteboardType: "public.url")
                pb.string = t
            }
        case .text, .filePath:
            pb.string = item.text ?? ""
        }
        #else
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .image:
            if let name = item.imageFileName, let data = try? Data(contentsOf: images.url(for: name)) {
                pb.setData(data, forType: .png)
                if let image = NSImage(data: data) { pb.writeObjects([image]) }
            }
        case .filePath:
            let text = item.text ?? ""
            pb.setString(text, forType: .string)
            if let url = PathResolver.resolve(text) { pb.writeObjects([url as NSURL]) ; pb.setString(text, forType: .string) }
        case .link, .text:
            pb.setString(item.text ?? "", forType: .string)
        }
        #endif
    }
}
