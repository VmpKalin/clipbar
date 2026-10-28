import Foundation

/// Ways to change a text clip before pasting it.
public enum TextTransform: String, CaseIterable, Identifiable, Sendable {
    case uppercase
    case lowercase
    case titleCase
    case trimWhitespace
    case singleLine
    case removeEmptyLines
    case jsonPretty
    case jsonMinify
    case urlEncode
    case urlDecode
    case base64Encode
    case base64Decode
    case snakeCase
    case camelCase
    case stripMarkdown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .uppercase: "UPPERCASE"
        case .lowercase: "lowercase"
        case .titleCase: "Title Case"
        case .trimWhitespace: "Trim Whitespace"
        case .singleLine: "Join Into One Line"
        case .removeEmptyLines: "Remove Empty Lines"
        case .jsonPretty: "Pretty-Print JSON"
        case .jsonMinify: "Minify JSON"
        case .urlEncode: "URL Encode"
        case .urlDecode: "URL Decode"
        case .base64Encode: "Base64 Encode"
        case .base64Decode: "Base64 Decode"
        case .snakeCase: "snake_case"
        case .camelCase: "camelCase"
        case .stripMarkdown: "Strip Markdown"
        }
    }

    public var systemImage: String {
        switch self {
        case .uppercase, .lowercase, .titleCase: "textformat"
        case .trimWhitespace, .singleLine, .removeEmptyLines: "text.alignleft"
        case .jsonPretty, .jsonMinify: "curlybraces"
        case .urlEncode, .urlDecode: "link"
        case .base64Encode, .base64Decode: "lock.doc"
        case .snakeCase, .camelCase: "character.cursor.ibeam"
        case .stripMarkdown: "text.badge.minus"
        }
    }

    /// Returns the transformed text, or nil when the transform does not apply
    /// (e.g. invalid JSON or Base64) or would not change anything.
    public func apply(_ text: String) -> String? {
        let result: String?
        switch self {
        case .uppercase: result = text.uppercased()
        case .lowercase: result = text.lowercased()
        case .titleCase: result = text.capitalized
        case .trimWhitespace:
            result = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .singleLine:
            result = text.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        case .removeEmptyLines:
            result = text.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n")
        case .jsonPretty: result = Self.reformatJSON(text, pretty: true)
        case .jsonMinify: result = Self.reformatJSON(text, pretty: false)
        case .urlEncode: result = text.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
        case .urlDecode: result = text.removingPercentEncoding
        case .base64Encode: result = Data(text.utf8).base64EncodedString()
        case .base64Decode:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let padded = trimmed + String(repeating: "=", count: (4 - trimmed.count % 4) % 4)
            result = Data(base64Encoded: padded).flatMap { String(data: $0, encoding: .utf8) }
        case .snakeCase: result = Self.words(in: text).map { $0.lowercased() }.joined(separator: "_")
        case .camelCase:
            let words = Self.words(in: text)
            result = words.enumerated().map { i, w in i == 0 ? w.lowercased() : w.capitalized }.joined()
        case .stripMarkdown: result = Self.stripMarkdown(text)
        }
        guard let result, !result.isEmpty, result != text else { return nil }
        return result
    }

    static func reformatJSON(_ text: String, pretty: Bool) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed]) else {
            return nil
        }
        var options: JSONSerialization.WritingOptions = [.withoutEscapingSlashes, .fragmentsAllowed]
        if pretty { options.formUnion([.prettyPrinted, .sortedKeys]) }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: options) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func words(in text: String) -> [String] {
        // Split on non-alphanumerics and on lower→upper camel boundaries.
        var words: [String] = []
        var current = ""
        var previousLower = false
        for ch in text {
            if ch.isLetter || ch.isNumber {
                if ch.isUppercase && previousLower && !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                current.append(ch)
                previousLower = ch.isLowercase || ch.isNumber
            } else {
                if !current.isEmpty { words.append(current) }
                current = ""
                previousLower = false
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    static func stripMarkdown(_ text: String) -> String {
        var s = text
        s = s.replacing(/\[([^\]]+)\]\([^)]+\)/) { String($0.1) }        // [title](url)
        s = s.replacing(/(\*\*|__)(.+?)\1/) { String($0.2) }             // bold
        s = s.replacing(/(\*|_)(.+?)\1/) { String($0.2) }                // italic
        s = s.replacing(/`([^`]+)`/) { String($0.1) }                    // inline code
        s = s.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            var l = String(line)
            l = l.replacing(/^\s{0,3}#{1,6}\s+/, with: "")                // headings
            l = l.replacing(/^\s*>\s?/, with: "")                         // quotes
            l = l.replacing(/^\s*[-*+]\s+/, with: "• ")                   // bullets
            return l
        }.joined(separator: "\n")
        return s
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
