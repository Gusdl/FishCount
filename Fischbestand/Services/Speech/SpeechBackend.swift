import Foundation

protocol SpeechBackend: AnyObject {
    var onUtterance: ((String) -> Void)? { get set }
    var onPartial: ((String) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    func start() throws
    func stop()
}

enum SpeechBackendError: LocalizedError {
    case recognizerUnavailable
    case backendUnavailable(String)
    case modelMissing

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Spracherkennung ist auf diesem Gerät nicht verfügbar."
        case let .backendUnavailable(reason):
            return reason
        case .modelMissing:
            return "Das Whisper-Modell wurde noch nicht geladen."
        }
    }
}
