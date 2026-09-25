import Foundation

/// Plain-text report to paste back into the chat for tuning.
enum ReportBuilder {
    static func build(_ r: AnalysisResult, supportedLanguages: [String], languageCorrection: Bool) -> String {
        var out: [String] = []
        let polish = supportedLanguages.contains { $0.lowercased().hasPrefix("pl") }
        out.append("POLISH PAIRS TEST REPORT")
        out.append("Polish recognition: \(polish ? "yes" : "NO")")
        out.append("Supported languages: \(supportedLanguages.joined(separator: ", "))")
        out.append("Language correction: \(languageCorrection ? "on" : "off")")
        out.append("Pages: \(r.orientations.count) (orientation: \(r.orientations.joined(separator: ", ")))")
        out.append("Deck title: \(r.title ?? "-")")
        out.append("")

        out.append("TABLE PAIRS (\(r.tablePairs.count))")
        for p in r.tablePairs { out.append("\(p.polish) — \(p.english)") }
        out.append("")

        out.append("NUMBERED PAIRS (\(r.numberedPairs.count))")
        for p in r.numberedPairs { out.append("\(p.source) \(p.polish) — \(p.english)") }
        out.append("")

        out.append("PROBLEMS (\(r.problems.count))")
        out.append(contentsOf: r.problems)
        out.append("")

        out.append("UNPAIRED (\(r.leftovers.count))")
        for s in r.leftovers { out.append("p\(s.page + 1): \(s.text)") }
        out.append("")

        out.append("RAW LINES")
        let sorted = r.segments.sorted { ($0.page, $0.midY, $0.minX) < ($1.page, $1.midY, $1.minX) }
        for s in sorted {
            out.append(String(format: "p%d x=%.3f y=%.3f h=%.3f c=%.2f [%@] ",
                              s.page + 1, Double(s.rect.minX), Double(s.midY), Double(s.height),
                              Double(s.confidence), s.lang.rawValue) + s.text)
        }
        return out.joined(separator: "\n")
    }
}
