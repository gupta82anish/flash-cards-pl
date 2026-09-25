import AVFoundation

/// Reads Polish aloud with the best installed pl-PL voice (Premium > Enhanced > default).
/// Better voices: Settings → Accessibility → Spoken Content → Voices → Polish.
@MainActor
final class Speaker {
    static let shared = Speaker()

    private let synth = AVSpeechSynthesizer()
    private lazy var voice: AVSpeechSynthesisVoice? =
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "pl-PL" }
            .max { $0.quality.rawValue < $1.quality.rawValue }
        ?? AVSpeechSynthesisVoice(language: "pl-PL")

    func speak(_ text: String) {
        // Book notes like "(m.)" / "(f.)" shouldn't be read out.
        let spoken = text.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        // .playback so a tap is heard even with the ring/silent switch on silent.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}
