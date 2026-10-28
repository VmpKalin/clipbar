import Foundation

/// Scores how well a query matches a candidate string. Higher is better, nil means no match.
///
/// Order of preference: exact match > prefix > word prefix > substring > fuzzy subsequence.
public enum SearchMatcher {
    public static func score(_ query: String, in candidate: String) -> Int? {
        let q = query.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        guard !q.isEmpty else { return 0 }
        let c = candidate.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        if c == q { return 1000 }
        if c.hasPrefix(q) { return 800 - min(c.count, 200) / 10 }
        if let range = c.range(of: q) {
            let atWordStart = range.lowerBound == c.startIndex
                || !(c[c.index(before: range.lowerBound)].isLetter || c[c.index(before: range.lowerBound)].isNumber)
            let base = atWordStart ? 600 : 400
            return base - min(c.distance(from: c.startIndex, to: range.lowerBound), 200)
        }
        // All query words present somewhere.
        let words = q.split(separator: " ")
        if words.count > 1, words.allSatisfy({ c.contains($0) }) { return 300 }
        // Fuzzy subsequence (only for short queries against short candidates, to avoid noise).
        guard q.count >= 2, q.count <= 24, !q.contains(" "), c.count <= 64 else { return nil }
        var index = c.startIndex
        var gaps = 0
        for ch in q {
            guard let found = c[index...].firstIndex(of: ch) else { return nil }
            gaps += c.distance(from: index, to: found)
            index = c.index(after: found)
        }
        guard gaps <= q.count * 2 else { return nil }
        let score = 200 - gaps * 8
        return score > 80 ? score : nil
    }

    /// Best score over several fields of the same item.
    public static func score(_ query: String, fields: [String?]) -> Int? {
        fields.compactMap { $0 }.compactMap { score(query, in: $0) }.max()
    }
}
