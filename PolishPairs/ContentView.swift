import SwiftUI
import SwiftData
import PhotosUI
import VisionKit
import UIKit

struct ContentView: View {
    @State private var showScanner = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var review: ReviewData?
    @State private var busy = false
    @AppStorage("languageCorrection") private var languageCorrection = true
    @State private var supported: [String] = []
    @State private var mode: ScanMode = .auto
    @State private var savedMessage: String?

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
                    Picker("Page type", selection: $mode) {
                        ForEach(ScanMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Pick the page type before scanning. \"Auto\" tries both — use it only for a page with a table and an exercise together.")
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

                if let savedMessage {
                    Section {
                        Label(savedMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Scan")
            .sheet(item: $review) { data in
                ReviewView(data: data) { message in
                    savedMessage = message
                }
            }
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
        savedMessage = nil
        let pages = images
        let correction = languageCorrection
        let languages = supported
        let scanMode = mode
        Task.detached(priority: .userInitiated) {
            var segments: [Segment] = []
            var orientations: [String] = []
            for (index, image) in pages.enumerated() {
                let r = TextRecognizer.recognize(image: image, page: index, languageCorrection: correction)
                segments += r.segments
                orientations.append(r.orientation)
            }
            var analysis = Analyzer(tag: LanguageTagger.tag).analyze(segments, mode: scanMode)
            analysis.orientations = orientations
            analysis.report = ReportBuilder.build(analysis, supportedLanguages: languages, languageCorrection: correction)
            let finished = analysis
            await MainActor.run {
                review = ReviewData(finished)
                busy = false
            }
        }
    }
}
