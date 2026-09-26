import SwiftUI
import SwiftData
import UIKit

/// An extracted pair before it's saved — editable in the review screen, becomes a `Card` on Save.
struct DraftCard: Identifiable {
    let id = UUID()
    var polish: String
    var english: String
    var kind: CardKind

    var isBlank: Bool {
        polish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Everything the review screen needs from one scan.
struct ReviewData: Identifiable {
    let id = UUID()
    var drafts: [DraftCard]
    var leftovers: [String]
    var report: String

    init(_ result: AnalysisResult) {
        drafts = result.tablePairs.map { DraftCard(polish: $0.polish, english: $0.english, kind: .words) }
            + result.numberedPairs.map { DraftCard(polish: $0.polish, english: $0.english, kind: .sentences) }
        leftovers = result.leftovers.map(\.text)
        report = result.report
    }
}

/// Review a scan before saving: edit text, delete, merge a split entry, add a missed card.
struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var drafts: [DraftCard]
    let leftovers: [String]
    let report: String
    /// Called after Save with a short summary for the Scan screen.
    let onSaved: (String) -> Void

    @State private var editing: Editing?
    @State private var copied = false

    private struct Editing: Identifiable { let id: DraftCard.ID }

    init(data: ReviewData, onSaved: @escaping (String) -> Void) {
        _drafts = State(initialValue: data.drafts)
        leftovers = data.leftovers
        report = data.report
        self.onSaved = onSaved
    }

    private var saveable: Int { drafts.filter { !$0.isBlank }.count }

    var body: some View {
        NavigationStack {
            List {
                ForEach($drafts) { $draft in
                    DraftRow(draft: draft)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = Editing(id: draft.id) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                drafts.removeAll { $0.id == draft.id }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if canMerge(draft.id) {
                                Button {
                                    merge(draft.id)
                                } label: {
                                    Label("Merge with next", systemImage: "arrow.triangle.merge")
                                }
                                .tint(.indigo)
                            }
                        }
                }

                if !leftovers.isEmpty {
                    Section {
                        ForEach(leftovers, id: \.self) { Text($0).foregroundStyle(.secondary) }
                    } header: {
                        Text("Unpaired text (\(leftovers.count))")
                    } footer: {
                        Text("Text the scan couldn't pair. Add any you want with +.")
                    }
                }
            }
            .overlay {
                if drafts.isEmpty {
                    ContentUnavailableView("Nothing extracted", systemImage: "doc.text.magnifyingglass",
                                           description: Text("Add a card with +, or go back and rescan."))
                }
            }
            .navigationTitle("Review \(saveable)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }.disabled(saveable == 0)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Add card", systemImage: "plus") {
                            let new = DraftCard(polish: "", english: "", kind: .words)
                            drafts.append(new)
                            editing = Editing(id: new.id)
                        }
                        Button(copied ? "Copied" : "Copy report", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = report
                            copied = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $editing) { editing in
                if let index = drafts.firstIndex(where: { $0.id == editing.id }) {
                    DraftEditor(draft: $drafts[index])
                }
            }
        }
    }

    // MARK: - Merge

    /// A draft can merge downward only into the next draft of the same deck.
    private func canMerge(_ id: DraftCard.ID) -> Bool {
        guard let i = drafts.firstIndex(where: { $0.id == id }), i + 1 < drafts.count else { return false }
        return drafts[i].kind == drafts[i + 1].kind
    }

    private func merge(_ id: DraftCard.ID) {
        guard let i = drafts.firstIndex(where: { $0.id == id }), i + 1 < drafts.count else { return }
        let next = drafts[i + 1]
        drafts[i].polish = join(drafts[i].polish, next.polish)
        drafts[i].english = join(drafts[i].english, next.english)
        drafts.remove(at: i + 1)
    }

    private func join(_ a: String, _ b: String) -> String {
        [a, b].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: - Save

    private func save() {
        let existing = (try? context.fetch(FetchDescriptor<Card>())) ?? []
        var seen = Set(existing.map { Card.key($0.polish, $0.english) })
        var added: [CardKind: Int] = [:]
        var dupes = 0
        for draft in drafts where !draft.isBlank {
            let pl = draft.polish.trimmingCharacters(in: .whitespacesAndNewlines)
            let en = draft.english.trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.insert(Card.key(pl, en)).inserted {
                context.insert(Card(polish: pl, english: en, kind: draft.kind))
                added[draft.kind, default: 0] += 1
            } else {
                dupes += 1
            }
        }
        let parts = CardKind.allCases.compactMap { k in added[k].map { "\($0) \(k.label.lowercased())" } }
        let message = (parts.isEmpty ? "Nothing new saved" : "Saved " + parts.joined(separator: ", "))
            + (dupes > 0 ? " (\(dupes) already saved)" : "")
        onSaved(message)
        dismiss()
    }
}

struct DraftRow: View {
    let draft: DraftCard

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if draft.isBlank {
                Text("Tap to fill in").italic().foregroundStyle(.secondary)
            } else {
                Text(draft.polish).font(.body.weight(.semibold))
                Text(draft.english).foregroundStyle(.secondary)
            }
            Text(draft.kind.label).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

/// Edit one draft in place; a binding so changes flow straight back to the review list.
struct DraftEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: DraftCard

    var body: some View {
        NavigationStack {
            Form {
                Section("Polish") {
                    TextField("Polish", text: $draft.polish, axis: .vertical).autocorrectionDisabled()
                }
                Section("English") {
                    TextField("English", text: $draft.english, axis: .vertical).autocorrectionDisabled()
                }
                Section {
                    Picker("Deck", selection: $draft.kind) {
                        ForEach(CardKind.allCases) { Text($0.label).tag($0) }
                    }
                    Button("Swap Polish and English") {
                        let polish = draft.polish
                        draft.polish = draft.english
                        draft.english = polish
                    }
                }
            }
            .navigationTitle("Edit card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
