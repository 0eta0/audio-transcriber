import Foundation
import AVFoundation
@preconcurrency import WhisperKit

protocol WhisperManagerType {

    func setupWhisperIfNeeded(modelName: String, progressCallback: ((WhisperInitializeStatus) -> Void)?) async throws
    func supportedModel() -> [String]
    func currentModel() -> String
    func transcribe(url: URL, progressCallback: @escaping (TimeInterval) -> Void) async throws -> [TranscriptSegment]
}

final class WhisperManager: @unchecked Sendable, WhisperManagerType {

    // MARK: Properties

    private var whisperKit: WhisperKit?
    private let language = "ja"
    private let modelRepo = "argmaxinc/whisperkit-coreml"
    private var currentModelName: String = "openai_whisper-base"

    // MARK: Public Functions

    // Initialize WhisperKit
    func setupWhisperIfNeeded(modelName: String, progressCallback: ((WhisperInitializeStatus) -> Void)? = nil) async throws {
        // Run setup only if the model has changed or has not been initialized yet
        if (whisperKit != nil && currentModelName == modelName) {
            return
        }

        progressCallback?(.checkingModel)
        // Check if the model name is valid
        let supported = supportedModel()
        guard supported.contains(modelName) else {
            throw WhisperError.unsupportedModel
        }
        // Create WhisperKit configuration
        let config = WhisperKitConfig(
            model: modelName,
            modelRepo: modelRepo,
            verbose: false,
            download: true
        )
        do {
            progressCallback?(.downloadingModel(progress: 0.0))
            // Execute WhisperKit download
            _ = try await WhisperKit.download(
                variant: modelName,
                from: modelRepo,
                progressCallback: { progress in
                    progressCallback?(.downloadingModel(progress: progress.fractionCompleted))
                }
            )
            progressCallback?(.loadingModel)

            let whisperKit = try await WhisperKit(config)
            try await whisperKit.loadModels()
            // Save WhisperKit instance if model loading is successful
            self.whisperKit = whisperKit
            currentModelName = modelName

            progressCallback?(.ready)
        } catch {
            throw WhisperError.failedToInitialize
        }
    }

    func supportedModel() -> [String] {
        return WhisperKit.recommendedModels().supported
    }
    
    func currentModel() -> String {
        return currentModelName
    }

    // Transcribe audio file
    func transcribe(url: URL, progressCallback: @escaping (TimeInterval) -> Void) async throws -> [TranscriptSegment] {
        try await setupWhisperIfNeeded(modelName: currentModelName)
        guard let whisperKit = whisperKit else {
            throw WhisperError.uninitialized
        }

        let fileExtension = url.pathExtension.lowercased()
        let supportedFormats = SupportMediaType.allCases.map { $0.rawValue }
        guard supportedFormats.contains(fileExtension) else {
            throw WhisperError.unsupportedFormat
        }
 
        var extractedAudioURL: URL?
        // If the file is a video, extract audio
        if isVideoFile(url: url) {
            let f = UUID().uuidString + ".m4a"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(f)
            extractedAudioURL = tempURL
            do {
                try await extractAudio(from: url, to: tempURL)
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                throw WhisperError.exportAudioFailed
            }
        }
        // Clean up temporary audio file
        defer {
            if let url = extractedAudioURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        let url = extractedAudioURL ?? url
        // Get audio file duration
        let audioDuration = try await getAudioDuration(for: url)
        // Execute transcription process
        return try await transcribeAudio(
            whisperKit: whisperKit,
            url: url,
            audioDuration: audioDuration,
            progressCallback: progressCallback
        )
    }

    // MARK: Private Functions
    
    private func isVideoFile(url: URL) -> Bool {
        return SupportMediaType.allVideoTypes
            .map({ $0.rawValue })
            .contains(url.pathExtension.lowercased())
    }
    
    // Get audio file duration
    private func getAudioDuration(for url: URL) async throws -> TimeInterval {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
    
    private func extractAudio(from videoURL: URL, to audioURL: URL) async throws {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw WhisperError.exportAudioFailed
        }
        session.outputFileType = .m4a
        session.outputURL = audioURL
        session.timeRange = CMTimeRange(start: .zero, duration: duration)
        await session.export()
    }

    // Execute transcription (using WhisperKit)
    private func transcribeAudio(
        whisperKit: WhisperKit,
        url: URL,
        audioDuration: TimeInterval,
        progressCallback: @escaping (TimeInterval) -> Void
    ) async throws -> [TranscriptSegment]{
        do {
            // Transcription settings
            let decodeOptions = DecodingOptions(
                task: .transcribe,
                language: language,
                temperature: 0.0
            )
            // Execute transcription - using audioPath
            let results = try await whisperKit.transcribe(
                audioPath: url.path,
                decodeOptions: decodeOptions,
                callback: { _ in
                    let progress = whisperKit.progress.fractionCompleted
                    progressCallback(progress)
                    return true
            })
            // Generate TranscriptSegment from WhisperKit results
            var segments: [TranscriptSegment] = []
            guard let result = results.first else {
                return []
            }

            for segment in result.segments {
                let cleanedText = removeTagsFromText(segment.text)
                // If the same text continues, update the previous segment
                if let last = segments.last, last.text == cleanedText {
                    let ts = TranscriptSegment(
                        text: cleanedText.trimmingCharacters(in: .whitespacesAndNewlines),
                        startTime: last.startTime,
                        endTime: TimeInterval(segment.end)
                    )
                    _ = segments.popLast()
                    segments.append(ts)
                    continue
                }
                let ts = TranscriptSegment(
                    text: cleanedText.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end)
                )
                segments.append(ts)
            }
            return segments
        } catch {
            throw WhisperError.transcriptionFailed
        }
    }

    // Helper method to remove tags enclosed in angle brackets
    private func removeTagsFromText(_ text: String) -> String {
        // Remove parts enclosed in <> using regular expressions
        let pattern = "<[^>]+>"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        } catch {
            return text
        }
    }
}
