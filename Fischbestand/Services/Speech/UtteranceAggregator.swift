import Foundation

final class UtteranceAggregator {
    private let timeout: TimeInterval
    private let queue = DispatchQueue(label: "UtteranceAggregator.queue")
    private var timer: DispatchSourceTimer?
    private var latestUtterance: String = ""

    var onFinalUtterance: ((String) -> Void)?

    init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    func ingestPartial(_ text: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.latestUtterance = text
            self.scheduleTimer()
        }
    }

    func forceCommit() {
        queue.async { [weak self] in
            self?.commit()
        }
    }

    private func scheduleTimer() {
        timer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { [weak self] in
            self?.commit()
        }
        self.timer = timer
        timer.resume()
    }

    private func commit() {
        timer?.cancel()
        timer = nil
        let text = latestUtterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        latestUtterance = ""
        DispatchQueue.main.async { [weak self] in
            self?.onFinalUtterance?(text)
        }
    }
}
