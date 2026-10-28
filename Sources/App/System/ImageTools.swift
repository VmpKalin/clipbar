import AppKit
import Vision

enum ImageTools {
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
}
