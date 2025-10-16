import AVFoundation
import Speech

final class AppleSpeechBackend: NSObject, SpeechBackend {
    var onUtterance: ((String) -> Void)?
    var onPartial: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let aggregator: UtteranceAggregator
    private let contextWordsProvider: () -> [String]

    init(contextWordsProvider: @escaping () -> [String] = { SpeechHints.contextWords() }) {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de_DE"))
        aggregator = UtteranceAggregator(timeout: 1.0)
        self.contextWordsProvider = contextWordsProvider
        super.init()
        aggregator.onFinalUtterance = { [weak self] text in
            self?.onUtterance?(text)
        }
    }

    func start() throws {
        guard let recognizer else { throw SpeechBackendError.recognizerUnavailable }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextWordsProvider()
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self, weak request] buffer, _ in
            request?.append(buffer)
            if request == nil {
                self?.audioEngine.inputNode.removeTap(onBus: 0)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString
                self.aggregator.ingestPartial(transcript)
                DispatchQueue.main.async { [weak self] in
                    self?.onPartial?(transcript)
                }
                if result.isFinal {
                    self.aggregator.forceCommit()
                }
            }
            if let error {
                DispatchQueue.main.async { [weak self] in
                    self?.onError?(error)
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        aggregator.forceCommit()

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
