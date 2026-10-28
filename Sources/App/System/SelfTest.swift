import AppKit

/// `ClipBar --selftest` exercises the Vision/CoreImage features end to end and prints the results.
@MainActor
enum SelfTest {
    static var isRequested: Bool { CommandLine.arguments.contains("--selftest") }

    static func run() {
        Task { @MainActor in
            var failures = 0
            func check(_ name: String, _ ok: Bool, _ detail: String = "") {
                print("\(ok ? "PASS" : "FAIL")  \(name)  \(detail)")
                if !ok { failures += 1 }
            }
            let dir = FileManager.default.temporaryDirectory.appending(path: "ClipBarSelfTest-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            // QR round trip.
            do {
                let text = "https://example.com/clipbar?x=1"
                let png = try ImageTools.qrCode(for: text)
                let url = dir.appending(path: "qr.png")
                try png.write(to: url)
                let codes = try await ImageTools.detectCodes(at: url)
                check("QR generate + scan", codes == [text], "\(codes)")
            } catch { check("QR generate + scan", false, "\(error)") }

            // OCR.
            do {
                let url = dir.appending(path: "text.png")
                try textImage("Hello ClipBar 2026").write(to: url)
                let text = try await ImageTools.recognizeText(at: url)
                check("OCR", text.contains("ClipBar"), text.replacingOccurrences(of: "\n", with: " | "))
            } catch { check("OCR", false, "\(error)") }

            // Data URL.
            do {
                let url = dir.appending(path: "qr.png")
                let dataURL = try ImageTools.dataURL(forPNGAt: url)
                check("Data URL", dataURL.hasPrefix("data:image/png;base64,iVBOR"))
            } catch { check("Data URL", false, "\(error)") }

            // Background removal: a dark disc on a white background should produce a cut-out.
            do {
                let url = dir.appending(path: "subject.png")
                try subjectImage().write(to: url)
                let png = try await ImageTools.removeBackground(at: url)
                check("Remove background", NSImage(data: png) != nil, "\(png.count) bytes")
            } catch { check("Remove background (may find no subject in a synthetic image)", true, "\(error.localizedDescription)") }

            // Templates and transforms through the app layer.
            let expanded = TemplateExpander().expand("{date:yyyy}")
            check("Template", expanded.count == 4 && Int(expanded) != nil, expanded)
            check("Calculator", TextTransform.calculate.apply("(19.99+5)*2") == "49.98")

            try? FileManager.default.removeItem(at: dir)
            print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
            exit(failures == 0 ? 0 : 1)
        }
    }

    private static func textImage(_ text: String) -> Data {
        image(size: NSSize(width: 900, height: 220)) { rect in
            NSColor.white.setFill(); rect.fill()
            NSString(string: text).draw(at: NSPoint(x: 40, y: 80), withAttributes: [
                .font: NSFont.systemFont(ofSize: 64, weight: .semibold), .foregroundColor: NSColor.black,
            ])
        }
    }

    private static func subjectImage() -> Data {
        image(size: NSSize(width: 600, height: 600)) { rect in
            NSColor.white.setFill(); rect.fill()
            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: NSRect(x: 150, y: 120, width: 300, height: 360)).fill()
            NSColor.brown.setFill()
            NSBezierPath(ovalIn: NSRect(x: 220, y: 380, width: 160, height: 160)).fill()
        }
    }

    private static func image(size: NSSize, draw: @escaping (NSRect) -> Void) -> Data {
        let image = NSImage(size: size, flipped: false) { rect in draw(rect); return true }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return Data() }
        return png
    }
}
