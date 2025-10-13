import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcript: String = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    var onUtterance: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))!
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var lastSpeechAt = Date()
    private let silenceTimeout: TimeInterval = 0.8
    private var silenceTimer: Timer?
    private var lastCommitted = ""
    private var hints: [String] = []
    private var tapInstalled = false

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

    func start(hints: [String], onUtterance: @escaping (String) -> Void) async throws {
        guard recognizer.isAvailable else {
            throw NSError(domain: "Speech", code: 4, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available for current locale."])
        }

        self.onUtterance = onUtterance
        self.hints = hints
        lastCommitted = ""
        transcript = ""

        try await checkPermissions()
        try configureSession()
        try startRecording()
    }

    func stop() {
        guard request != nil else { return }
        silenceTimer?.invalidate()
        silenceTimer = nil
        finishAudioInput()
        isRecording = false
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecording() throws {
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw NSError(domain: "Speech", code: 5, userInfo: nil) }

        request.shouldReportPartialResults = false
        request.contextualStrings = hints
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }

        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            if self.bufferContainsSpeech(buffer) {
                self.lastSpeechAt = Date()
            }
            self.request?.append(buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()

        lastSpeechAt = Date()
        startSilenceMonitoring()
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error {
                Task { @MainActor in
                    self.handleError(error)
                }
                return
            }

            guard let result, result.isFinal else { return }

            Task { @MainActor in
                self.handleFinalResult(result)
            }
        }
    }

    private func bufferContainsSpeech(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData else { return false }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return false }

        var rmsAccumulator: Float = 0
        for channel in 0..<channelCount {
            let data = channelData[channel]
            var sum: Float = 0
            for frame in 0..<frameLength {
                let sample = data[frame]
                sum += sample * sample
            }
            rmsAccumulator += sum / Float(frameLength)
        }

        let meanSquare = rmsAccumulator / Float(channelCount)
        guard meanSquare > 0 else { return false }

        let rms = sqrt(meanSquare)
        let power = 20 * log10(rms)
        return power > -45
    }

    private func startSilenceMonitoring() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if !self.isRecording {
                timer.invalidate()
                return
            }
            if Date().timeIntervalSince(self.lastSpeechAt) >= self.silenceTimeout {
                timer.invalidate()
                Task { @MainActor in
                    self.handleSilenceTimeout()
                }
            }
        }
        if let silenceTimer {
            RunLoop.main.add(silenceTimer, forMode: .common)
        }
    }

    private func handleSilenceTimeout() {
        finishAudioInput()
        isRecording = false
    }

    private func handleError(_ error: Error) {
        print("Speech recognition error: \(error.localizedDescription)")
        finishAudioInput()
        cleanupAfterRecognition(cancelTask: true)
    }

    private func handleFinalResult(_ result: SFSpeechRecognitionResult) {
        finishAudioInput()

        let text = result.bestTranscription.formattedString
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            cleanupAfterRecognition()
            return
        }

        guard text != lastCommitted else {
            cleanupAfterRecognition()
            return
        }

        lastCommitted = text
        transcript = text
        onUtterance?(text)

        cleanupAfterRecognition()
    }

    private func finishAudioInput() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
    }

    private func cleanupAfterRecognition(cancelTask: Bool = false) {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if cancelTask {
            task?.cancel()
        }
        request = nil
        task = nil
        onUtterance = nil

        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}
