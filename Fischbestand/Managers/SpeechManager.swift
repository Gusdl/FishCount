import Foundation
import Speech
import AVFoundation

final class SpeechManager: NSObject, ObservableObject {
    @Published var liveText: String = ""
    @Published private(set) var isRecording: Bool = false

    /// Wird bei jedem abgeschlossenen Satz (nach kurzer Stille) aufgerufen.
    var onUtterance: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))!
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // Stille-Handling für Satzgrenzen
    private var lastSpeechAt = Date()
    private let silenceTimeout: TimeInterval = 1.0
    private var timer: Timer?

    // Segmentierung
    private var lastCommittedSegmentIndex = 0
    private var latestSegments: [SFTranscriptionSegment] = []

    // Kontext
    private var contextual: [String] = []

    func start(contextualStrings: [String]) throws {
        guard !isRecording else { return }
        contextual = contextualStrings
        try configureSession()
        try startRecording()
        isRecording = true
    }

    func stop() {
        guard isRecording else { return }
        commitPendingUtteranceIfAny()
        timer?.invalidate(); timer = nil
        audioEngine.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
    }

    private func configureSession() throws {
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try s.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecording() throws {
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw NSError(domain: "Speech", code: -1) }

        request.shouldReportPartialResults = true
        request.contextualStrings = contextual
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
        }

        audioEngine.prepare()
        try audioEngine.start()

        lastSpeechAt = Date()
        lastCommittedSegmentIndex = 0
        latestSegments.removeAll()
        liveText = ""

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                self.liveText = r.bestTranscription.formattedString
                let segs = r.bestTranscription.segments
                if segs.count != self.latestSegments.count {
                    self.lastSpeechAt = Date()
                    self.latestSegments = segs
                }
            }
            if error != nil { self.commitPendingUtteranceIfAny() }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastSpeechAt) >= self.silenceTimeout {
                self.commitPendingUtteranceIfAny()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func commitPendingUtteranceIfAny() {
        guard latestSegments.count > lastCommittedSegmentIndex else { return }
        let slice = latestSegments[lastCommittedSegmentIndex..<latestSegments.count]
        let text = slice.map { $0.substring }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        lastCommittedSegmentIndex = latestSegments.count
        if !text.isEmpty { onUtterance?(text) }
    }
}
