import Foundation
import Combine

@MainActor
final class SpeechManager: ObservableObject {
    @Published var isRecording = false
    @Published var latestText: String = ""
    @Published var lastInfo: String?
    @Published private(set) var useWhisper = false
    @Published var isLoadingWhisperModel = false
    @Published var whisperDownloadProgress: Double = 0
    @Published var whisperError: String?

    var speciesCatalog: [String] = SpeciesCatalog.all
    var activeDefaultSize: SizeRange?

    var onCommands: (([ParsedCommand]) -> Void)?
    var onUnrecognized: ((String) -> Void)?

    private var backend: SpeechBackend
    private var pendingBuffer: String = ""
    private var whisperRemoteURL: URL?

    init() {
        backend = AppleSpeechBackend()

        #if canImport(WhisperKit)
        if let whisperBackend = makeWhisperBackend() {
            backend = whisperBackend
            useWhisper = true
        } else {
            backend = makeAppleBackend()
        }
        #else
        backend = makeAppleBackend()
        #endif

        wireBackend()
    }

    func configureWhisper(modelName: String? = nil, remoteURL: URL? = nil) {
        if let modelName, !modelName.isEmpty {
            WhisperModelManager.shared.modelName = modelName
        }
        if let remoteURL {
            whisperRemoteURL = remoteURL
            WhisperModelManager.shared.remoteArchiveURL = remoteURL
        }
    }

    func setWhisperEnabled(_ enabled: Bool, remoteURL: URL? = nil) {
        if let remoteURL {
            configureWhisper(remoteURL: remoteURL)
        }

        guard enabled else {
            switchBackend(useWhisper: false)
            return
        }

        guard !isRecording else {
            lastInfo = "Bitte Aufnahme beenden, bevor Whisper aktiviert wird."
            return
        }

        let manager = WhisperModelManager.shared
        if manager.remoteArchiveURL == nil, let whisperRemoteURL {
            manager.remoteArchiveURL = whisperRemoteURL
        }

        if manager.isModelAvailable {
            switchBackend(useWhisper: true)
            return
        }

        guard manager.remoteArchiveURL != nil else {
            let message = "Keine Download-Quelle für Whisper konfiguriert."
            whisperError = message
            lastInfo = message
            switchBackend(useWhisper: false)
            return
        }

        isLoadingWhisperModel = true
        whisperDownloadProgress = 0
        whisperError = nil

        manager.ensureModelAvailable(progress: { [weak self] value in
            Task { @MainActor in
                self?.whisperDownloadProgress = value
            }
        }, completion: { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingWhisperModel = false
                switch result {
                case .success:
                    self.switchBackend(useWhisper: true)
                case .failure(let error):
                    self.whisperError = error.localizedDescription
                    self.lastInfo = "Whisper konnte nicht geladen werden: \(error.localizedDescription)"
                    self.switchBackend(useWhisper: false)
                }
            }
        })
    }

    func start() throws {
        guard !isRecording else { return }
        lastInfo = "Höre zu …"
        pendingBuffer = ""
        latestText = ""
        do {
            try backend.start()
            isRecording = true
        } catch {
            if useWhisper {
                lastInfo = "Whisper nicht verfügbar (\(error.localizedDescription)), wechsle zu Apple Speech."
                switchBackend(useWhisper: false)
                do {
                    try backend.start()
                    isRecording = true
                    lastInfo = "Höre zu …"
                    return
                } catch {
                    lastInfo = "Spracherkennung fehlgeschlagen: \(error.localizedDescription)"
                    throw error
                }
            } else {
                lastInfo = "Spracherkennung fehlgeschlagen: \(error.localizedDescription)"
                throw error
            }
        }
    }

    func stop(reason: String? = nil) {
        backend.stop()
        let wasRecording = isRecording
        isRecording = false
        pendingBuffer = ""
        if let reason {
            lastInfo = reason
        } else if wasRecording {
            lastInfo = "Aufnahme gestoppt."
        }
    }

    private func wireBackend() {
        backend.onPartial = { [weak self] transcript in
            Task { @MainActor in
                self?.latestText = transcript
            }
        }
        backend.onUtterance = { [weak self] utterance in
            Task { @MainActor in
                self?.handleUtterance(utterance)
            }
        }
        backend.onError = { [weak self] error in
            Task { @MainActor in
                self?.handleBackendError(error)
            }
        }
    }

    private func handleUtterance(_ utterance: String) {
        latestText = utterance
        let normalized = utterance.lowercased()
        if !pendingBuffer.isEmpty {
            pendingBuffer.append(" ")
        }
        pendingBuffer.append(normalized)
        processPending(force: true)
    }

    private func processPending(force: Bool) {
        let text = pendingBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard force || !text.isEmpty else { return }

        let result = VoiceParser.extractCommands(from: text,
                                                 speciesCatalog: speciesCatalog,
                                                 defaultSize: activeDefaultSize)

        if !result.commands.isEmpty {
            onCommands?(result.commands)
            lastInfo = "Erfasst: " + result.commands.map { "\($0.species) – \($0.sizeRange.label) – \($0.count)×" }.joined(separator: ", ")
            pendingBuffer = result.remainder
        } else if force, !text.isEmpty {
            onUnrecognized?(text)
            lastInfo = "Nicht erkannt, als Notiz gespeichert."
            pendingBuffer = ""
        }
    }

    private func handleBackendError(_ error: Error) {
        stop(reason: "Spracherkennung beendet (\(error.localizedDescription))")
    }

    private func switchBackend(useWhisper: Bool) {
        backend.stop()
        pendingBuffer = ""

        if useWhisper, let whisperBackend = makeWhisperBackend() {
            backend = whisperBackend
            self.useWhisper = true
            lastInfo = "Whisper aktiv."
        } else {
            if useWhisper {
                lastInfo = "WhisperKit nicht verfügbar, nutze Apple Speech."
            }
            backend = makeAppleBackend()
            self.useWhisper = false
        }

        wireBackend()
    }

    private func makeWhisperBackend() -> SpeechBackend? {
        #if canImport(WhisperKit)
        return WhisperBackend(modelURL: WhisperModelManager.shared.localModelURL)
        #else
        return nil
        #endif
    }

    private func makeAppleBackend() -> SpeechBackend {
        AppleSpeechBackend(contextWordsProvider: { [weak self] in
            guard let self else { return SpeechHints.contextWords() }
            return SpeechHints.contextWords(speciesCatalog: self.speciesCatalog)
        })
    }
}
