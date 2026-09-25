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

    func analyze(_ input: [Segment], mode: ScanMode = .auto) -> AnalysisResult {
        var segs = input.filter { Self.hasLetter($0.text) || Self.match(Self.markerRe, $0.text) != nil }
        for i in segs.indices { segs[i].lang = tag(segs[i].text) }

        var result = AnalysisResult()
        result.mode = mode
        result.segments = segs
        guard !segs.isEmpty else {
            result.problems.append("No text found.")
            return result
        }

        let medianHeight = median(segs.map { $0.height })
        let pages = Array(Set(segs.map { $0.page })).sorted()
        var used = Set<Int>()
        var members = Set<Int>()   // segments that belong to a real (≥3) numbered list
        var numbered: [NumberedList] = []

        // ---------- Layout B: numbered lists ----------
        if mode.runsNumbered {
        // Detect markers over ALL segments (headings are not excluded yet). A lone
        // tall title can match the inline pattern, but it survives only if it joins
        // a list of ≥3, so it can never masquerade as numbered item 1.
        var markers: [Marker] = []
        for (i, s) in segs.enumerated() {
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
        let markerIndices = Set(markers.map { $0.segIndex })

        // A marker on its own ("11.") takes the text start from the nearest segment to its right.
        for m in markers where m.textX == nil {
            var best: (CGFloat, Int)?
            for (j, s) in segs.enumerated() where !markerIndices.contains(j) && s.page == m.page {
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

        for var list in lists where list.count >= 3 {
            for m in list { used.insert(m.segIndex); members.insert(m.segIndex) }
            list.sort { $0.y < $1.y }
            let textX = median(list.compactMap { $0.textX })
            let pitch = median(zip(list, list.dropFirst()).map { $1.y - $0.y })
            let low = list[0].y - pitch
            let high = list[list.count - 1].y + pitch
            let page = list[0].page

            // A bare marker ("1.") claims the text on its own row to the right. Done
            // per-row so a skewed page (its text column drifting in x) can't strand
            // the topmost items the way the column band below would.
            for m in list where m.lines.isEmpty {
                var best: (CGFloat, Int)?
                for (j, s) in segs.enumerated() where !used.contains(j) && s.page == page {
                    guard s.rect.minX > m.x, s.rect.minX - m.segMaxX < 0.15, abs(s.midY - m.y) < 1.5 * m.h else { continue }
                    let d = abs(s.midY - m.y)
                    if best == nil || d < best!.0 { best = (d, j) }
                }
                if let b = best {
                    m.lines.append((segs[b.1].midY, segs[b.1].text))
                    used.insert(b.1); members.insert(b.1)
                }
            }

            // Remaining unnumbered lines aligned with the text column belong to the nearest
            // numbered item (a continuation can sit above or below the number).
            for (j, s) in segs.enumerated() where !used.contains(j) && s.page == page {
                if s.height < 0.5 * medianHeight { continue }   // footer / page-number bleed, not a real line
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
        } // mode.runsNumbered

        // Headings = tall lines that are NOT part of a numbered list (a large page
        // title, not an inflated body item). We don't surface a deck title, but we
        // still set these aside so a big title can't be mispaired in Layout A.
        let headings = Set(segs.indices.filter { segs[$0].height > 1.6 * medianHeight && !members.contains($0) })

        if mode.runsNumbered {
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
            // Iterate only across the range this page actually covers (the book's
            // exercises don't start at 1), so a "missing on both" is a real interior
            // gap, not a number that was never on the page.
            let numbers = Set(english.keys).union(polish.keys)
            guard let lo = numbers.min(), let hi = numbers.max() else { continue }
            for n in lo...hi {
                switch (polish[n], english[n]) {
                case let (p?, en?):
                    result.numberedPairs.append(Pair(polish: p, english: en, source: "#\(n)"))
                case (nil, _?):
                    result.problems.append("#\(n): Polish item not found")
                case (_?, nil):
                    result.problems.append("#\(n): English item not found")
                default:
                    result.problems.append("#\(n): missing on both pages (OCR may have dropped it)")
                }
            }
        }
        for p in numbered.indices where numbered[p].lang == .polish && !usedPolishLists.contains(p) {
            result.problems.append("Numbered Polish list on page \(numbered[p].page + 1) has no matching English list.")
        }
        for l in numbered where l.lang == .unknown {
            result.problems.append("A numbered list on page \(l.page + 1) could not be identified as Polish or English.")
        }
        } // mode.runsNumbered

        // ---------- Layout A: vocabulary tables ----------
        if mode.runsTable {
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
                let englishLines = runs[e].indices.sorted { segs[$0].midY < segs[$1].midY }
                let pitch = polishRows.count > 1
                    ? median(zip(polishRows, polishRows.dropFirst()).map { segs[$1].midY - segs[$0].midY })
                    : 2 * medianHeight
                let band = 0.75 * pitch     // a line links to the nearest opposite-column line within this
                let mergeT = 0.8 * pitch    // wrapped/gendered lines are tighter than the entry pitch
                func mid(_ k: Int) -> CGFloat { segs[k].midY }

                // Union-find over Polish rows and English lines (segment indices are unique, so
                // they share one parent map).
                var parent: [Int: Int] = [:]
                for j in polishRows + englishLines { parent[j] = j }
                func find(_ x: Int) -> Int {
                    var r = x
                    while parent[r]! != r { r = parent[r]! }
                    var c = x
                    while parent[c]! != r { let n = parent[c]!; parent[c] = r; c = n }
                    return r
                }
                func union(_ a: Int, _ b: Int) {
                    let ra = find(a), rb = find(b)
                    if ra != rb { parent[ra] = rb }
                }
                // Nearest opposite-column line for each line (regardless of distance).
                let nearE = Dictionary(uniqueKeysWithValues: polishRows.map { r in
                    (r, englishLines.min(by: { abs(mid($0) - mid(r)) < abs(mid($1) - mid(r)) })) })
                let nearP = Dictionary(uniqueKeysWithValues: englishLines.map { e in
                    (e, polishRows.min(by: { abs(mid($0) - mid(e)) < abs(mid($1) - mid(e)) })) })
                // R1: mutual-nearest cross-link within `band` (2 English for 1 Polish, or vice versa).
                var crossed = Set<Int>()
                for e in englishLines {
                    if let r = nearP[e] ?? nil, abs(mid(r) - mid(e)) < band { union(e, r); crossed.insert(e); crossed.insert(r) }
                }
                for r in polishRows {
                    if let e = nearE[r] ?? nil, abs(mid(e) - mid(r)) < band { union(r, e); crossed.insert(r); crossed.insert(e) }
                }
                // R2a: an orphan line (no cross-link) joins its nearest same-column neighbour.
                for seq in [polishRows, englishLines] {
                    for i in seq.indices where !crossed.contains(seq[i]) {
                        let nb = [i - 1, i + 1].filter { seq.indices.contains($0) }.map { seq[$0] }
                        if let o = nb.min(by: { abs(mid($0) - mid(seq[i])) < abs(mid($1) - mid(seq[i])) }),
                           abs(mid(o) - mid(seq[i])) < mergeT { union(seq[i], o) }
                    }
                }
                // R2b: merge two adjacent cells that are ONE entry wrapped in both columns
                // (e.g. "Wszystko"/"w porządku." <-> "Everything's"/"fine."). A wrap gap is a
                // LOCAL MINIMUM — tighter on both sides than the neighbouring entry gaps — which
                // tells it apart from two separate but tightly-spaced entries (fiancé/fiancée).
                // Conservative at the column edges.
                if polishRows.count >= 2 {
                    for i in 0..<(polishRows.count - 1) where i - 1 >= 0 && i + 2 < polishRows.count {
                        let a = polishRows[i], b = polishRows[i + 1]
                        let g = mid(b) - mid(a)
                        guard g < mergeT, g < mid(a) - mid(polishRows[i - 1]), g < mid(polishRows[i + 2]) - mid(b) else { continue }
                        if let ea = nearE[a] ?? nil, let eb = nearE[b] ?? nil, ea != eb, abs(mid(ea) - mid(eb)) < mergeT {
                            union(a, b)
                        }
                    }
                }
                let polishSet = Set(polishRows)
                var comps: [Int: [Int]] = [:]
                for j in polishRows + englishLines { comps[find(j), default: []].append(j) }
                var cards: [(CGFloat, String, String)] = []
                for members in comps.values {
                    let pls = members.filter { polishSet.contains($0) }.sorted { segs[$0].midY < segs[$1].midY }
                    let ens = members.filter { !polishSet.contains($0) }.sorted { segs[$0].midY < segs[$1].midY }
                    guard let first = pls.first, !ens.isEmpty else { continue }
                    cards.append((segs[first].midY,
                                  pls.map { segs[$0].text }.joined(separator: " "),
                                  ens.map { segs[$0].text }.joined(separator: " ")))
                    for k in pls + ens { used.insert(k) }
                }
                for card in cards.sorted(by: { $0.0 < $1.0 }) {
                    result.tablePairs.append(Pair(polish: card.1, english: card.2, source: "table, page \(page + 1)"))
                }
            }
        }
        } // mode.runsTable

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
