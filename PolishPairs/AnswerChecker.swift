import Foundation

enum Verdict {
    case correct
    case accentsOnly   // right apart from diacritics (ą/ć/ę/ł/ń/ó/ś/ź/ż)
    case wrong
}

/// Lenient answer matching: case, punctuation, apostrophes and a leading English "to " don't matter;
/// (bracketed) notes are optional; any comma/semicolon/slash alternative counts
/// ("to do, to make" accepts "make"; "wolny (m.), wolna (f.)" accepts "wolna").
enum AnswerChecker {
    static func check(_ input: String, answer: String, answerIsEnglish: Bool) -> Verdict {
        let typed = normalize(input, english: answerIsEnglish)
        guard !typed.isEmpty else { return .wrong }
        let accepted = variants(of: answer, english: answerIsEnglish)
        if accepted.contains(typed) { return .correct }
        let folded = fold(typed)
        if accepted.contains(where: { fold($0) == folded }) { return .accentsOnly }
        return .wrong
    }

    static func variants(of answer: String, english: Bool) -> Set<String> {
        let unbracketed = answer.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        var raw = [answer, unbracketed]
        raw += unbracketed.split(whereSeparator: { ",;/".contains($0) }).map(String.init)
        return Set(raw.map { normalize($0, english: english) }.filter { !$0.isEmpty })
    }

    static func normalize(_ s: String, english: Bool) -> String {
        var t = s.lowercased()
        t = t.replacingOccurrences(of: #"['’`]"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespaces)
        if english, t.hasPrefix("to ") { t.removeFirst(3) }
        return t
    }

    /// ł isn't a combining-mark letter, so diacritic folding alone leaves it.
    static func fold(_ s: String) -> String {
        s.replacingOccurrences(of: "ł", with: "l").folding(options: .diacriticInsensitive, locale: nil)
    }
}
