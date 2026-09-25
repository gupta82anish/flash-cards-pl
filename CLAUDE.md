# Polish Pairs — handoff notes for Claude Code

## What this is
A personal iPhone app for A.G., who is learning Polish from the textbook **Speak Polish (Preston Publishing)**. A.G. photographs a page, the app pulls out the Polish–English pairs the book already prints (**no translation needed**), and turns them into spaced-repetition flashcards.

Full plan (living doc): https://claude.ai/code/artifact/842464ca-7cfe-48dd-a27b-03860a2a8dcf

## Decisions already made
- **Native SwiftUI, iPhone only**, deployment target iOS 17 (A.G.'s phone runs iOS 26). No Android.
- **Everything on-device, no server, no running cost:**
  - VisionKit `VNDocumentCameraViewController` for capture (edge detection, flattening)
  - Vision `VNRecognizeTextRequest` (revision 3, `.accurate`, languages `pl-PL` + `en-US`) for OCR
  - NaturalLanguage `NLLanguageRecognizer` (limited to Polish and English) for tagging, plus rules: Polish diacritics → Polish; text starting with "to " → English
  - Pairing uses rules based on the page layout, not AI
  - SwiftData for storage, FSRS for scheduling, `AVSpeechSynthesizer` pl-PL for audio (later phases)
- **DeepSeek** (text-only chat API) is an optional *later* fallback for messy pages. We considered and dropped DeepSeek-OCR and DeepSeek vision. No Claude API.
- A.G. prefers direct recommendations and concise, exact answers.

## The book's two layouts (see `samples/`)
**Layout A — vocabulary tables** (`samples/vocabulary-tables.jpg`)
- No grid lines. Shaded two-column blocks (bold Polish on the left, English on the right), often **three blocks side by side**.
- English sometimes wraps onto two lines, with the Polish word vertically centred between them (mieszkać → "to live (somewhere)", studiować → "to study (at university)", zaczynać → "to start, to begin").
- Reflexive verbs: "spieszyć się" is one entry. Commas mark alternatives: "to do, to make".
- Page title such as "1. Useful Verbs. Part 1" (large type): use it as the deck name. It must never count as numbered item 1.
- Grammar tables (my (we) | -my) must be rejected: the right column is not English.

**Layout B — numbered exercises** (`samples/numbered-exercise-spread.jpg`, photo is rotated 90°)
- English sentences 1–15 on the left page (with blank lines for writing), Polish answers 1–15 on the facing page. Pair them by number.
- Multi-line items: in English item 11 the number sits beside the **second** line, with one line above and one below. Continuation lines go to the nearest number.
- Ignore: grey margin note boxes (circled numbers with no period, and they contain Polish words), handwriting on the dotted lines, headers and footers.
- A single page can hold a vocabulary table on top and half of an exercise below.

## Code map (`PolishPairs/`)
| File | Role |
| --- | --- |
| `TextRecognizer.swift` | OCR. Normalizes image orientation, tries up/right/left/down if confidence is low, splits lines at word gaps wider than 1.2× the line height (merged table cells) |
| `LanguageTagger.swift` | Polish / English / unknown |
| `Analyzer.swift` | Pairing. Layout B: number markers → lists grouped by x → continuation lines → pair lists by number overlap. Layout A: remaining segments → columns by left edge (gap 0.04) → vertical runs (split at gaps over 4× median height) → Polish run + nearest English run to its right with ≥50% vertical overlap → each English line goes to the Polish row nearest in height (within 0.6× row pitch) |
| `ReportBuilder.swift` | Plain-text report (pairs, problems, unpaired text, raw lines with coordinates) that A.G. pastes back for tuning |
| `ContentView.swift` | Test screen: Polish-support check, Scan, Choose photos, language-correction toggle, Copy results |
| `samples/mirror.py`, `synth.py` | Python mirror of `Analyzer.swift` plus synthetic tests from both photos (28/28 table pairs, 15/15 numbered pairs). Keep them in sync if the rules change |

Coordinates are normalized with a **top-left** origin (Vision's bottom-left origin is converted in `TextRecognizer.topLeft`).

## Status
- Phase 0 test app has been written but **never compiled**: it was written in a Linux sandbox with no Xcode. `project.pbxproj` is hand-written (objectVersion 77, a synchronized folder, no shared scheme).
- The pairing logic passed synthetic tests only. It hasn't been tested on real Vision output yet.

## Next steps, in order
1. **Make it build:** `xcodebuild -project PolishPairs.xcodeproj -target PolishPairs -sdk iphonesimulator build`. Fix errors. If the hand-written project file is the problem, recreate the project in Xcode and keep the sources.
2. Help A.G. sign the app (Personal Team; change the bundle ID `pl.ag.polishpairs.test` if it's taken) and run it on the iPhone.
3. Confirm `pl-PL` appears in `supportedRecognitionLanguages()` on the device. If it's missing, the fallback is Google ML Kit text recognition (Latin script).
4. A.G. scans 5 table pages and 5 exercises and shares the reports. Tune `Analyzer.swift` thresholds; target ≥95% of pairs correct, diacritics included.
5. Then the roadmap: Phase 1, scan → review screen (edit, merge, delete, manual pairing) → decks in SwiftData. Phase 2, flashcards (Polish→English and English→Polish), FSRS, pl-PL audio. Phase 3, duplicate detection, stats, TestFlight. Phase 4, DeepSeek text fallback, typing and listening modes, Anki/CSV export.
