import Foundation
import Synchronization

/// Extra facts about a text clip, used for smart sections, icons and previews.
public enum ContentTag: String, CaseIterable, Sendable {
    case email
    case phone
    case color
    case json
    case code
    case number
    /// API keys, tokens, private keys: masked in the UI and removed automatically.
    case secret
}

public enum ContentInspector {
    private static let cache = Mutex<[String: Set<ContentTag>]>([:])

    /// Same as `tags(for:)` but memoized by a content key (the clip's hash).
    public static func cachedTags(for text: String, key: String) -> Set<ContentTag> {
        if let hit = cache.withLock({ $0[key] }) { return hit }
        let tags = tags(for: text)
        cache.withLock { dict in
            if dict.count > 5000 { dict.removeAll() }
            dict[key] = tags
        }
        return tags
    }

    public static func tags(for raw: String) -> Set<ContentTag> {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        var tags: Set<ContentTag> = []
        if isEmail(text) { tags.insert(.email) }
        if isPhone(text) { tags.insert(.phone) }
        if color(in: text) != nil { tags.insert(.color) }
        if isJSON(text) { tags.insert(.json) }
        if text.looksLikeCode || tags.contains(.json) { tags.insert(.code) }
        if isNumber(text) { tags.insert(.number) }
        if isSecret(text) { tags = [.secret] }
        return tags
    }

    public static func isEmail(_ text: String) -> Bool {
        guard !text.contains(" "), !text.contains("\n") else { return false }
        return text.wholeMatch(of: /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/) != nil
    }

    public static func isPhone(_ text: String) -> Bool {
        guard text.count <= 24, !text.contains("\n") else { return false }
        guard text.wholeMatch(of: /\+?\(?[0-9][0-9 ()\-.]{5,}[0-9]/) != nil else { return false }
        // Dates such as 2026-10-28 or 28.10.2026 are not phone numbers.
        if text.wholeMatch(of: /\d{4}[\-.\/]\d{1,2}[\-.\/]\d{1,2}|\d{1,2}[\-.\/]\d{1,2}[\-.\/]\d{2,4}/) != nil { return false }
        let digits = text.filter(\.isNumber).count
        return (7...15).contains(digits) && (text.hasPrefix("+") || text.contains(" ") || text.contains("-") || text.contains("("))
    }

    /// Well-known credential formats. Conservative on purpose: false positives would hide normal clips.
    public static func isSecret(_ text: String) -> Bool {
        if text.contains("-----BEGIN") && text.contains("PRIVATE KEY-----") { return true }
        guard !text.contains(" "), !text.contains("\n"), text.count >= 20, text.count <= 4000 else { return false }
        let patterns: [Regex<Substring>] = [
            /sk-(?:ant-|proj-)?[A-Za-z0-9_\-]{20,}/,           // OpenAI / Anthropic
            /gh[pousr]_[A-Za-z0-9]{30,}/,                     // GitHub
            /github_pat_[A-Za-z0-9_]{40,}/,
            /AKIA[0-9A-Z]{16}/,                               // AWS access key id
            /xox[baprs]-[A-Za-z0-9\-]{10,}/,                  // Slack
            /AIza[0-9A-Za-z_\-]{35}/,                         // Google API key
            /(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{20,}/,           // Stripe
            /eyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}/, // JWT
            /glpat-[A-Za-z0-9_\-]{20,}/,                      // GitLab
            /npm_[A-Za-z0-9]{36}/,                            // npm
        ]
        return patterns.contains { text.wholeMatch(of: $0) != nil }
    }

    /// "sk-ant-abcd…wxyz" style mask that keeps a hint of the value.
    public static func masked(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.contains("PRIVATE KEY") { return "•••• private key ••••" }
        guard t.count > 12 else { return String(repeating: "•", count: t.count) }
        return "\(t.prefix(6))••••••\(t.suffix(4))"
    }

    public static func isNumber(_ text: String) -> Bool {
        text.count < 40 && Double(text.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "")) != nil
    }

    public static func isJSON(_ text: String) -> Bool {
        guard let first = text.first, first == "{" || first == "[" else { return false }
        return (try? JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])) != nil
    }

    /// RGBA components 0…1 when the text is a CSS-style colour (#rgb, #rrggbb, #rrggbbaa, rgb(), rgba()).
    public static func color(in text: String) -> (r: Double, g: Double, b: Double, a: Double)? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        if let m = t.wholeMatch(of: /#?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})/) {
            // Plain 6-digit numbers without "#" are too ambiguous.
            if !t.hasPrefix("#") && t.allSatisfy(\.isNumber) { return nil }
            if !t.hasPrefix("#") { return nil }
            var hex = String(m.1)
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            guard let value = UInt64(hex, radix: 16) else { return nil }
            if hex.count == 8 {
                return (Double((value >> 24) & 0xff) / 255, Double((value >> 16) & 0xff) / 255,
                        Double((value >> 8) & 0xff) / 255, Double(value & 0xff) / 255)
            }
            return (Double((value >> 16) & 0xff) / 255, Double((value >> 8) & 0xff) / 255,
                    Double(value & 0xff) / 255, 1)
        }
        if let m = t.wholeMatch(of: /rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([0-9.]+)\s*)?\)/) {
            guard let r = Double(m.1), let g = Double(m.2), let b = Double(m.3),
                  r <= 255, g <= 255, b <= 255 else { return nil }
            let a = m.4.flatMap { Double($0) } ?? 1
            return (r / 255, g / 255, b / 255, min(a, 1))
        }
        return nil
    }

    /// Simple statistics shown in the preview.
    public static func stats(for text: String) -> (characters: Int, words: Int, lines: Int) {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        let lines = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
        return (text.count, words, lines)
    }
}
