#!/usr/bin/env swift
// Composes marketing images from panel snapshots.
//
//     ClipBar.app/Contents/MacOS/ClipBar --snapshot /tmp/shots
//     swift scripts/make-promo.swift /tmp/shots docs/promo
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: make-promo.swift <snapshots-dir> <output-dir>"); exit(1) }
let shots = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let canvas = NSSize(width: 2880, height: 1800)

struct Slide {
    let file: String
    let shot: String
    let eyebrow: String
    let title: String
    let body: String
    var dark = false
    var hue: [NSColor]
}

let slides: [Slide] = [
    Slide(file: "01-hero", shot: "01-clipboard", eyebrow: "CLIPBAR FOR MAC",
          title: "Your clipboard,\nsupercharged.",
          body: "Everything you copy — text, links, images, files — one keystroke away in the menu bar. ⇧⌘V.",
          hue: [.systemIndigo, .systemPurple, .systemPink]),
    Slide(file: "02-quick-search", shot: "06-quick-search", eyebrow: "QUICK SEARCH",
          title: "One search box\nfor everything.",
          body: "History, saved snippets and contacts in a single fuzzy search. Filter with app:safari or is:image.",
          hue: [.systemBlue, .systemTeal, .systemMint]),
    Slide(file: "03-library", shot: "08-library", eyebrow: "LIBRARY",
          title: "The things you\ntype every day.",
          body: "Emails, addresses, IBANs, links and replies — grouped, searchable by keyword, pasted in a blink.",
          hue: [.systemOrange, .systemPink, .systemPurple]),
    Slide(file: "04-dynamic", shot: "16-library-dynamic-light", eyebrow: "DYNAMIC SNIPPETS",
          title: "Snippets that\nfill themselves in.",
          body: "{date}, {time}, {uuid}, {clipboard} and more — always fresh when you paste.",
          hue: [.systemIndigo, .systemPurple, .systemBlue]),
    Slide(file: "05-images", shot: "03-image-preview", eyebrow: "IMAGES",
          title: "Screenshots\nthat do more.",
          body: "Copy text out of any image, scan QR codes, remove the background, save or paste as a data URL.",
          hue: [.systemPink, .systemOrange, .systemYellow]),
    Slide(file: "06-files", shot: "05-files-preview", eyebrow: "PATHS & FILES",
          title: "Any path, straight\nto Finder or Terminal.",
          body: "Copy a file or paste a path — ClipBar shows it, reveals it in Finder or opens a Terminal there.",
          hue: [.systemTeal, .systemBlue, .systemIndigo]),
    Slide(file: "07-colors", shot: "17-color-light", eyebrow: "SMART TYPES",
          title: "It knows what\nyou copied.",
          body: "Colors, JSON, code, emails and phone numbers are recognized with previews and one-click transforms.",
          hue: [.systemPurple, .systemIndigo, .systemPink]),
    Slide(file: "08-privacy", shot: "14-secret", eyebrow: "PRIVATE BY DESIGN",
          title: "Secrets stay\nsecret.",
          body: "API keys and tokens are masked and expire automatically. Password managers are ignored. Nothing leaves your Mac.",
          hue: [.systemGreen, .systemTeal, .systemBlue]),
]

func font(_ size: CGFloat, _ weight: NSFont.Weight, rounded: Bool = false) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard rounded, let d = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: d, size: size) ?? base
}

func symbol(_ name: String, _ size: CGFloat, _ color: NSColor) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        .applying(.init(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
}

func drawWallpaper(_ rect: NSRect, colors: [NSColor], dark: Bool) {
    (dark ? NSColor(white: 0.06, alpha: 1) : NSColor(white: 0.97, alpha: 1)).setFill()
    rect.fill()
    // Soft colored blobs.
    let blobs: [(CGFloat, CGFloat, CGFloat)] = [(0.78, 0.35, 0.55), (0.95, 0.85, 0.45), (0.45, 0.05, 0.5), (0.1, 0.9, 0.35)]
    for (i, b) in blobs.enumerated() {
        let c = colors[i % colors.count].withAlphaComponent(dark ? 0.55 : 0.45)
        let r = rect.width * b.2
        let center = NSPoint(x: rect.width * b.0, y: rect.height * b.1)
        NSGradient(colors: [c, c.withAlphaComponent(0)])?
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: r, options: [])
    }
}

