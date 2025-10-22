import Foundation

#if canImport(WhisperKit)

final class WhisperBackend: SpeechBackend {
    var onUtterance: ((String) -> Void)?
    var onPartial: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private let modelURL: URL
    private let aggregator = UtteranceAggregator(timeout: 0.6)

    init(modelURL: URL) {
        self.modelURL = modelURL
        aggregator.onFinalUtterance = { [weak self] text in
            self?.onUtterance?(text)
        }
    }

    func start() throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw SpeechBackendError.modelMissing
        }

        throw SpeechBackendError.backendUnavailable("WhisperKit-Streaming muss projektspezifisch initialisiert werden.")
    }

    func stop() {
        aggregator.forceCommit()
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
