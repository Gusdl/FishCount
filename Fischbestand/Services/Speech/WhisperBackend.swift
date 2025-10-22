import Foundation

final class WhisperBackend: SpeechBackend {
    var onUtterance: ((String) -> Void)?
    var onPartial: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private let modelURL: URL

    init(modelURL: URL) {
        self.modelURL = modelURL
    }

    func start() throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw SpeechBackendError.modelMissing
        }

        throw SpeechBackendError.backendUnavailable("WhisperKit ist im aktuellen Build nicht verfügbar.")
    }

    func stop() {}
}
