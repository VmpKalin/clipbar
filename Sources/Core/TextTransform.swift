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
    case sortLines
    case uniqueLines
    case removeTracking
    case colorToRGB
    case colorToHex
    case timestampToDate
    case calculate
    case jsonEscape

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
        case .sortLines: "Sort Lines"
        case .uniqueLines: "Remove Duplicate Lines"
        case .removeTracking: "Remove Tracking from Link"
        case .colorToRGB: "Color as rgb()"
        case .colorToHex: "Color as #HEX"
        case .timestampToDate: "Timestamp to Date"
        case .calculate: "Calculate Result"
        case .jsonEscape: "Escape as JSON String"
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
        case .sortLines, .uniqueLines: "arrow.up.arrow.down"
        case .removeTracking: "link.badge.plus"
        case .colorToRGB, .colorToHex: "paintpalette"
        case .timestampToDate: "calendar"
        case .calculate: "equal.square"
        case .jsonEscape: "quote.closing"
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
        case .sortLines:
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            result = lines.count > 1 ? lines.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator: "\n") : nil
        case .uniqueLines:
            var seen = Set<String>()
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            result = lines.count > 1 ? lines.filter { seen.insert($0).inserted }.joined(separator: "\n") : nil
        case .removeTracking: result = Self.removeTracking(text)
        case .colorToRGB:
            if let c = ContentInspector.color(in: text) {
                let rgb = "\(Int((c.r * 255).rounded())), \(Int((c.g * 255).rounded())), \(Int((c.b * 255).rounded()))"
                result = c.a < 1 ? "rgba(\(rgb), \(String(format: "%.2g", c.a)))" : "rgb(\(rgb))"
            } else { result = nil }
        case .colorToHex:
            if let c = ContentInspector.color(in: text) {
                result = String(format: "#%02X%02X%02X", Int((c.r * 255).rounded()), Int((c.g * 255).rounded()), Int((c.b * 255).rounded()))
            } else { result = nil }
        case .timestampToDate: result = Self.timestampToDate(text)
        case .calculate: result = Calculator.evaluate(text).map(Calculator.format)
        case .jsonEscape:
            result = (try? JSONSerialization.data(withJSONObject: text, options: [.fragmentsAllowed, .withoutEscapingSlashes]))
                .flatMap { String(data: $0, encoding: .utf8) }
        }
        guard let result, !result.isEmpty, result != text else { return nil }
        return result
    }

    static func removeTracking(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: t), components.scheme?.hasPrefix("http") == true,
              let items = components.queryItems, !items.isEmpty else { return nil }
        let tracking: Set<String> = ["fbclid", "gclid", "dclid", "msclkid", "mc_cid", "mc_eid", "igshid", "yclid",
                                     "_hsenc", "_hsmi", "ref_src", "si", "spm", "trk", "mkt_tok"]
        let kept = items.filter { item in
            let name = item.name.lowercased()
            return !name.hasPrefix("utm_") && !tracking.contains(name)
        }
        guard kept.count != items.count else { return nil }
        components.queryItems = kept.isEmpty ? nil : kept
        return components.string
    }

    static func timestampToDate(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 9, t.count <= 13, let value = Double(t), value > 0 else { return nil }
        let seconds = t.count == 13 ? value / 1000 : value
        let date = Date(timeIntervalSince1970: seconds)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = .current
        return f.string(from: date)
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

/// A tiny arithmetic evaluator for "Calculate Result": + - * / % ^ and parentheses.
public enum Calculator {
    public static func evaluate(_ text: String) -> Double? {
        let expr = text.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")
        guard !expr.isEmpty, expr.count < 200,
              expr.allSatisfy({ "0123456789.+-*/%^()".contains($0) }),
              expr.contains(where: { "+*/%^".contains($0) }) || expr.dropFirst().contains("-") else { return nil }
        // Dates and phone-like strings ("2026-10-28", "067-123-45-67") are not subtractions.
        if !expr.contains(where: { "+*/%^()".contains($0) }), expr.filter({ $0 == "-" }).count >= 2 { return nil }
        var parser = Parser(chars: Array(expr))
        guard let value = parser.expression(), parser.index == parser.chars.count, value.isFinite else { return nil }
        return value
    }

    public static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.maximumFractionDigits = 10
        f.decimalSeparator = "."
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    private struct Parser {
        let chars: [Character]
        var index = 0

        mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while index < chars.count, chars[index] == "+" || chars[index] == "-" {
                let op = chars[index]; index += 1
                guard let rhs = term() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func term() -> Double? {
            guard var value = power() else { return nil }
            while index < chars.count, "*/%".contains(chars[index]) {
                let op = chars[index]; index += 1
                guard let rhs = power() else { return nil }
                switch op {
                case "*": value *= rhs
                case "/": guard rhs != 0 else { return nil }; value /= rhs
                default: guard rhs != 0 else { return nil }; value = value.truncatingRemainder(dividingBy: rhs)
                }
            }
            return value
        }

        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if index < chars.count, chars[index] == "^" {
                index += 1
                guard let exp = power() else { return nil }
                return pow(base, exp)
            }
            return base
        }

        mutating func unary() -> Double? {
            if index < chars.count, chars[index] == "-" { index += 1; return unary().map { -$0 } }
            if index < chars.count, chars[index] == "+" { index += 1; return unary() }
            return primary()
        }

        mutating func primary() -> Double? {
            if index < chars.count, chars[index] == "(" {
                index += 1
                guard let value = expression(), index < chars.count, chars[index] == ")" else { return nil }
                index += 1
                return value
            }
            let start = index
            while index < chars.count, chars[index].isNumber || chars[index] == "." { index += 1 }
            guard index > start else { return nil }
            return Double(String(chars[start..<index]))
        }
    }
}