func drawMenuBar(_ rect: NSRect, dark: Bool) -> NSPoint {
    let h: CGFloat = 52
    let bar = NSRect(x: 0, y: rect.height - h, width: rect.width, height: h)
    (dark ? NSColor(white: 0, alpha: 0.25) : NSColor(white: 1, alpha: 0.45)).setFill()
    bar.fill()
    let fg: NSColor = dark ? .white : .black
    let attrs: [NSAttributedString.Key: Any] = [.font: font(26, .semibold), .foregroundColor: fg]
    let regular: [NSAttributedString.Key: Any] = [.font: font(26, .regular), .foregroundColor: fg]
    symbol("apple.logo", 26, fg)?.draw(in: NSRect(x: 40, y: bar.minY + 12, width: 26, height: 30))
    NSString(string: "Finder").draw(at: NSPoint(x: 100, y: bar.minY + 10), withAttributes: attrs)
    var x: CGFloat = 220
    for item in ["File", "Edit", "View", "Go", "Window"] {
        NSString(string: item).draw(at: NSPoint(x: x, y: bar.minY + 10), withAttributes: regular)
        x += NSString(string: item).size(withAttributes: regular).width + 44
    }
    // Status items, right to left.
    var right = rect.width - 40
    let time = "Tue 3 Nov  9:41"
    let tw = NSString(string: time).size(withAttributes: regular).width
    right -= tw
    NSString(string: time).draw(at: NSPoint(x: right, y: bar.minY + 10), withAttributes: regular)
    for name in ["switch.2", "magnifyingglass", "wifi", "battery.75percent"] {
        right -= 64
        symbol(name, 26, fg)?.draw(in: NSRect(x: right, y: bar.minY + 11, width: 40, height: 30))
    }
    // ClipBar icon, highlighted.
    right -= 74
    let pill = NSRect(x: right - 10, y: bar.minY + 6, width: 60, height: 40)
    (dark ? NSColor(white: 1, alpha: 0.22) : NSColor(white: 0, alpha: 0.12)).setFill()
    NSBezierPath(roundedRect: pill, xRadius: 10, yRadius: 10).fill()
    symbol("doc.on.clipboard.fill", 26, fg)?.draw(in: NSRect(x: right + 2, y: bar.minY + 10, width: 36, height: 32))
    return NSPoint(x: pill.midX, y: bar.minY)
}

func drawPanel(_ shot: NSImage, anchor: NSPoint, dark: Bool) {
    // Snapshot is 1040×1320 with a 40 px gradient margin; crop to the panel.
    let src = NSRect(x: 40, y: 40, width: shot.size.width - 80, height: shot.size.height - 80)
    let scale: CGFloat = 1.2
    let size = NSSize(width: src.width * scale, height: src.height * scale)
    var origin = NSPoint(x: anchor.x - size.width * 0.62, y: anchor.y - 16 - size.height)
    origin.x = min(origin.x, canvas.width - size.width - 60)
    let frame = NSRect(origin: origin, size: size)
    let path = NSBezierPath(roundedRect: frame, xRadius: 52, yRadius: 52)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.6 : 0.28)
    shadow.shadowBlurRadius = 90
    shadow.shadowOffset = NSSize(width: 0, height: -30)
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    shot.draw(in: frame, from: src, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    NSColor(white: 1, alpha: dark ? 0.18 : 0.6).setStroke()
    path.lineWidth = 3
    path.stroke()
}

func drawCopy(_ slide: Slide, dark: Bool) {
    let fg: NSColor = dark ? .white : NSColor(white: 0.08, alpha: 1)
    let left: CGFloat = 170
    let maxWidth: CGFloat = 1150
    let para = NSMutableParagraphStyle()
    para.lineSpacing = 6

    let eyebrow: [NSAttributedString.Key: Any] = [
        .font: font(34, .bold), .foregroundColor: slide.hue[0].blended(withFraction: dark ? 0.35 : 0.1, of: fg) ?? fg,
        .kern: 4,
    ]
    let title: [NSAttributedString.Key: Any] = [.font: font(128, .bold, rounded: true), .foregroundColor: fg,
                                                 .paragraphStyle: para, .kern: -2]
    let body: [NSAttributedString.Key: Any] = [.font: font(46, .regular), .foregroundColor: fg.withAlphaComponent(0.72),
                                                .paragraphStyle: para]

    let t = NSAttributedString(string: slide.title, attributes: title)
    let b = NSAttributedString(string: slide.body, attributes: body)
    let tH = t.boundingRect(with: NSSize(width: maxWidth, height: 1000), options: .usesLineFragmentOrigin).height
    let bH = b.boundingRect(with: NSSize(width: maxWidth - 120, height: 1000), options: .usesLineFragmentOrigin).height
    let total = 50 + 40 + tH + 50 + bH
    var y = (canvas.height - 52) / 2 + total / 2

    y -= 50
    NSAttributedString(string: slide.eyebrow, attributes: eyebrow).draw(at: NSPoint(x: left, y: y))
    y -= 40 + tH
    t.draw(with: NSRect(x: left, y: y, width: maxWidth, height: tH), options: .usesLineFragmentOrigin)
    y -= 50 + bH
    b.draw(with: NSRect(x: left, y: y, width: maxWidth - 120, height: bH), options: .usesLineFragmentOrigin)
}

func render(_ slide: Slide) throws {
    guard let shot = NSImage(contentsOf: shots.appending(path: "\(slide.shot).png")) else {
        print("missing \(slide.shot)"); return
    }
    // Snapshots are @2x; treat their pixel size as points.
    if let rep = shot.representations.first { shot.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh) }

    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
    rep.size = canvas
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rect = NSRect(origin: .zero, size: canvas)
    drawWallpaper(rect, colors: slide.hue, dark: slide.dark)
    let anchor = drawMenuBar(rect, dark: slide.dark)
    drawPanel(shot, anchor: anchor, dark: slide.dark)
    drawCopy(slide, dark: slide.dark)
    NSGraphicsContext.restoreGraphicsState()

    let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    try jpeg?.write(to: out.appending(path: "\(slide.file).jpg"))
    print("wrote \(slide.file).jpg")
}

for slide in slides { try render(slide) }
