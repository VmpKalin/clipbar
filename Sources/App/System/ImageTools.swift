import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

enum ImageTools {
    enum Failure: LocalizedError {
        case noResult
        var errorDescription: String? { "Nothing found in the image" }
    }

    /// Recognizes text in an image file (accurate mode, automatic language detection).
    static func recognizeText(at url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let handler = VNImageRequestHandler(url: url)
            try handler.perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }

    /// Payloads of QR codes and barcodes in the image.
    static func detectCodes(at url: URL) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(url: url)
            try handler.perform([request])
            var seen = Set<String>()
            return (request.results ?? []).compactMap(\.payloadStringValue).filter { seen.insert($0).inserted }
        }.value
    }

    /// Lifts the main subject(s) off the background. Returns a PNG with transparency.
    static func removeBackground(at url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(url: url)
            try handler.perform([request])
            guard let result = request.results?.first, !result.allInstances.isEmpty else { throw Failure.noResult }
            let buffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler,
                                                        croppedToInstancesExtent: true)
            let image = CIImage(cvPixelBuffer: buffer)
            let context = CIContext()
            guard let cg = context.createCGImage(image, from: image.extent) else { throw Failure.noResult }
            return try png(from: cg)
        }.value
    }

    /// A crisp QR code for the text, as PNG.
    static func qrCode(for text: String, scale: CGFloat = 12) throws -> Data {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else {
            throw Failure.noResult
        }
        // Add a quiet zone so scanners read it reliably.
        let margin = scale * 2
        let background = CIImage(color: .white).cropped(to: output.extent.insetBy(dx: -margin, dy: -margin))
        let composed = output.composited(over: background)
        let context = CIContext()
        guard let cg = context.createCGImage(composed, from: composed.extent) else { throw Failure.noResult }
        return try png(from: cg)
    }

    static func dataURL(forPNGAt url: URL) throws -> String {
        "data:image/png;base64," + (try Data(contentsOf: url)).base64EncodedString()
    }

    /// Copies an image file into ~/Downloads with a readable, unique name. Returns the new URL.
    static func saveToDownloads(_ source: URL, date: Date = .now) throws -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        var target = downloads.appending(path: "ClipBar Image \(f.string(from: date)).png")
        var n = 2
        while FileManager.default.fileExists(atPath: target.path) {
            target = downloads.appending(path: "ClipBar Image \(f.string(from: date)) \(n).png")
            n += 1
        }
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }

    private static func png(from image: CGImage) throws -> Data {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { throw Failure.noResult }
        return data
    }
}
