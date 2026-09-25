import Foundation
import CoreGraphics

/// Turns recognized text segments into Polish–English pairs.
///
/// Layout A: vocabulary tables — Polish column on the left, English column right next to it,
///           several tables may sit side by side. Paired by height on the page.
/// Layout B: numbered lists — English items 1…N on one page, Polish items 1…N on the facing page.
///           Paired by number.
struct Analyzer {
    var tag: (String) -> Lang

    private static let markerRe = try! NSRegularExpression(pattern: #"^(\d{1,2})[.,]$"#)
    private static let inlineRe = try! NSRegularExpression(pattern: #"^(\d{1,2})[.,]\s+(\S.*)$"#)
    private static let leadingNumberRe = try! NSRegularExpression(pattern: #"^\s*\d{1,2}[.,]?\s*"#)

    private final class Marker {
        let number: Int
        let segIndex: Int
        let page: Int
        let x: CGFloat
        let y: CGFloat
        let h: CGFloat
        let segMaxX: CGFloat
        var textX: CGFloat?
        var lines: [(CGFloat, String)] = []

        init(number: Int, segIndex: Int, segment: Segment) {
            self.number = number
            self.segIndex = segIndex
            self.page = segment.page
            self.x = segment.rect.minX
            self.y = segment.midY
            self.h = segment.height
            self.segMaxX = segment.rect.maxX
        }
    }

    private struct NumberedList {
        var lang: Lang
        var items: [Int: String]
        var page: Int
    }

    private struct Run {
        var indices: [Int]
        var minX: CGFloat
        var top: CGFloat
        var bottom: CGFloat
        var page: Int
    }

    func analyze(_ input: [Segment]) -> AnalysisResult {
        var segs = input.filter { Self.hasLetter($0.text) || Self.match(Self.markerRe, $0.text) != nil }
        for i in segs.indices { segs[i].lang = tag(segs[i].text) }

        var result = AnalysisResult()
        result.segments = segs
        guard !segs.isEmpty else {
            result.problems.append("No text found.")
            return result
        }

        let medianHeight = median(segs.map { $0.height })
        let headings = Set(segs.indices.filter { segs[$0].height > 1.6 * medianHeight })
        let pages = Array(Set(segs.map { $0.page })).sorted()
        var used = Set<Int>()

        // ---------- Title: tallest heading in the top 35% of the first page ----------
        let titleCandidates = headings.filter { segs[$0].page == pages[0] && segs[$0].midY < 0.35 && Self.hasLetter(segs[$0].text) }
        if let t = titleCandidates.max(by: { segs[$0].height < segs[$1].height }) {
            result.title = Self.stripLeadingNumber(segs[t].text)
        }

        // ---------- Layout B: numbered lists ----------
        var markers: [Marker] = []
        for (i, s) in segs.enumerated() where !headings.contains(i) {
            if let g = Self.match(Self.markerRe, s.text), let n = Int(g[0]) {
                markers.append(Marker(number: n, segIndex: i, segment: s))
            } else if let g = Self.match(Self.inlineRe, s.text), let n = Int(g[0]) {
                let m = Marker(number: n, segIndex: i, segment: s)
                let prefixFraction = CGFloat(s.text.count - g[1].count) / CGFloat(max(s.text.count, 1))
                m.textX = s.rect.minX + s.rect.width * prefixFraction
                m.lines = [(s.midY, g[1])]
                markers.append(m)
            }
        }
        for m in markers { used.insert(m.segIndex) }

        // A marker on its own ("11.") takes the text start from the nearest segment to its right.
        for m in markers where m.textX == nil {
            var best: (CGFloat, Int)?
            for (j, s) in segs.enumerated() where !used.contains(j) && !headings.contains(j) && s.page == m.page {
                guard s.rect.minX > m.x, s.rect.minX - m.segMaxX < 0.15, abs(s.midY - m.y) < 1.5 * m.h else { continue }
                let d = abs(s.midY - m.y)
                if best == nil || d < best!.0 { best = (d, j) }
            }
            if let b = best { m.textX = segs[b.1].rect.minX }
        }

        // Group markers into lists: same page, same left edge.
        var lists: [[Marker]] = []
        for page in pages {
            let pageMarkers = markers.filter { $0.page == page && $0.textX != nil }.sorted { $0.x < $1.x }
            var current: [Marker] = []
            for m in pageMarkers {
                if let last = current.last, m.x - last.x >= 0.05 {
                    lists.append(current)
                    current = []
                }
                current.append(m)
            }
            if !current.isEmpty { lists.append(current) }
        }

        var numbered: [NumberedList] = []
        for var list in lists where list.count >= 3 {
            list.sort { $0.y < $1.y }
            let textX = median(list.compactMap { $0.textX })
            let pitch = median(zip(list, list.dropFirst()).map { $1.y - $0.y })
            let low = list[0].y - pitch
            let high = list[list.count - 1].y + pitch
            let page = list[0].page

            // Unnumbered lines aligned with the text column belong to the nearest numbered item
            // (the continuation can sit above or below the number).
            for (j, s) in segs.enumerated() where !used.contains(j) && !headings.contains(j) && s.page == page {
                guard abs(s.rect.minX - textX) <= 0.025, s.midY >= low, s.midY <= high else { continue }
                guard let nearest = list.min(by: { abs($0.y - s.midY) < abs($1.y - s.midY) }) else { continue }
                if abs(nearest.y - s.midY) < 1.2 * pitch {
                    nearest.lines.append((s.midY, s.text))
                    used.insert(j)
                }
            }

            var items: [Int: String] = [:]
            for m in list {
                items[m.number] = m.lines.sorted { $0.0 < $1.0 }.map { $0.1 }.joined(separator: " ")
            }
            let tags = items.values.map { tag($0) }
            let pl = tags.filter { $0 == .polish }.count
            let en = tags.filter { $0 == .english }.count
            let lang: Lang = pl > en ? .polish : (en > pl ? .english : .unknown)
            numbered.append(NumberedList(lang: lang, items: items, page: page))
        }

        var usedPolishLists = Set<Int>()
        for e in numbered.indices where numbered[e].lang == .english {
            var best: (Int, Int)?
            for p in numbered.indices where numbered[p].lang == .polish && !usedPolishLists.contains(p) {
                let overlap = Set(numbered[e].items.keys).intersection(numbered[p].items.keys).count
                if best == nil || overlap > best!.0 { best = (overlap, p) }
            }
            guard let b = best, b.0 > 0 else {
                result.problems.append("Numbered English list on page \(numbered[e].page + 1) has no matching Polish list. Scan both facing pages together.")
                continue
            }
            usedPolishLists.insert(b.1)
            let english = numbered[e].items
            let polish = numbered[b.1].items
            let maxNumber = Set(english.keys).union(polish.keys).max() ?? 0
            guard maxNumber >= 1 else { continue }
            for n in 1...maxNumber {
                switch (polish[n], english[n]) {
                case let (p?, en?):
                    result.numberedPairs.append(Pair(polish: p, english: en, source: "#\(n)"))
                case (nil, _?):
                    result.problems.append("#\(n): Polish item not found")
                case (_?, nil):
                    result.problems.append("#\(n): English item not found")
                default:
                    result.problems.append("#\(n): missing on both pages")
                }
            }
        }
        for p in numbered.indices where numbered[p].lang == .polish && !usedPolishLists.contains(p) {
            result.problems.append("Numbered Polish list on page \(numbered[p].page + 1) has no matching English list.")
        }
        for l in numbered where l.lang == .unknown {
            result.problems.append("A numbered list on page \(l.page + 1) could not be identified as Polish or English.")
        }

        // ---------- Layout A: vocabulary tables ----------
        for page in pages {
            let rest = segs.indices.filter {
                !used.contains($0) && !headings.contains($0) && segs[$0].page == page
                    && Self.match(Self.markerRe, segs[$0].text) == nil
            }.sorted { segs[$0].rect.minX < segs[$1].rect.minX }

            // 1. Columns: cluster by left edge (a new column starts after a 0.04 jump in x).
            var columns: [[Int]] = []
            for j in rest {
                if let last = columns.last?.last, segs[j].rect.minX - segs[last].rect.minX < 0.04 {
                    columns[columns.count - 1].append(j)
                } else {
                    columns.append([j])
                }
            }

            // 2. Runs: split each column where there is a big vertical gap, so a table
            //    is not merged with unrelated text further down the page.
            var runs: [Run] = []
            for column in columns {
                let sorted = column.sorted { segs[$0].midY < segs[$1].midY }
                var current: [Int] = []
                for j in sorted {
                    if let last = current.last, segs[j].midY - segs[last].midY > 4 * medianHeight {
                        runs.append(makeRun(current, segs))
                        current = []
                    }
                    current.append(j)
                }
                if !current.isEmpty { runs.append(makeRun(current, segs)) }
            }

            // 3. Pair each Polish run with the nearest English run to its right that overlaps it vertically.
            var usedRuns = Set<Int>()
            let polishRuns = runs.indices.filter { runs[$0].indices.count >= 3 && share(runs[$0], .polish, segs) >= 0.6 }
                .sorted { runs[$0].minX < runs[$1].minX }
            for p in polishRuns {
                let P = runs[p]
                var best: Int?
                for e in runs.indices where e != p && !usedRuns.contains(e) {
                    let E = runs[e]
                    guard E.minX > P.minX, E.indices.count >= 3, share(E, .english, segs) >= 0.6 else { continue }
                    let overlap = min(P.bottom, E.bottom) - max(P.top, E.top)
                    let smaller = min(P.bottom - P.top, E.bottom - E.top)
                    guard smaller > 0, overlap / smaller >= 0.5 else { continue }
                    if best == nil || E.minX < runs[best!].minX { best = e }
                }
                guard let e = best else { continue }
                usedRuns.insert(p)
                usedRuns.insert(e)

                let polishRows = P.indices.sorted { segs[$0].midY < segs[$1].midY }
                let pitch = polishRows.count > 1
                    ? median(zip(polishRows, polishRows.dropFirst()).map { segs[$1].midY - segs[$0].midY })
                    : 2 * medianHeight
                var answers: [Int: [(CGFloat, String)]] = [:]
                for j in runs[e].indices {
                    let s = segs[j]
                    guard let row = polishRows.min(by: { abs(segs[$0].midY - s.midY) < abs(segs[$1].midY - s.midY) }) else { continue }
                    if abs(segs[row].midY - s.midY) < 0.6 * pitch {
                        answers[row, default: []].append((s.midY, s.text))
                        used.insert(j)
                    }
                }
                for row in polishRows {
                    guard let lines = answers[row] else { continue }
                    let english = lines.sorted { $0.0 < $1.0 }.map { $0.1 }.joined(separator: " ")
                    result.tablePairs.append(Pair(polish: segs[row].text, english: english, source: "table, page \(page + 1)"))
                    used.insert(row)
                }
            }
        }

        // ---------- Leftovers ----------
        result.leftovers = segs.indices
            .filter { !used.contains($0) && !headings.contains($0) && Self.hasLetter(segs[$0].text) }
            .map { segs[$0] }
            .sorted { ($0.page, $0.midY, $0.minX) < ($1.page, $1.midY, $1.minX) }

        return result
    }

    // MARK: - Helpers

    private func makeRun(_ indices: [Int], _ segs: [Segment]) -> Run {
        Run(indices: indices,
            minX: indices.map { segs[$0].rect.minX }.min() ?? 0,
            top: indices.map { segs[$0].rect.minY }.min() ?? 0,
            bottom: indices.map { segs[$0].rect.maxY }.max() ?? 0,
            page: indices.first.map { segs[$0].page } ?? 0)
    }

    private func share(_ run: Run, _ lang: Lang, _ segs: [Segment]) -> Double {
        guard !run.indices.isEmpty else { return 0 }
        let n = run.indices.filter { segs[$0].lang == lang }.count
        return Double(n) / Double(run.indices.count)
    }

    private static func hasLetter(_ s: String) -> Bool {
        s.contains { $0.isLetter }
    }

    private static func stripLeadingNumber(_ s: String) -> String {
        let ns = s as NSString
        return leadingNumberRe.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: ns.length), withTemplate: "")
    }

    /// Returns the capture groups of the first match, or nil.
    private static func match(_ re: NSRegularExpression, _ s: String) -> [String]? {
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (1..<m.numberOfRanges).map {
            let r = m.range(at: $0)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }
}
