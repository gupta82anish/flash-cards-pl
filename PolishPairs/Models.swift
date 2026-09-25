import Foundation
import CoreGraphics

enum Lang: String {
    case polish = "pl"
    case english = "en"
    case unknown = "?"
}

/// What kind of page is being scanned, so the analyzer runs only the layout that applies.
enum ScanMode: String, CaseIterable, Identifiable {
    case auto        // try both layouts (a page may hold a table and an exercise)
    case table       // Layout A: vocabulary tables only
    case numbered    // Layout B: numbered exercises only

    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "Auto"
        case .table: return "Table"
        case .numbered: return "Numbered"
        }
    }
    var runsTable: Bool { self != .numbered }
    var runsNumbered: Bool { self != .table }
}

/// One piece of text on a page. Coordinates are normalized (0...1) with the origin at the TOP-left.
struct Segment: Identifiable {
    let id = UUID()
    var text: String
    var rect: CGRect
    var confidence: Float
    var page: Int
    var lang: Lang = .unknown

    var midY: CGFloat { rect.midY }
    var minX: CGFloat { rect.minX }
    var height: CGFloat { rect.height }
}

struct Pair: Identifiable {
    let id = UUID()
    var polish: String
    var english: String
    var source: String
}

struct AnalysisResult {
    var mode: ScanMode = .auto
    var tablePairs: [Pair] = []
    var numberedPairs: [Pair] = []
    var problems: [String] = []
    var leftovers: [Segment] = []
    var segments: [Segment] = []
    var orientations: [String] = []
    var report: String = ""
}

func median(_ values: [CGFloat]) -> CGFloat {
    guard !values.isEmpty else { return 0 }
    let s = values.sorted()
    let n = s.count
    return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
}
