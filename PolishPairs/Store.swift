import Foundation
import SwiftData

/// How the card went the last time it was studied.
enum Outcome: String {
    case new, correct, wrong, skipped
}

/// Which deck a card belongs to: vocabulary-table entries are words, numbered-exercise items are sentences.
enum CardKind: String, CaseIterable, Identifiable {
    case words, sentences

    var id: String { rawValue }
    var label: String { self == .words ? "Words" : "Sentences" }
}

@Model
final class Card {
    var polish: String
    var english: String
    var kindRaw: String = CardKind.words.rawValue   // default lets SwiftData migrate cards saved before decks existed
    var createdAt: Date
    var lastReviewed: Date?
    var lastOutcomeRaw: String
    var correctCount: Int
    var wrongCount: Int
    var skipCount: Int
    var needsPractice: Bool

    init(polish: String, english: String, kind: CardKind) {
        self.polish = polish
        self.english = english
        self.kindRaw = kind.rawValue
        self.createdAt = .now
        self.lastReviewed = nil
        self.lastOutcomeRaw = Outcome.new.rawValue
        self.correctCount = 0
        self.wrongCount = 0
        self.skipCount = 0
        self.needsPractice = false
    }

    var kind: CardKind {
        get { CardKind(rawValue: kindRaw) ?? .words }
        set { kindRaw = newValue.rawValue }
    }

    var lastOutcome: Outcome {
        get { Outcome(rawValue: lastOutcomeRaw) ?? .new }
        set { lastOutcomeRaw = newValue.rawValue }
    }

    func record(_ outcome: Outcome) {
        lastOutcome = outcome
        lastReviewed = .now
        switch outcome {
        case .correct: correctCount += 1
        case .wrong: wrongCount += 1
        case .skipped: skipCount += 1
        case .new: break
        }
    }

    /// "I was right" after a wrong verdict (typo, or an alternative the checker didn't know).
    func overrideToCorrect() {
        wrongCount = max(0, wrongCount - 1)
        correctCount += 1
        lastOutcome = .correct
    }

    /// Duplicate check when saving a scan.
    static func key(_ polish: String, _ english: String) -> String {
        let clean = { (s: String) in s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        return clean(polish) + "\u{1F}" + clean(english)
    }
}

enum StudyDirection: String, CaseIterable, Identifiable {
    case plToEn, enToPl

    var id: String { rawValue }
    var label: String { self == .plToEn ? "Polish → English" : "English → Polish" }
    var promptName: String { self == .plToEn ? "Polish" : "English" }
    var answerName: String { self == .plToEn ? "English" : "Polish" }
    var answerIsEnglish: Bool { self == .plToEn }

    func prompt(_ card: Card) -> String { self == .plToEn ? card.polish : card.english }
    func answer(_ card: Card) -> String { self == .plToEn ? card.english : card.polish }
}

enum CardFilter: String, CaseIterable, Identifiable {
    case all, wrong, skipped, practice

    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .wrong: return "Wrong"
        case .skipped: return "Skipped"
        case .practice: return "Practice"
        }
    }

    func includes(_ card: Card) -> Bool {
        switch self {
        case .all: return true
        case .wrong: return card.lastOutcome == .wrong
        case .skipped: return card.lastOutcome == .skipped
        case .practice: return card.needsPractice
        }
    }
}
