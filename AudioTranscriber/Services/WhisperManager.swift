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

    // WhisperKitの初期設定
    func setupWhisperIfNeeded(modelName: String, progressCallback: ((WhisperInitializeStatus) -> Void)? = nil) async throws {
        // モデルが変更された場合か、まだ初期化されていない場合のみセットアップを実行
        if (whisperKit != nil && currentModelName == modelName) {
            return
        }

        progressCallback?(.checkingModel)
        // モデル名が有効かチェック
        let supported = supportedModel()
        guard supported.contains(modelName) else {
            throw WhisperError.unsupportedModel
        }
        // WhisperKitの設定を作成
        let config = WhisperKitConfig(
            model: modelName,
            modelRepo: modelRepo,
            verbose: false,
            download: true
        )
        do {
            progressCallback?(.downloadingModel(progress: 0.0))
            // WhisperKitのダウンロードを実行
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
            // モデルの読み込みが成功した場合、WhisperKitインスタンスを保存
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

    // 音声ファイルを文字起こしする
    func transcribe(url: URL, progressCallback: @escaping (TimeInterval) -> Void) async throws -> [TranscriptSegment] {
        try await setupWhisperIfNeeded(modelName: currentModelName)
        // ファイル形式を確認
        let fileExtension = url.pathExtension.lowercased()
        let supportedFormats = SupportAudioType.allCases.map { $0.rawValue }
        guard supportedFormats.contains(fileExtension) else {
            throw WhisperError.unsupportedFormat
        }
        
        guard let whisperKit = whisperKit else {
            throw WhisperError.uninitialized
        }
        // オーディオファイルの長さを取得
        let audioDuration = try await getAudioDuration(for: url)
        // 文字起こし処理を実行
        return try await transcribeAudio(
            whisperKit: whisperKit,
            url: url,
            audioDuration: audioDuration,
            progressCallback: progressCallback
        )
    }

    // MARK: Private Functions
    
    // オーディオファイルの長さを取得
    private func getAudioDuration(for url: URL) async throws -> TimeInterval {
        // 通常の音声ファイル
        let audioPlayer = try AVAudioPlayer(contentsOf: url)
        return audioPlayer.duration
    }

    // 文字起こしを実行（WhisperKitを使用）
    private func transcribeAudio(
        whisperKit: WhisperKit,
        url: URL,
        audioDuration: TimeInterval,
        progressCallback: @escaping (TimeInterval) -> Void
    ) async throws -> [TranscriptSegment]{
        do {
            // 文字起こし設定
            let decodeOptions = DecodingOptions(
                task: .transcribe,
                language: language,
                temperature: 0.0
            )
            // 文字起こしを実行 - audioPathを使用
            let results = try await whisperKit.transcribe(
                audioPath: url.path,
                decodeOptions: decodeOptions,
                callback: { _ in
                    let progress = whisperKit.progress.fractionCompleted
                    progressCallback(progress)
                    return true
            })
            // WhisperKitの結果からTranscriptSegmentを生成
            var segments: [TranscriptSegment] = []
            guard let result = results.first else {
                return []
            }

            for segment in result.segments {
                let cleanedText = removeTagsFromText(segment.text)
                // 同じテキストが連続している場合は、前のセグメントを更新
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

    // 山括弧で囲まれたタグを削除するヘルパーメソッド
    private func removeTagsFromText(_ text: String) -> String {
        // 正規表現で<>で囲まれた部分を削除
        let pattern = "<[^>]+>"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        } catch {
            print("error: regex: \(error.localizedDescription)")
            return text
        }
    }
}
