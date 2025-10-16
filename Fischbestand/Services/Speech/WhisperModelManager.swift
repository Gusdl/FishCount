import Foundation
import ZIPFoundation

final class WhisperModelManager {
    static let shared = WhisperModelManager()

    var modelName: String = "whisper-small-int8"
    var remoteArchiveURL: URL?

    private init() {}

    private var baseDirectory: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("Models", isDirectory: true)
    }

    var localModelURL: URL {
        baseDirectory.appendingPathComponent(modelName).appendingPathExtension("mlmodelc")
    }

    var isModelAvailable: Bool {
        FileManager.default.fileExists(atPath: localModelURL.path)
    }

    func ensureModelAvailable(progress: ((Double) -> Void)? = nil,
                              completion: @escaping (Result<URL, Error>) -> Void) {
        if isModelAvailable {
            completion(.success(localModelURL))
            return
        }

        guard let remoteArchiveURL else {
            completion(.failure(SpeechBackendError.backendUnavailable("Keine Download-URL für das Whisper-Modell konfiguriert.")))
            return
        }

        let fm = FileManager.default
        do {
            try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.downloadTask(with: remoteArchiveURL) { [weak self] tempURL, response, error in
            guard let self else { return }
            if let error {
                completion(.failure(error))
                return
            }
            guard let tempURL else {
                completion(.failure(SpeechBackendError.backendUnavailable("Download fehlgeschlagen.")))
                return
            }

            do {
                let downloadURL = self.baseDirectory.appendingPathComponent("download-\(UUID().uuidString)")
                if fm.fileExists(atPath: downloadURL.path) {
                    try fm.removeItem(at: downloadURL)
                }
                try fm.moveItem(at: tempURL, to: downloadURL)

                try self.unpack(at: downloadURL)
                progress?(1.0)
                completion(.success(self.localModelURL))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    private func unpack(at url: URL) throws {
        let fm = FileManager.default
        defer { try? fm.removeItem(at: url) }

        if url.pathExtension.lowercased() == "zip" {
            let extractDir = baseDirectory.appendingPathComponent("extract-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: extractDir) }

            let archive = try makeArchive(from: url)

            for entry in archive {
                let destinationURL = extractDir.appendingPathComponent(entry.path)
                let parent = destinationURL.deletingLastPathComponent()
                try fm.createDirectory(at: parent, withIntermediateDirectories: true)
                if entry.type == .directory {
                    try fm.createDirectory(at: destinationURL, withIntermediateDirectories: true)
                } else {
                    try archive.extract(entry, to: destinationURL)
                }
            }

            if let artifact = locateModelArtifact(in: extractDir) {
                try finalizeArtifact(at: artifact)
            } else {
                throw SpeechBackendError.backendUnavailable("Kein Whisper-Modell im Archiv gefunden.")
            }
        } else {
            try finalizeArtifact(at: url)
        }
    }

    private func makeArchive(from url: URL) throws -> Archive {
        do {
            return try Archive(url: url, accessMode: .read)
        } catch {
            if let fallbackArchive = try? Archive(url: url, accessMode: .read, preferredEncoding: .utf8) {
                return fallbackArchive
            }
            throw error
        }
    }

    private func locateModelArtifact(in directory: URL) -> URL? {
        let fm = FileManager.default
        if fm.fileExists(atPath: localModelURL.path) {
            return localModelURL
        }
        let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        while let item = enumerator?.nextObject() as? URL {
            if item.pathExtension == "mlmodelc" {
                return item
            }
        }
        return nil
    }

    private func finalizeArtifact(at url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: localModelURL.path) {
            try fm.removeItem(at: localModelURL)
        }
        if fm.fileExists(atPath: url.path) {
            try fm.moveItem(at: url, to: localModelURL)
        } else {
            throw SpeechBackendError.backendUnavailable("Modell-Artefakt nicht gefunden.")
        }
    }
}
