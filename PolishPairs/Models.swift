import Foundation
import CoreGraphics

enum Lang: String {
    case polish = "pl"
    case english = "en"
    case unknown = "?"
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
    var title: String?
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
