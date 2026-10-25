import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension Image {
    /// Builds an Image from encoded data on either platform; nil when the data is not an image.
    static func fromData(_ data: Data?) -> Image? {
        guard let data else { return nil }
        #if os(iOS)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #else
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #endif
    }
}
