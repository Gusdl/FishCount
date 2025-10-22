import Foundation

#if canImport(WhisperKit)
import AVFoundation
import WhisperKit

@MainActor
final class WhisperBackend: NSObject, SpeechBackend {
    var onUtterance: ((String) -> Void)?
    var onPartial: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private let modelURL: URL
    private let aggregator = UtteranceAggregator(timeout: 0.6)
    private var transcriber: StreamingTranscriber?
    private var microphone: Microphone?
    private var audioSessionConfigured = false

    init(modelURL: URL) {
        self.modelURL = modelURL
        super.init()

        aggregator.onFinalUtterance = { [weak self] text in
            self?.onUtterance?(text)
        }
    }

    func start() throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw SpeechBackendError.modelMissing
        }

        if !audioSessionConfigured {
            try configureAudioSession()
            audioSessionConfigured = true
        }

        if transcriber == nil {
            transcriber = try makeTranscriber()
        }

        guard let transcriber else {
            throw SpeechBackendError.backendUnavailable("WhisperKit konnte nicht initialisiert werden.")
        }

        transcriber.delegate = self
        try transcriber.startStreaming()
    }

    func stop() {
        transcriber?.stopStreaming()
        transcriber = nil
        microphone?.stop()
        microphone = nil
        aggregator.forceCommit()
        deactivateAudioSession()
        audioSessionConfigured = false
    }

    private func makeTranscriber() throws -> StreamingTranscriber {
        let preferredLanguage = Locale.preferredLanguages.first
        let locale = preferredLanguage.flatMap { Locale(identifier: $0) }
        let languageCode = locale?.language.languageCode?.identifier ?? "de"

        let configuration = TranscriptionConfiguration(
            task: .transcribe,
            language: languageCode,
            translateTo: nil,
            enableVAD: true,
            prompt: nil
        )

        let transcriber = try StreamingTranscriber(modelURL: modelURL, configuration: configuration)
        let microphone = Microphone()
        microphone.delegate = transcriber
        self.microphone = microphone
        microphone.start()
        return transcriber
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.duckOthers, .allowBluetooth, .defaultToSpeaker])
        try session.setPreferredSampleRate(16_000)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension WhisperBackend: StreamingTranscriberDelegate {
    nonisolated func streamingTranscriber(_ transcriber: StreamingTranscriber, didProducePartialTranscript transcript: String) {
        Task { @MainActor in
            self.aggregator.ingestPartial(transcript)
            self.onPartial?(transcript)
        }
    }

    nonisolated func streamingTranscriber(_ transcriber: StreamingTranscriber, didProduceFinalTranscript transcript: String) {
        Task { @MainActor in
            self.aggregator.ingestPartial(transcript)
            self.aggregator.forceCommit()
        }
    }

    nonisolated func streamingTranscriber(_ transcriber: StreamingTranscriber, didEncounter error: Error) {
        Task { @MainActor in
            self.onError?(error)
        }
    }
}
#else

final class WhisperBackend: SpeechBackend {
    var onUtterance: ((String) -> Void)?
    var onPartial: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    init(modelURL: URL) {}

    func start() throws {
        throw SpeechBackendError.backendUnavailable("WhisperKit ist im aktuellen Build nicht verfügbar.")
    }

    func stop() {}
}

#endif
