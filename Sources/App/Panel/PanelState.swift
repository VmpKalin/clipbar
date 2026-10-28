import Foundation
import Observation

/// UI state of the menu bar panel. Reset each time the panel opens.
@MainActor
@Observable
final class PanelState {
    enum Tab: String, CaseIterable, Identifiable {
        case clipboard, library, contacts
        var id: String { rawValue }
        var title: String {
            switch self {
            case .clipboard: "Clipboard"
            case .library: "Library"
            case .contacts: "Contacts"
            }
        }
        var systemImage: String {
            switch self {
            case .clipboard: "doc.on.clipboard"
            case .library: "books.vertical"
            case .contacts: "person.crop.circle"
            }
        }
    }

    enum Selection: Hashable {
        case clip(UUID)
        case snippet(UUID)
        case contactField(String)
    }

    struct SnippetDraft: Equatable {
        var existingID: UUID?
        var title = ""
        var value = ""
        var keyword = ""
        var groupID: UUID?
    }

    struct GroupDraft: Equatable {
        var existingID: UUID?
        var name = ""
        var symbol = "folder"
    }

    enum Editor: Equatable {
        case snippet(SnippetDraft)
        case clip(id: UUID, text: String)
        case group(GroupDraft)
    }

    var tab: Tab = .clipboard
    var search = ""
    var clipSection: ClipSection = .all
    /// nil = all groups.
    var libraryGroupID: UUID?
    private(set) var selection: Selection?
    var editor: Editor?
    var showPreview: Bool = UserDefaults.standard.object(forKey: "showPreview") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showPreview, forKey: "showPreview") }
    }
    /// Bumped when the panel opens so the search field can take focus.
    private(set) var openCount = 0
    /// Time of the last keyboard navigation; hover is ignored right after it.
    private(set) var lastKeyboardMove = Date.distantPast
    /// Set by keyboard navigation; the list scrolls to it.
    private(set) var scrollTarget: Selection?

    func select(_ selection: Selection?, scroll: Bool = false) {
        self.selection = selection
        if scroll { scrollTarget = selection }
    }

    func hoverSelect(_ selection: Selection) {
        guard Date().timeIntervalSince(lastKeyboardMove) > 0.35, self.selection != selection else { return }
        self.selection = selection
    }

    /// Moves the selection through `order` by `offset` (wrapping is disabled).
    func move(by offset: Int, in order: [Selection]) {
        guard !order.isEmpty else { return }
        lastKeyboardMove = Date()
        let index = selection.flatMap { order.firstIndex(of: $0) }
        let next: Int
        if let index {
            next = max(0, min(order.count - 1, index + offset))
        } else {
            next = offset >= 0 ? 0 : order.count - 1
        }
        select(order[next], scroll: true)
    }

    /// Keeps the selection valid for the current entries: selects the first entry when the
    /// current one disappeared.
    func ensureSelection(in order: [Selection]) {
        if let selection, order.contains(selection) { return }
        self.selection = order.first
    }

    func nextTab(_ step: Int = 1) {
        let all = Tab.allCases
        let i = all.firstIndex(of: tab) ?? 0
        tab = all[(i + step + all.count) % all.count]
        selection = nil
    }

    func prepareForOpen() {
        search = ""
        editor = nil
        tab = .clipboard
        clipSection = .all
        selection = nil
        scrollTarget = nil
        openCount += 1
    }
}
