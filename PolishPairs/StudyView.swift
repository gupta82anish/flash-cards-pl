import SwiftUI

/// One study session: type the answer, Submit or Skip, the card flips to show the answer.
struct StudyView: View {
    @Environment(\.dismiss) private var dismiss
    let direction: StudyDirection

    private enum Reveal: Equatable {
        case correct, accents, wrong, skipped, overridden
    }

    private struct Tally {
        var correct = 0, wrong = 0, skipped = 0
    }

    @State private var queue: [Card]
    @State private var index = 0
    @State private var typed = ""
    @State private var reveal: Reveal?
    @State private var flipped = false
    @State private var tally = Tally()
    @State private var missed: [Card] = []
    @FocusState private var fieldFocused: Bool
    @AppStorage("autoSpeak") private var autoSpeak = true

    init(cards: [Card], direction: StudyDirection) {
        _queue = State(initialValue: cards.shuffled())
        self.direction = direction
    }

    var body: some View {
        NavigationStack {
            Group {
                if index < queue.count {
                    session(queue[index])
                } else {
                    summary
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(index < queue.count ? "\(index + 1) of \(queue.count)" : "Done")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End") { dismiss() }
                }
            }
            .sensoryFeedback(trigger: reveal) { _, new in
                switch new {
                case .correct, .accents, .overridden: return .success
                case .wrong: return .error
                default: return nil
                }
            }
        }
    }

    // MARK: - Card

    private func session(_ card: Card) -> some View {
        VStack(spacing: 20) {
            FlipCard(
                angle: flipped ? 180 : 0,
                // Front gets a speaker only when the prompt is Polish — otherwise it would give the answer away.
                front: CardFace(language: direction.promptName, text: direction.prompt(card), footnote: nil, tint: .blue,
                                onSpeak: direction == .plToEn ? { Speaker.shared.speak(card.polish) } : nil),
                back: CardFace(language: direction.answerName, text: direction.answer(card),
                               footnote: direction.prompt(card), tint: tint,
                               onSpeak: { Speaker.shared.speak(card.polish) })
            )
            .frame(height: 280)
            .id(card.persistentModelID)   // a new card starts face-up, without animating back
            .onTapGesture {
                guard reveal != nil else { return }
                withAnimation(.spring(duration: 0.5)) { flipped.toggle() }
            }

            if let reveal {
                feedback(reveal, card)
            } else {
                answerArea
            }
            Spacer()
        }
        .padding()
        .onAppear { fieldFocused = true }
    }

    private var tint: Color {
        switch reveal {
        case .correct, .overridden: return .green
        case .accents, .skipped: return .orange
        case .wrong: return .red
        case nil: return .blue
        }
    }

    private var answerArea: some View {
        VStack(spacing: 12) {
            TextField("Type the \(direction.answerName) answer", text: $typed)
                .font(.title3)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .focused($fieldFocused)
                .onSubmit(submit)

            HStack(spacing: 12) {
                Button(action: skip) {
                    Text("Skip").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: submit) {
                    Text("Submit").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .controlSize(.large)
        }
    }

    private func feedback(_ reveal: Reveal, _ card: Card) -> some View {
        VStack(spacing: 12) {
            Label(title(reveal), systemImage: icon(reveal))
                .font(.headline)
                .foregroundStyle(tint)
            if reveal == .wrong || reveal == .accents {
                Text("You typed: \(typed)").foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    card.needsPractice.toggle()
                } label: {
                    Label(card.needsPractice ? "Marked for practice" : "Needs practice",
                          systemImage: card.needsPractice ? "flag.fill" : "flag")
                        .frame(maxWidth: .infinity)
                }
                .tint(.orange)

                if reveal == .wrong {
                    Button {
                        card.overrideToCorrect()
                        tally.wrong -= 1
                        tally.correct += 1
                        missed.removeAll { $0 === card }
                        self.reveal = .overridden
                    } label: {
                        Text("I was right").frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.bordered)

            Button(action: next) {
                Text("Next").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func title(_ reveal: Reveal) -> String {
        switch reveal {
        case .correct: return "Correct"
        case .accents: return "Correct — check the accents"
        case .wrong: return "Not quite"
        case .skipped: return "Skipped"
        case .overridden: return "Counted as correct"
        }
    }

    private func icon(_ reveal: Reveal) -> String {
        switch reveal {
        case .correct, .overridden: return "checkmark.circle.fill"
        case .accents: return "checkmark.circle.badge.questionmark"
        case .wrong: return "xmark.circle.fill"
        case .skipped: return "forward.fill"
        }
    }

    // MARK: - Actions

    private func submit() {
        let answer = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, reveal == nil, index < queue.count else { return }
        let card = queue[index]
        switch AnswerChecker.check(answer, answer: direction.answer(card), answerIsEnglish: direction.answerIsEnglish) {
        case .correct:
            reveal = .correct
            card.record(.correct)
            tally.correct += 1
        case .accentsOnly:
            reveal = .accents
            card.record(.correct)
            tally.correct += 1
        case .wrong:
            reveal = .wrong
            card.record(.wrong)
            tally.wrong += 1
            missed.append(card)
        }
        flip()
    }

    private func skip() {
        guard reveal == nil, index < queue.count else { return }
        let card = queue[index]
        reveal = .skipped
        card.record(.skipped)
        tally.skipped += 1
        missed.append(card)
        flip()
    }

    private func flip() {
        fieldFocused = false
        withAnimation(.spring(duration: 0.5)) { flipped = true }
        if autoSpeak { Speaker.shared.speak(queue[index].polish) }
    }

    private func next() {
        Speaker.shared.stop()
        index += 1
        typed = ""
        reveal = nil
        flipped = false
        fieldFocused = true
    }

    private func restart(with cards: [Card]) {
        queue = cards.shuffled()
        missed = []
        tally = Tally()
        index = 0
        typed = ""
        reveal = nil
        flipped = false
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 24) {
            Text("Session done").font(.largeTitle.bold())
            HStack(spacing: 32) {
                stat("Correct", tally.correct, .green)
                stat("Wrong", tally.wrong, .red)
                stat("Skipped", tally.skipped, .orange)
            }
            VStack(spacing: 12) {
                if !missed.isEmpty {
                    Button {
                        restart(with: missed)
                    } label: {
                        Text("Practise the \(missed.count) missed").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button {
                    dismiss()
                } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .padding()
    }

    private func stat(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack {
            Text("\(value)").font(.largeTitle.bold()).foregroundStyle(color)
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

/// Two faces with a 3D flip; the face shown switches at 90° so the back never reads mirrored.
struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front
            } else {
                back.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}

struct CardFace: View {
    let language: String
    let text: String
    let footnote: String?
    let tint: Color
    var onSpeak: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Text(language.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(tint)
            Text(text)
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
            if let footnote {
                Text(footnote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemGroupedBackground)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(tint.opacity(0.45), lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            if let onSpeak {
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .padding(16)
                }
                .tint(tint)
                .accessibilityLabel("Say it in Polish")
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }
}
