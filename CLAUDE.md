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
| `TextRecognizer.swift` | OCR. Normalizes image orientation, then picks the page orientation whose text boxes are mostly **horizontal** (upright Latin lines are wider than tall; sideways ≈ taller than wide), using confidence only to break up-vs-upside-down ties. Splits lines at word gaps wider than 1.2× the line height (merged table cells). **Can't distinguish upright from 180° when confidence is flat — see Known limitations** |
| `LanguageTagger.swift` | Polish / English / unknown |
| `Analyzer.swift` | Pairing. Takes a `ScanMode` (`.auto`/`.table`/`.numbered`) and runs only the matching layout(s). Layout B: number markers → lists grouped by x → continuation lines → pair lists by number overlap (the number is the pairing key). Layout A: remaining segments → columns by left edge (gap 0.04) → vertical runs (split at gaps over 4× median height) → Polish run + nearest English run to its right with ≥50% vertical overlap → **union-find cell builder**: (R1) mutual-nearest links each line to the nearest opposite-column line within 0.75× row pitch; (R2a) an orphan line joins its nearest same-column neighbour within 0.8× pitch; (R2b) two adjacent cells merge when one entry wrapped on **both** sides — detected as a *local-minimum* gap (tighter than the neighbouring entry gaps) with the matched English also tight. Handles multi-line on either or both sides |
| `ReportBuilder.swift` | Plain-text report (page type, pairs, problems, unpaired text, raw lines with coordinates) that A.G. pastes back for tuning |
| `ContentView.swift` | Test screen: Polish-support check, **page-type picker (Auto/Table/Numbered)**, Scan, Choose photos, language-correction toggle, Copy results |
| `samples/mirror.py` | Line-by-line Python mirror of `Analyzer.swift`, for fast logic iteration. **Keep it in sync with `Analyzer.swift` whenever the pairing rules change.** Uses `pair.lang` (a *stub* tagger — weak on English), so table fixtures pass real per-line `[pl]`/`[en]` device tags instead; `mirror.analyze` respects a pre-set `lang`. |
| `samples/seg.py` | Stub so `pair.py`'s top-level `from seg import segments` resolves (the mirror only needs `pair.lang`). |
| `samples/*.py` fixtures | Regression tests — run them all after any Analyzer change (see **How to verify**). |

