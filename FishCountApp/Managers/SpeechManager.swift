import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcript: String = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))

    func checkPermissions() async throws {
        let status = SFSpeechRecognizer.authorizationStatus()
        authorizationStatus = status
        switch status {
        case .authorized:
            return
        case .denied, .restricted:
            throw NSError(domain: "SpeechAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission denied."])
        case .notDetermined:
            let newStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            authorizationStatus = newStatus
            if newStatus != .authorized {
                throw NSError(domain: "SpeechAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission not granted."])
            }
        @unknown default:
            throw NSError(domain: "SpeechAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown authorization status."])
        }
    }

    func start(transcriptHandler: @escaping (String) -> Void) async throws {
        guard recognizer?.isAvailable == true else {
            throw NSError(domain: "Speech", code: 4, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available for current locale."])
        }

        try await checkPermissions()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw NSError(domain: "Speech", code: 5, userInfo: nil) }
        request.shouldReportPartialResults = true

        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let text = result?.bestTranscription.formattedString {
                Task { @MainActor in
                    transcriptHandler(text)
                    self.transcript = text
                }
            }

            if let error {
                print("Speech recognition error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.stop()
                }
            }

            if result?.isFinal == true {
                Task { @MainActor in
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}
