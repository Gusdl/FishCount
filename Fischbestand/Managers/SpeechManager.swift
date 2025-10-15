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

    // Puffert laufend erkannte Tokens, bis eine Pause erkannt wird
    private var bufferedTokens: [String] = []
    private var lastProcessedCharCount: Int = 0
    private var lastSegmentTimestamp: TimeInterval = 0
    private let pauseCommitWindow: TimeInterval = 0.7

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
        flushBufferedTokens()
        audioEngine.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        lastProcessedCharCount = 0
        lastSegmentTimestamp = 0
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

        liveText = ""
        bufferedTokens.removeAll()
        lastProcessedCharCount = 0
        lastSegmentTimestamp = 0

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognition(result: result, error: error)
        }
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            liveText = result.bestTranscription.formattedString

            let transcription = result.bestTranscription
            let segments = transcription.segments
            let newCharCount = transcription.formattedString.count

            if newCharCount > lastProcessedCharCount {
                let newSegments = segments.filter { segment in
                    let segmentEnd = segment.substringRange.location + segment.substringRange.length
                    return segmentEnd > lastProcessedCharCount
                }

                for segment in newSegments {
                    bufferedTokens.append(segment.substring.lowercased())
                    lastSegmentTimestamp = CFAbsoluteTimeGetCurrent()
                }

                lastProcessedCharCount = newCharCount
            }

            var shouldCommit = false
            if !bufferedTokens.isEmpty, lastSegmentTimestamp > 0 {
                let gap = CFAbsoluteTimeGetCurrent() - lastSegmentTimestamp
                if gap >= pauseCommitWindow { shouldCommit = true }
            }

            if result.isFinal { shouldCommit = true }

            if shouldCommit, !bufferedTokens.isEmpty {
                let utterance = bufferedTokens.joined(separator: " ")
                commitUtterance(utterance)
                bufferedTokens.removeAll()
                lastSegmentTimestamp = 0
            }

            if result.isFinal {
                finalizeRecognition()
            }
        }

        if let error {
            print("Speech error:", error)
            finalizeRecognition()
        }
    }

    private func finalizeRecognition() {
        flushBufferedTokens()
        lastProcessedCharCount = 0
        lastSegmentTimestamp = 0
    }

    private func flushBufferedTokens() {
        guard !bufferedTokens.isEmpty else { return }
        let utterance = bufferedTokens.joined(separator: " ")
        commitUtterance(utterance)
        bufferedTokens.removeAll()
    }

    private func commitUtterance(_ text: String) {
        if Thread.isMainThread {
            onUtterance?(text)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onUtterance?(text)
            }
        }
    }
}