Coordinates are normalized with a **top-left** origin (Vision's bottom-left origin is converted in `TextRecognizer.topLeft`).

## Current state (updated 2026-09-25)
- **Builds clean.** `xcodebuild -project PolishPairs.xcodeproj -target PolishPairs -sdk iphonesimulator build` → **BUILD SUCCEEDED** (hand-written `project.pbxproj`, objectVersion 77, synchronized folder, no shared scheme; Xcode 27 / iOS 17 target). *Note: SourceKit shows "Cannot find type Segment/Lang…" false errors when reading `Analyzer.swift` alone — cross-file indexing noise; the full-target compile is the source of truth.*
- **On-device only, no keys.** No network calls, API keys, or secrets. `NSCameraUsageDescription` is set. DeepSeek (later fallback) is the only thing that would need a key and isn't wired in.
- **Runs on A.G.'s iPhone.** Reports show `pl-PL` present in `supportedRecognitionLanguages()` and the page-type picker in use. A.G. drives testing by scanning a page and pasting the report (`ReportBuilder`) back into chat.
- **Analyzer is solid on upright/clean scans**, both layouts (see the two capability summaries below). It works from the real device reports that have been thrown at it; the open items are OCR quality and a couple of genuinely-ambiguous geometry cases, not structure.

### What the Analyzer handles now
- **Layout B (numbered):** heading over-detection fixed (list membership decided before headings); bare markers claim their own-row text (survives skew); footer/page-number bleed filtered; pairs over the `min…max` range of numbers actually seen (exercises don't start at 1). A single page with English + Polish columns, or a two-page spread, both work.
- **Layout A (tables):** union-find cell builder pairs cells, not lines — multi-line English (`to live (somewhere)`), gendered Polish forms (`wolny (m.), wolna (f.) — single`), 3-line cells, and single entries wrapped on **both** sides (`Wszystko w porządku. — Everything's fine.`) all collapse to one card. See the `Analyzer.swift` row for the R1/R2a/R2b rules.

### How to verify (run after ANY Analyzer change)
From `samples/`: `python3 synth.py && python3 repro_report.py && python3 repro_report2.py && python3 repro_table.py && python3 repro_table2.py`, then rebuild the Swift target. Expected:
- `synth.py` → **28 table + 15 numbered**, no problems (the baseline synthetic page + spread).
- `repro_report.py` → **15 numbered** (skewed single-page exercise, items 1–15).
- `repro_report2.py` → **21 numbered, 0 problems** (asserts; items 16–36).
- `repro_table.py` → **22 table** (old *garbled* scan; contains one known over-merge — see limits).
- `repro_table2.py` → **24 table, 0 leftovers** (clean 3-block table with gendered + both-sides wraps).
Each `repro_*.py` replays a real device report; add a new one whenever a fresh report exposes a case.

### Known limitations / parked
- **Upside-down (180°) numbered scans are NOT handled.** When a numbered page is captured upside-down, `TextRecognizer` can't tell upright from 180° (box aspect ratio is the same both ways, and confidence is a flat ~0.5), so it may pick the flipped frame: numbers land right-of-text, columns share a right edge, `16.` reads as `16..`, and pairing falls apart (~9/21 on one report). A pure 180° coordinate flip does *not* fix it. The durable fix discussed was **number-key pairing** (tag each numbered item's language and pair `EN[n]`↔`PL[n]` purely by number, dropping column geometry) — a real Layout B rewrite. **Parked at A.G.'s request.** Workaround: re-scan right-side-up.
- **Table wrap-vs-two-entries is not perfectly separable.** R2b uses a local-minimum-gap heuristic; on a messy scan two tightly-stacked *distinct* entries can still over-merge (`repro_table.py`: `urodziny rodzinne miasto — birthday hometown`). The real fix is a manual merge/split in the review screen (Phase 1). Don't chase the threshold — it's genuinely ambiguous (a wrapped entry and two tight entries can look identical).
- **Auto-shutter can't be defaulted to Manual.** `VNDocumentCameraViewController` exposes no API for it (VisionKit limitation). A.G. chose to leave the system scanner as-is (tap Auto→Manual in-scanner each time). A custom AVFoundation scanner is the only way to change it; not pursued.
- **Diacritics dropped with Language correction OFF** (`mówic`/`słuchac` missing `ć`, `ogladaja` missing `ą`). Try the Language-correction toggle **on** and compare — untested so far.

### Git state
- Session work is committed on branch **`analyzer-pairing-fixes`** (commit `2b94e2b`), **not pushed**; `main` is untouched. To land it: `git checkout main && git merge analyzer-pairing-fixes`, then push when ready.

## Next steps, in order
1. **Diacritics:** have A.G. re-scan a page with **Language correction ON** and compare — likely the cheapest quality win.
2. **Review screen (Phase 1):** scan → editable review (edit / merge / split / delete / manual pairing) → decks in SwiftData. This also *is* the fix for the two ambiguous cases above (upside-down numbered, table over-merge), so it's higher priority than more threshold tuning.
3. Optionally revisit **number-key pairing** for Layout B if upside-down/rotated numbered scans keep happening.
4. Roadmap after Phase 1: Phase 2 — flashcards (PL→EN and EN→PL), FSRS, pl-PL audio (`AVSpeechSynthesizer`). Phase 3 — duplicate detection, stats, TestFlight. Phase 4 — DeepSeek text fallback for messy pages, typing/listening modes, Anki/CSV export.
