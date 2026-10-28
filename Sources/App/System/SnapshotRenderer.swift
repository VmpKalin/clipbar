import AppKit
import SwiftUI

/// Renders the panel with sample data into PNG files, then quits.
///
///     ClipBar.app/Contents/MacOS/ClipBar --snapshot /path/to/dir
///
/// Used to check the UI without screen-recording permission. Uses an in-memory store,
/// so the real history is never touched.
@MainActor
enum SnapshotRenderer {
    static var isRequested: Bool { CommandLine.arguments.contains("--snapshot") }

    private static var outputDirectory: URL {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), args.indices.contains(i + 1) {
            return URL(fileURLWithPath: args[i + 1])
        }
        return FileManager.default.temporaryDirectory.appending(path: "ClipBarSnapshots")
    }

    struct Scenario {
        let name: String
        var dark = false
        let configure: (PanelState, Seeded) -> Void
    }

    struct Seeded {
        var clips: [String: ClipItem] = [:]
        var snippets: [String: Snippet] = [:]
    }

    static func run(model: AppModel) {
        let dir = outputDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let seeded = seed(model)

        let scenarios: [Scenario] = [
            Scenario(name: "01-clipboard") { s, d in s.select(.clip(d.clips["command"]!.id)) },
            Scenario(name: "02-clipboard-dark", dark: true) { s, d in s.select(.clip(d.clips["command"]!.id)) },
            Scenario(name: "03-image-preview") { s, d in s.select(.clip(d.clips["image"]!.id)) },
            Scenario(name: "04-color-preview", dark: true) { s, d in s.select(.clip(d.clips["color"]!.id)) },
            Scenario(name: "05-files-preview") { s, d in s.select(.clip(d.clips["files"]!.id)) },
            Scenario(name: "06-quick-search") { s, _ in s.search = "mail" },
            Scenario(name: "07-section-code") { s, _ in s.clipSection = .code },
            Scenario(name: "08-library") { s, d in s.tab = .library; s.select(.snippet(d.snippets["email"]!.id)) },
            Scenario(name: "09-library-dynamic", dark: true) { s, d in
                s.tab = .library
                s.libraryGroupID = d.snippets["today"]!.group?.id
                s.select(.snippet(d.snippets["today"]!.id))
            },
            Scenario(name: "10-add-to-library") { s, d in
                s.select(.clip(d.clips["address"]!.id))
                s.editor = .snippet(.init(title: "Home address", value: d.clips["address"]!.text ?? "",
                                          groupID: d.snippets["email"]!.group?.id))
            },
            Scenario(name: "11-contacts") { s, _ in s.tab = .contacts },
            Scenario(name: "12-no-preview") { s, _ in s.showPreview = false },
        ]

        Task { @MainActor in
            for scenario in scenarios {
                let state = PanelState()
                state.showPreview = true
                scenario.configure(state, seeded)
                let root = ZStack {
                    LinearGradient(colors: scenario.dark
                                   ? [Color(red: 0.12, green: 0.14, blue: 0.3), Color(red: 0.35, green: 0.12, blue: 0.3)]
                                   : [Color(red: 0.55, green: 0.75, blue: 0.95), Color(red: 0.95, green: 0.7, blue: 0.8)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    PanelRootView()
                        .environment(model)
                        .environment(state)
                        .modelContainer(model.container)
                        .padding(20)
                }
                await render(root, size: NSSize(width: 520, height: 660), dark: scenario.dark,
                             to: dir.appending(path: "\(scenario.name).png"))
                state.showPreview = true
            }
            await render(SettingsView().environment(model), size: NSSize(width: 520, height: 470), dark: false,
                         to: dir.appending(path: "13-settings.png"))
            print("Snapshots written to \(dir.path)")
            exit(0)
        }
    }

    private static func render<V: View>(_ view: V, size: NSSize, dark: Bool, to url: URL) async {
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = dark ? .black : .white
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hosting.frame = NSRect(origin: .zero, size: size)
        window.contentView = hosting
        window.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(900))
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
        window.orderOut(nil)
    }

    // MARK: Sample data

    private static func seed(_ model: AppModel) -> Seeded {
        var d = Seeded()
        let store = model.store
        let now = Date()
        func add(_ key: String, _ payload: ClipPayload, minutesAgo: Double, used: Int = 0, pinned: Bool = false) {
            guard let item = store.ingest(payload, now: now.addingTimeInterval(-minutesAgo * 60)) else { return }
            for _ in 0..<used { store.markUsed(item) }
            if pinned { store.togglePin(item) }
            d.clips[key] = item
        }
        add("address", ClipPayload(text: "Khreshchatyk St, 22, Kyiv, 01001", sourceAppBundleID: "com.apple.mail", sourceAppName: "Mail"), minutesAgo: 400, used: 3, pinned: true)
        add("paragraph", ClipPayload(text: "Liquid Glass is a new design material that reflects and refracts its surroundings, bringing focus to content while staying out of the way.", sourceAppBundleID: "com.apple.Safari", sourceAppName: "Safari"), minutesAgo: 240)
        add("json", ClipPayload(text: #"{"name": "ClipBar", "version": 2, "features": ["history", "library", "contacts"]}"#, sourceAppBundleID: "com.apple.dt.Xcode", sourceAppName: "Xcode"), minutesAgo: 180)
        add("phone", ClipPayload(text: "+380 67 123 45 67", sourceAppBundleID: "com.apple.MobileSMS", sourceAppName: "Messages"), minutesAgo: 150, used: 2)
        add("email", ClipPayload(text: "hello@clipbar.app", sourceAppBundleID: "com.apple.mail", sourceAppName: "Mail"), minutesAgo: 120, used: 5)
        add("files", ClipPayload(text: "/Applications/Xcode.app\n/Applications/Safari.app\n\(NSHomeDirectory())/Desktop", sourceAppBundleID: "com.apple.finder", sourceAppName: "Finder"), minutesAgo: 90)
        add("image", ClipPayload(imageData: sampleImage(), sourceAppBundleID: "com.apple.Preview", sourceAppName: "Preview"), minutesAgo: 60)
        add("color", ClipPayload(text: "#5E5CE6", sourceAppBundleID: "com.figma.Desktop", sourceAppName: "Figma"), minutesAgo: 40)
        add("link", ClipPayload(text: "https://developer.apple.com/design/human-interface-guidelines/materials", sourceAppBundleID: "com.apple.Safari", sourceAppName: "Safari"), minutesAgo: 20, used: 1)
        add("path", ClipPayload(text: "/Applications/Xcode.app", sourceAppBundleID: "com.apple.Terminal", sourceAppName: "Terminal"), minutesAgo: 8)
        add("command", ClipPayload(text: "xcodebuild -scheme ClipBar -destination 'platform=macOS' build", sourceAppBundleID: "com.apple.Terminal", sourceAppName: "Terminal"), minutesAgo: 1)

        let lib = model.library
        if let personal = lib.group(named: "Personal") {
            d.snippets["email"] = lib.addSnippet(title: "Email", value: "hello@clipbar.app", keyword: "@mail", to: personal)
            lib.addSnippet(title: "Phone", value: "+380 67 123 45 67", keyword: "@tel", to: personal)
            lib.addSnippet(title: "Home address", value: "Khreshchatyk St, 22, Kyiv, 01001", to: personal)
            lib.addSnippet(title: "IBAN", value: "UA21 3223 1300 0002 6007 2335 6600 1", keyword: "iban", to: personal)
        }
        if let work = lib.group(named: "Work") {
            lib.addSnippet(title: "Zoom link", value: "https://zoom.us/j/1234567890", keyword: "zoom", to: work)
            lib.addSnippet(title: "Out of office", value: "I'm away until {date:dd.MM} and will reply when I'm back.", to: work)
        }
        d.snippets["today"] = lib.allSnippets().first { $0.title == "Today" }
        return d
    }

    private static func sampleImage() -> Data {
        let size = NSSize(width: 640, height: 400)
        let image = NSImage(size: size, flipped: false) { rect in
            let gradient = NSGradient(colors: [.systemIndigo, .systemPink, .systemOrange])
            gradient?.draw(in: rect, angle: 30)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 56, weight: .bold), .foregroundColor: NSColor.white,
            ]
            NSString(string: "ClipBar").draw(at: NSPoint(x: 40, y: 40), withAttributes: attrs)
            return true
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return Data() }
        return png
    }
}
