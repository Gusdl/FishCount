import Foundation

#if canImport(WhisperKit)
import AVFoundation
import WhisperKit

final class WhisperBackend: SpeechBackend {
    var onUtterance: ((String) -> Void)?
    var onPartial: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private let modelURL: URL
    private let aggregator = UtteranceAggregator(timeout: 0.6)
    private var teardownHandler: (() -> Void)?

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

        // Placeholder implementation. Replace with the appropriate WhisperKit streaming setup.
        throw SpeechBackendError.backendUnavailable("WhisperKit-Streaming muss projektspezifisch initialisiert werden.")
    }

    func stop() {
        teardownHandler?()
        teardownHandler = nil
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
