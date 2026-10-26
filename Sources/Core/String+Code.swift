import Foundation

public extension String {
    /// Heuristic: does this clip look like a shell command or code? Used to pick a monospaced font.
    var looksLikeCode: Bool {
        let text = trimmingCharacters(in: .whitespaces)
        let prefixes = ["$ ", "./", "sudo ", "git ", "npm ", "yarn ", "pnpm ", "brew ", "xcodebuild", "python", "pip ",
                        "cd ", "ls ", "curl ", "docker ", "swift ", "make ", "cargo ", "go ", "--", "-"]
        if prefixes.contains(where: { text.hasPrefix($0) }) { return true }
        if text.contains("{") && text.contains("}") { return true }
        if text.contains("();") || text.contains(" => ") || text.contains(" -> ") { return true }
        return false
    }
}
