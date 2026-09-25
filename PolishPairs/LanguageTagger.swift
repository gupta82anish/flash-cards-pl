import Foundation
import NaturalLanguage

enum LanguageTagger {
    private static let polishChars = Set("ąćęłńóśźżĄĆĘŁŃÓŚŹŻ")

    static func tag(_ text: String) -> Lang {
        // Polish diacritics settle it.
        if text.contains(where: { polishChars.contains($0) }) { return .polish }

        let letters = text.filter { $0.isLetter }
        if letters.count < 3 { return .unknown }

        // English infinitives in vocabulary tables: "to be", "to wait".
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.hasPrefix("to ") { return .english }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.polish, .english]
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 2)
        let pl = hypotheses[.polish] ?? 0
        let en = hypotheses[.english] ?? 0
        if pl >= 0.6 { return .polish }
        if en >= 0.6 { return .english }
        return .unknown
    }
}
