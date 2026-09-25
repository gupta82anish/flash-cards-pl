import SwiftUI
import PhotosUI
import VisionKit
import UIKit

struct ContentView: View {
    @State private var showScanner = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var result: AnalysisResult?
    @State private var busy = false
    @State private var languageCorrection = false
    @State private var copied = false
    @State private var supported: [String] = []

    private var polishAvailable: Bool { supported.contains { $0.lowercased().hasPrefix("pl") } }

    var body: some View {
        NavigationStack {
            List {
                Section("Setup check") {
                    Label(polishAvailable ? "Polish text recognition: available" : "Polish text recognition: NOT available",
                          systemImage: polishAvailable ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(polishAvailable ? .green : .red)
                    Toggle("Language correction", isOn: $languageCorrection)
                }

                Section {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan pages", systemImage: "doc.viewfinder")
                    }
                    .disabled(!VNDocumentCameraViewController.isSupported || busy)

                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 4, matching: .images) {
                        Label("Choose photos", systemImage: "photo.on.rectangle")
                    }
                    .disabled(busy)

                    if !images.isEmpty {
                        Button("Re-run on the same pages") { run() }
                            .disabled(busy)
                    }
                    if busy {
                        ProgressView("Reading…")
                    }
                } footer: {
                    Text("For a numbered exercise, scan the English page and the Polish page in the same scan.")
                }

                if let r = result {
                    Section {
                        Button(copied ? "Copied — paste it into the chat" : "Copy results") {
                            UIPasteboard.general.string = r.report
                            copied = true
                        }
                    }
                    if let title = r.title {
                        Section("Deck title") { Text(title) }
                    }
                    Section("Table pairs (\(r.tablePairs.count))") {
                        ForEach(r.tablePairs) { PairRow(pair: $0) }
                    }
                    Section("Numbered pairs (\(r.numberedPairs.count))") {
                        ForEach(r.numberedPairs) { PairRow(pair: $0) }
                    }
                    if !r.problems.isEmpty {
                        Section("Problems (\(r.problems.count))") {
                            ForEach(r.problems, id: \.self) { Text($0).foregroundStyle(.red) }
                        }
                    }
                    Section("Unpaired text (\(r.leftovers.count))") {
                        ForEach(r.leftovers) { s in
                            Text(s.text).foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Polish Pairs test")
            .sheet(isPresented: $showScanner) {
                DocumentScanner { scanned in
                    showScanner = false
                    if !scanned.isEmpty {
                        images = scanned
                        run()
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    var loaded: [UIImage] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            loaded.append(image)
                        }
                    }
                    pickerItems = []
                    if !loaded.isEmpty {
                        images = loaded
                        run()
                    }
                }
            }
            .task {
                supported = TextRecognizer.supportedLanguages()
            }
        }
    }

    private func run() {
        busy = true
        copied = false
        let pages = images
        let correction = languageCorrection
        let languages = supported
        Task.detached(priority: .userInitiated) {
            var segments: [Segment] = []
            var orientations: [String] = []
            for (index, image) in pages.enumerated() {
                let r = TextRecognizer.recognize(image: image, page: index, languageCorrection: correction)
                segments += r.segments
                orientations.append(r.orientation)
            }
            var analysis = Analyzer(tag: LanguageTagger.tag).analyze(segments)
            analysis.orientations = orientations
            analysis.report = ReportBuilder.build(analysis, supportedLanguages: languages, languageCorrection: correction)
            await MainActor.run {
                result = analysis
                busy = false
            }
        }
    }
}

struct PairRow: View {
    let pair: Pair

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(pair.polish).font(.body.weight(.semibold))
            Text(pair.english).foregroundStyle(.secondary)
            Text(pair.source).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
