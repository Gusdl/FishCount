import AVFoundation
import Speech

final class SpeechManager: ObservableObject {
    @Published var isRecording = false
    @Published var latestText: String = ""
    @Published var lastInfo: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var bufferText: String = ""
    private var debounceWorkItem: DispatchWorkItem?
    private var currentTranscript: String = ""
    private var processedTranscript: String = ""

    var speciesCatalog: [String] = SpeciesCatalog.all
    var activeDefaultSize: SizeRange?

    var onCommands: (([ParsedCommand]) -> Void)?
    var onUnrecognized: ((String) -> Void)?

    func start() throws {
        guard !isRecording else { return }
        lastInfo = "Höre zu …"
        bufferText = ""
        currentTranscript = ""
        processedTranscript = ""
        latestText = ""
        try setupAudio()
        isRecording = true
    }

    func stop() {
        guard isRecording else { return }
        debounceWorkItem?.cancel()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        bufferText = ""
        currentTranscript = ""
        processedTranscript = ""
        lastInfo = "Aufnahme gestoppt."
    }

    private func setupAudio() throws {
        guard let recognizer else { throw NSError(domain: "Speech", code: -1) }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString
                self.onPartial(transcript: transcript)
                if result.isFinal {
                    self.flush()
                }
            }
            if let error {
                self.lastInfo = "Spracherkennung beendet (\(error.localizedDescription))"
                self.stop()
            }
        }
    }

    private func onPartial(transcript: String) {
        latestText = transcript
        let lower = transcript.lowercased()
        currentTranscript = lower

        if !processedTranscript.isEmpty, lower.hasPrefix(processedTranscript) {
            let startIndex = lower.index(lower.startIndex, offsetBy: processedTranscript.count)
            let suffix = lower[startIndex...]
            bufferText = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            bufferText = lower.trimmingCharacters(in: .whitespacesAndNewlines)
            if !processedTranscript.isEmpty, !lower.hasPrefix(processedTranscript) {
                processedTranscript = ""
            }
        }

        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.processBuffer()
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func flush() {
        processBuffer(force: true)
    }

    private func processBuffer(force: Bool = false) {
        let text = bufferText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard force || !text.isEmpty else { return }

        let result = VoiceParser.extractCommands(from: text,
                                                 speciesCatalog: speciesCatalog,
                                                 defaultSize: activeDefaultSize)

        if !result.commands.isEmpty {
            onCommands?(result.commands)
            lastInfo = "Erfasst: " + result.commands.map { "\($0.species) – \($0.sizeRange.label) – \($0.count)×" }.joined(separator: ", ")
            bufferText = result.remainder
            processedTranscript = currentTranscript
        } else if force, !text.isEmpty {
            onUnrecognized?(text)
            lastInfo = "Nicht erkannt, als Notiz gespeichert."
            bufferText = ""
            processedTranscript = currentTranscript
        }
    }
}
