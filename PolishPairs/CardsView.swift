import SwiftUI
import SwiftData

/// All saved cards: filter by how they went, study the filtered set, edit, flag, delete.
struct CardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    @AppStorage("studyDirection") private var direction: StudyDirection = .plToEn
    @AppStorage("autoSpeak") private var autoSpeak = true
    @State private var deck: CardKind?   // nil = both decks
    @State private var filter: CardFilter = .all
    @State private var session: StudySession?
    @State private var editing: Card?
    @State private var adding = false
    @State private var confirmReset: Reset?

    /// Development resets.
    private enum Reset {
        case progress, everything

        var title: String { self == .progress ? "Reset progress?" : "Delete all cards?" }
        var button: String { self == .progress ? "Reset progress" : "Delete all cards" }
        func message(_ count: Int) -> String {
            self == .progress
                ? "Keeps all \(count) cards but clears right/wrong/skipped history and practice flags."
                : "Deletes all \(count) cards and their history. You'll need to scan again."
        }
    }

    private func perform(_ reset: Reset) {
        for card in cards {
            switch reset {
            case .progress:
                card.lastOutcome = .new
                card.lastReviewed = nil
                card.correctCount = 0
                card.wrongCount = 0
                card.skipCount = 0
                card.needsPractice = false
            case .everything:
                context.delete(card)
            }
        }
    }

    private struct StudySession: Identifiable {
        let id = UUID()
        let cards: [Card]
    }

    private var shown: [Card] {
        cards.filter { (deck == nil || $0.kind == deck) && filter.includes($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    ContentUnavailableView("No cards yet", systemImage: "rectangle.stack",
                                           description: Text("Scan a page in the Scan tab and tap Save cards, or add one with +."))
                } else {
                    cardList
                }
            }
            .navigationTitle("Cards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Reset progress…", systemImage: "arrow.counterclockwise") { confirmReset = .progress }
                        Button("Delete all cards…", systemImage: "trash", role: .destructive) { confirmReset = .everything }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise.circle")
                    }
                    .disabled(cards.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        adding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog(confirmReset?.title ?? "", isPresented: Binding(
                get: { confirmReset != nil },
                set: { if !$0 { confirmReset = nil } }
            ), titleVisibility: .visible, presenting: confirmReset) { reset in
                Button(reset.button, role: .destructive) { perform(reset) }
            } message: { reset in
                Text(reset.message(cards.count))
            }
            .sheet(item: $editing) { CardEditor(card: $0) }
            .sheet(isPresented: $adding) { CardEditor(card: nil) }
            .fullScreenCover(item: $session) { StudyView(cards: $0.cards, direction: direction) }
        }
    }

    private var cardList: some View {
        List {
            Section {
                Picker("Deck", selection: $deck) {
                    Text("All").tag(CardKind?.none)
                    ForEach(CardKind.allCases) { Text($0.label).tag(CardKind?.some($0)) }
                }
                .pickerStyle(.segmented)

                Picker("Show", selection: $filter) {
                    ForEach(CardFilter.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Direction", selection: $direction) {
                    ForEach(StudyDirection.allCases) { Text($0.label).tag($0) }
                }

                Toggle("Read Polish aloud after answering", isOn: $autoSpeak)

                Button {
                    session = StudySession(cards: shown)
                } label: {
                    Label("Study \(shown.count) \(shown.count == 1 ? "card" : "cards")",
                          systemImage: "rectangle.on.rectangle.angled")
                }
                .disabled(shown.isEmpty)
            }

            Section("\(deck?.label ?? "All decks") · \(filter.label) (\(shown.count))") {
                if shown.isEmpty {
                    Text("No cards match.").foregroundStyle(.secondary)
                }
                ForEach(shown) { card in
                    CardRow(card: card)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = card }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(card)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                card.needsPractice.toggle()
                            } label: {
                                Label(card.needsPractice ? "Unflag" : "Practice",
                                      systemImage: card.needsPractice ? "flag.slash" : "flag")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
    }
}

struct CardRow: View {
    let card: Card

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.polish).font(.body.weight(.semibold))
                Text(card.english).foregroundStyle(.secondary)
            }
            Spacer()
            if card.needsPractice {
                Image(systemName: "flag.fill").foregroundStyle(.orange)
            }
            switch card.lastOutcome {
            case .correct: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .wrong: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .skipped: Image(systemName: "forward.fill").foregroundStyle(.gray)
            case .new: EmptyView()
            }
            Button {
                Speaker.shared.speak(card.polish)
            } label: {
                Image(systemName: "speaker.wave.2")
            }
            .buttonStyle(.borderless)   // so tapping the row still opens the editor
            .padding(.leading, 6)
            .accessibilityLabel("Say it in Polish")
        }
    }
}

/// Add a new card (card == nil) or edit an existing one.
struct CardEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let card: Card?
    @State private var polish: String
    @State private var english: String
    @State private var needsPractice: Bool
    @State private var kind: CardKind

    init(card: Card?) {
        self.card = card
        _polish = State(initialValue: card?.polish ?? "")
        _english = State(initialValue: card?.english ?? "")
        _needsPractice = State(initialValue: card?.needsPractice ?? false)
        _kind = State(initialValue: card?.kind ?? .words)
    }

    private var valid: Bool {
        !polish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Polish") {
                    TextField("Polish", text: $polish, axis: .vertical)
                        .autocorrectionDisabled()
                }
                Section("English") {
                    TextField("English", text: $english, axis: .vertical)
                        .autocorrectionDisabled()
                }
                Section {
                    Picker("Deck", selection: $kind) {
                        ForEach(CardKind.allCases) { Text($0.label).tag($0) }
                    }
                    Button("Swap Polish and English") { swap(&polish, &english) }
                    Toggle("Needs practice", isOn: $needsPractice)
                }
            }
            .navigationTitle(card == nil ? "New card" : "Edit card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!valid)
                }
            }
        }
    }

    private func save() {
        let pl = polish.trimmingCharacters(in: .whitespacesAndNewlines)
        let en = english.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = card ?? Card(polish: pl, english: en, kind: kind)
        target.polish = pl
        target.english = en
        target.kind = kind
        target.needsPractice = needsPractice
        if card == nil { context.insert(target) }
        dismiss()
    }
}
