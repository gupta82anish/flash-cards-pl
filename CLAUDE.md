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
  - Pairing uses rules based on the page layout, not AI. **A.G. picks the page type (Table / Numbered / Auto) before scanning** so the analyzer runs only the relevant layout instead of guessing; "Auto" (both layouts) stays available for a page that mixes a table and an exercise.
  - SwiftData for storage, FSRS for scheduling, `AVSpeechSynthesizer` pl-PL for audio (later phases)
- **DeepSeek** (text-only chat API) is an optional *later* fallback for messy pages. We considered and dropped DeepSeek-OCR and DeepSeek vision. No Claude API.
- A.G. prefers direct recommendations and concise, exact answers.

## The book's two layouts (see `samples/`)
**Layout A — vocabulary tables** (`samples/vocabulary-tables.jpg`)
- No grid lines. Shaded two-column blocks (bold Polish on the left, English on the right), often **three blocks side by side**.
- English sometimes wraps onto two lines, with the Polish word vertically centred between them (mieszkać → "to live (somewhere)", studiować → "to study (at university)", zaczynać → "to start, to begin").
- Reflexive verbs: "spieszyć się" is one entry. Commas mark alternatives: "to do, to make".
- Page title such as "1. Useful Verbs. Part 1" (large type): **we no longer surface a deck title** (A.G. doesn't want one). The title line is still set aside as a "heading" so it can't be mispaired, and must never count as numbered item 1.
- Grammar tables (my (we) | -my) must be rejected: the right column is not English.

**Layout B — numbered exercises** (`samples/numbered-exercise-spread.jpg`, photo is rotated 90°)
- English sentences 1–15 on the left page (with blank lines for writing), Polish answers 1–15 on the facing page. Pair them by number.
- Multi-line items: in English item 11 the number sits beside the **second** line, with one line above and one below. Continuation lines go to the nearest number.
- Ignore: grey margin note boxes (circled numbers with no period, and they contain Polish words), handwriting on the dotted lines, headers and footers.
- A single page can hold a vocabulary table on top and half of an exercise below.

## Code map (`PolishPairs/`)
| File | Role |
| --- | --- |
| `TextRecognizer.swift` | OCR. Normalizes image orientation, then picks the page orientation whose text boxes are mostly **horizontal** (upright Latin lines are wider than tall; sideways ≈ taller than wide), using confidence only to break up-vs-upside-down ties. Splits lines at word gaps wider than 1.2× the line height (merged table cells). See the orientation note under Status |
| `LanguageTagger.swift` | Polish / English / unknown |
| `Analyzer.swift` | Pairing. Takes a `ScanMode` (`.auto`/`.table`/`.numbered`) and runs only the matching layout(s). Layout B: number markers → lists grouped by x → continuation lines → pair lists by number overlap (the number is the pairing key). Layout A: remaining segments → columns by left edge (gap 0.04) → vertical runs (split at gaps over 4× median height) → Polish run + nearest English run to its right with ≥50% vertical overlap → **union-find cell builder**: (R1) mutual-nearest links each line to the nearest opposite-column line within 0.75× row pitch; (R2a) an orphan line joins its nearest same-column neighbour within 0.8× pitch; (R2b) two adjacent cells merge when one entry wrapped on **both** sides — detected as a *local-minimum* gap (tighter than the neighbouring entry gaps) with the matched English also tight. Handles multi-line on either or both sides |
| `ReportBuilder.swift` | Plain-text report (page type, pairs, problems, unpaired text, raw lines with coordinates) that A.G. pastes back for tuning |
| `ContentView.swift` | Test screen: Polish-support check, **page-type picker (Auto/Table/Numbered)**, Scan, Choose photos, language-correction toggle, Copy results |
| `samples/mirror.py`, `synth.py` | Python mirror of `Analyzer.swift` plus synthetic tests from both photos (28/28 table pairs, 15/15 numbered pairs). Keep them in sync if the rules change |

Coordinates are normalized with a **top-left** origin (Vision's bottom-left origin is converted in `TextRecognizer.topLeft`).

## Status (updated 2026-09-25)
- **It builds.** `xcodebuild -project PolishPairs.xcodeproj -target PolishPairs -sdk iphonesimulator build` → **BUILD SUCCEEDED** on the hand-written `project.pbxproj` (objectVersion 77, synchronized folder, no shared scheme), Xcode 27 / iOS 17 target. No source changes were needed to compile.
- **On-device only, no keys.** Confirmed no network calls, API keys, or secrets in the app. `NSCameraUsageDescription` is set in the project. DeepSeek (later fallback) is the only thing that would ever need a key and isn't wired in.
- **First real Vision test surfaced (and we fixed) a rotation bug.** A.G. scanned `samples/vocabulary-tables.jpg` (Layout A) and got **0 pairs, 35 unpaired**. Cause: the scan came in rotated 90°. Vision reads rotated text correctly (it auto-detects each line's direction), so **confidence stays high on a sideways page and can't reveal the rotation** — but the bounding boxes come back in the rotated frame, so Polish columns became horizontal bands and English landed *below* Polish instead of to its right, and `Analyzer`'s Layout A found nothing. Fix: `TextRecognizer` now selects orientation by **box aspect ratio** (measured ~3.8 w/h upright vs ~0.25 sideways on this page), not confidence alone. `Analyzer.swift` and the Python mirror were already correct for upright input and were left unchanged.
- **Verified end-to-end.** Ran the real upright Vision output (via a macOS `swift` harness calling `VNRecognizeTextRequest`) through `samples/mirror.py`: **28/28 table pairs**, all three blocks, multi-line English handled (`to live (somewhere)`, `to be sorry, to apologise`, `to study (at university)`), reflexives handled (`spieszyć się → to be in a hurry`). The only leftovers were the "Keep Polish…" margin note (correctly ignored).
- **Second real Vision test (Layout B, single cropped page) surfaced two bugs, both now fixed.** A.G. scanned the phrases half of an exercise page (English col left, Polish col right, one page, "orientation: right" = slightly skewed) and got **0 table + 11/15 numbered, with #1/#2/#3/#5 English "not found" and a bogus deck title** ("They watch Netflix every day."). Causes and fixes (in `Analyzer.swift` + the Python mirror, kept in sync):
  1. *Heading over-detection.* The four tallest English lines exceeded the `1.6 × median height` heading threshold (median ≈0.030 → cutoff ≈0.048; those lines were 0.058–0.065, likely the sentence merged with the writing line beneath) and were excluded from all pairing; the title then grabbed the tallest of them. **Fix:** numbered-list membership is now decided *before* heading classification — a segment that belongs to a real (≥3-item) numbered list is never a heading. A lone title still can't masquerade as item 1 because it never joins a ≥3 list. Markers are now detected over *all* segments; only kept-list markers are marked `used`.
  2. *Skew stranded the top items.* The left text column drifts in x down a skewed page (0.049 at top → 0.081 at bottom), so the `±0.025` continuation band missed #1/#5. **Fix:** a bare marker ("1.") now claims the text on its own row to the right directly (per-row), independent of the column band. Also added a `height < 0.5 × median` guard so footer/page-number bleed (e.g. "Dublichina nl") isn't swept into the last card.
  - Result on that page: **15/15 pairs, footer left unpaired.** `samples/synth.py` still passes **28/28 table + 15/15 numbered**; `samples/repro_report.py` replays this exact device report through the mirror.
  - **Third test (numbered page, items 16–36) exposed a phantom-problems bug, now fixed.** All 21 pairs came out right, but the report listed 15 problems ("#1–#15 missing on both pages") because the pairing loop walked `1…max`. It now walks `min…max` of the numbers actually present (exercises don't start at 1), so a "missing on both pages" only flags a real interior gap. Fixture: `samples/repro_report2.py` (asserts 21 pairs / 0 problems).
  - **Table test (3 blocks, gendered Polish forms) exposed the mirror of the multi-line bug, now fixed.** 24 pairs came out but 8 lines were orphaned: cells where the **Polish** side has two lines (masculine/feminine, e.g. `wolny (m.),` / `wolna (f.)`) sharing **one** English word (`single`) — Layout A only handled multi-line *English*. Fix: Layout A line-pairing is now symmetric — a **mutual-nearest union-find** (within `0.75× row pitch`) builds cells that can be multi-line on either side. Now `wolny (m.), wolna (f.) — single`, `żonaty (m.), zamężna (f.) — married`, `nazwisko panieńskie — maiden name`, `kolega (m.), koleżanka (f.) — friend`, `Wszystke — Everything's fine.` all merge; leftovers dropped 8→2 (the two remaining are genuinely fragmented/garbled OCR). Band tuned to 0.75× to avoid fabricating a *wrong* card (at 1.0× a drifting line merged into the neighbouring entry). Fixture: `samples/repro_table.py` — note it carries the real per-line device tags, since `pair.lang` is only a stub; `mirror.analyze` now respects a pre-set `lang`.
  - **Second table test (orientation up) drove two more Layout A passes.** A single entry that wraps on **both** sides (`Wszystko`/`w porządku.` ↔ `Everything's`/`fine.`) came out as two cards, and a 3-line Polish cell (`rozwiedziony`/`(m.),`/`rozwiedziona (f.)` ↔ `divorced`) orphaned its last line. Added **R2a** (orphan lines join their nearest same-column neighbour) and **R2b** (merge two adjacent cells when the gap is a *local minimum* — tighter than the neighbours — with the matched English also tight, so a real wrap is distinguished from two tightly-stacked separate entries like `narzeczony`/`narzeczona` = fiancé/fiancée). Result on that page: all correct, 24 pairs, 0 leftovers, incl. `przyjaciel (m.), przyjaciółka (f.) — close/dear friend`. **Known limit:** the wrap-vs-two-entries call is not perfectly separable geometrically — on a messy scan two tightly-spaced distinct entries can still over-merge (in `repro_table.py`, `urodziny rodzinne miasto — birthday hometown`). A future manual merge/split in the review screen is the real fix. Fixture: `samples/repro_table2.py`.
  - **Deck title dropped entirely afterward** (A.G. doesn't want one): removed `AnalysisResult.title`, the "Deck title" UI section, and the report line. The `headings` set (tall lines that aren't numbered-list members) is kept only to shield a large title from Layout A mispairing — it no longer produces any text.
- **Still open (tuning, not structural):**
  - OCR dropped some final diacritics with Language correction **off** (`to walt`, `mówic`/`słuchac`/`płacic` missing `ć`, `spozniać sięr`; this page also shows `ogladaja`/`ogladamy` missing `ą`). Try Language correction on and compare.
  - The numbered-exercise *spread* sample (rotated 90° per the notes) hasn't been re-tested on-device since the orientation fix, but should now benefit from it.
- **Python mirror now runs out of the box:** added `samples/seg.py` (a stub `segments(path)` so `pair.py`'s top-level `from seg import segments` resolves). `mirror.py` only needs `pair.lang`. The Swift↔Python mirror matches.

## Next steps, in order
1. ~~Make it build.~~ **Done** — builds clean, no changes needed.
2. Help A.G. sign the app (Personal Team; change the bundle ID `pl.ag.polishpairs.test` if it's taken) and run it on the iPhone.
3. Confirm `pl-PL` appears in `supportedRecognitionLanguages()` on the device — the pasted report already shows `pl-PL` present on A.G.'s phone. If it's ever missing, the fallback is Google ML Kit text recognition (Latin script).
4. Re-scan on-device with the orientation fix: 5 table pages and 5 exercises, share the reports. Then tune `Analyzer.swift` thresholds and the title cutoff; try Language correction on for diacritics; target ≥95% of pairs correct, diacritics included.
5. Then the roadmap: Phase 1, scan → review screen (edit, merge, delete, manual pairing) → decks in SwiftData. Phase 2, flashcards (Polish→English and English→Polish), FSRS, pl-PL audio. Phase 3, duplicate detection, stats, TestFlight. Phase 4, DeepSeek text fallback, typing and listening modes, Anki/CSV export.
