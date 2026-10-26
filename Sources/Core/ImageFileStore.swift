import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Stores full-size images as PNG files and produces small JPEG thumbnails.
public struct ImageFileStore: Sendable {
    public struct Stored: Sendable {
        public let fileName: String
        public let thumbnail: Data?
        public let width: Int
        public let height: Int
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func url(for fileName: String) -> URL { directory.appending(path: fileName) }

    public func store(_ data: Data, id: UUID) throws -> Stored {
        let fileName = "\(id.uuidString).png"
        let png = Self.pngData(from: data) ?? data
        try png.write(to: url(for: fileName), options: .atomic)
        let size = Self.pixelSize(of: png)
        return Stored(
            fileName: fileName,
            thumbnail: Self.thumbnail(from: png, maxPixel: 640),
            width: size.width,
            height: size.height
        )
    }

    public func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    // MARK: - ImageIO helpers

    static func pixelSize(of data: Data) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return (0, 0) }
        return (w, h)
    }

    static func pngData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return nil }
        if type == UTType.png.identifier as CFString { return data }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return encode(image, as: .png, quality: 1)
    }

    static func thumbnail(from data: Data, maxPixel: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return encode(thumb, as: .jpeg, quality: 0.85)
    }

    static func encode(_ image: CGImage, as type: UTType, quality: Double) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
