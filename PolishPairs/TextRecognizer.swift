import Foundation
import UIKit
import Vision

enum TextRecognizer {

    /// Languages Vision's accurate text recognition supports on this device.
    static func supportedLanguages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.revision = VNRecognizeTextRequestRevision3
        return (try? request.supportedRecognitionLanguages()) ?? []
    }

    /// Reads one page. Tries the upright orientation first, and the other three
    /// if the text looks sideways or upside down.
    ///
    /// Vision reads rotated text correctly (it detects each line's direction), so
    /// confidence alone stays high on a sideways page and can't reveal the rotation —
    /// but the bounding boxes come back in the rotated frame, which breaks pairing.
    /// The reliable signal is box shape: upright Latin text lines are wider than tall,
    /// sideways ones are taller than wide. We pick the orientation whose boxes are
    /// predominantly horizontal, using confidence only to tell up from upside-down.
    static func recognize(image: UIImage, page: Int, languageCorrection: Bool) -> (segments: [Segment], orientation: String) {
        guard let cgImage = normalized(image) else { return ([], "unreadable") }

        let first = run(cgImage, orientation: .up, page: page, languageCorrection: languageCorrection)
        if first.meanConfidence >= 0.6 && first.characters >= 40 && first.horizontalFraction >= 0.5 {
            return (first.segments, "up")
        }

        var best = (first, "up")
        let others: [(CGImagePropertyOrientation, String)] = [(.right, "right"), (.left, "left"), (.down, "down")]
        for (orientation, name) in others {
            let attempt = run(cgImage, orientation: orientation, page: page, languageCorrection: languageCorrection)
            if attempt.selectionScore > best.0.selectionScore { best = (attempt, name) }
        }
        return (best.0.segments, best.1)
    }

    // MARK: - Private

    private struct Attempt {
        var segments: [Segment]
        var characters: Int
        var meanConfidence: Float
        var score: Float
        /// Fraction of multi-character lines whose box is wider than tall (upright text ≈ 1, sideways ≈ 0).
        var horizontalFraction: Float
        /// Prefers an upright page (horizontal boxes), then higher confidence to break up-vs-down ties.
        var selectionScore: Float { horizontalFraction * 2 + meanConfidence }
    }

    private static func run(_ cgImage: CGImage, orientation: CGImagePropertyOrientation, page: Int, languageCorrection: Bool) -> Attempt {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLanguages = ["pl-PL", "en-US"]
        request.usesLanguageCorrection = languageCorrection

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return Attempt(segments: [], characters: 0, meanConfidence: 0, score: 0, horizontalFraction: 0)
        }

        var segments: [Segment] = []
        var characters = 0
        var confidenceSum: Float = 0
        var score: Float = 0
        let observations = request.results ?? []

        // Box aspect is measured in pixels; a right/left rotation swaps the frame's width and height.
        let swaps = (orientation == .right || orientation == .left)
        let frameW = CGFloat(swaps ? cgImage.height : cgImage.width)
        let frameH = CGFloat(swaps ? cgImage.width : cgImage.height)
        var shapedLines = 0
        var wideLines = 0

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let count = candidate.string.count
            characters += count
            confidenceSum += candidate.confidence
            score += Float(count) * candidate.confidence
            if count >= 3 {
                shapedLines += 1
                let box = observation.boundingBox
                if box.width * frameW > box.height * frameH { wideLines += 1 }
            }
            segments += split(candidate: candidate, observation: observation, page: page)
        }

        let mean = observations.isEmpty ? 0 : confidenceSum / Float(observations.count)
        let horizontal = shapedLines == 0 ? 0 : Float(wideLines) / Float(shapedLines)
        return Attempt(segments: segments, characters: characters,
                       meanConfidence: mean, score: score, horizontalFraction: horizontal)
    }

    /// Vision sometimes returns two table cells as one line ("być   to be").
    /// Split a line wherever the horizontal gap between words is wider than 1.2 × the line height.
    private static func split(candidate: VNRecognizedText, observation: VNRecognizedTextObservation, page: Int) -> [Segment] {
        let text = candidate.string
        let lineRect = topLeft(observation.boundingBox)
        let tokens = tokenRanges(text)
        guard tokens.count > 1 else {
            return [Segment(text: text, rect: lineRect, confidence: candidate.confidence, page: page)]
        }

        var boxes: [(Range<String.Index>, CGRect)] = []
        for range in tokens {
            if let box = try? candidate.boundingBox(for: range)?.boundingBox {
                boxes.append((range, topLeft(box)))
            } else {
                return [Segment(text: text, rect: lineRect, confidence: candidate.confidence, page: page)]
            }
        }

        let gapLimit = 1.2 * lineRect.height
        var groups: [[(Range<String.Index>, CGRect)]] = [[boxes[0]]]
        for item in boxes.dropFirst() {
            let previous = groups[groups.count - 1].last!
            if item.1.minX - previous.1.maxX > gapLimit {
                groups.append([item])
            } else {
                groups[groups.count - 1].append(item)
            }
        }

        return groups.map { group in
            let start = group.first!.0.lowerBound
            let end = group.last!.0.upperBound
            let rect = group.dropFirst().reduce(group.first!.1) { $0.union($1.1) }
            return Segment(text: String(text[start..<end]), rect: rect, confidence: candidate.confidence, page: page)
        }
    }

    private static func tokenRanges(_ s: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var start: String.Index?
        var i = s.startIndex
        while i < s.endIndex {
            if s[i].isWhitespace {
                if let st = start { result.append(st..<i); start = nil }
            } else if start == nil {
                start = i
            }
            i = s.index(after: i)
        }
        if let st = start { result.append(st..<s.endIndex) }
        return result
    }

    /// Vision uses a bottom-left origin; convert to top-left.
    private static func topLeft(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: 1 - r.maxY, width: r.width, height: r.height)
    }

    /// Redraws the image upright (applies EXIF orientation) and caps the long side at 3000 px.
    private static func normalized(_ image: UIImage, maxSide: CGFloat = 3000) -> CGImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.cgImage
    }
}
