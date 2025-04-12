import Foundation
import AVFoundation
@preconcurrency import WhisperKit


protocol WhisperManagerType {

    func setupWhisperIfNeeded(modelName: String) async throws
    func supportedModel() -> [String]
    func transcribe(url: URL) async throws -> [TranscriptSegment]
}

// Making WhisperManager sendable by adding @unchecked Sendable conformance
final class WhisperManager: @unchecked Sendable, WhisperManagerType {

    // MARK: Properties

    // WhisperKitの各種モデルコンポーネント
    private var whisperKit: WhisperKit?
    // 言語設定
    private let language = "ja" // 日本語文字起こし用
    // WhisperKitのダウンロード設定
    private let modelRepo = "argmaxinc/whisperkit-coreml"
    // WhisperKitのロード状態
    private var isLoading = false

    // MARK: Public Functions

    // WhisperKitの初期設定
    func setupWhisperIfNeeded(modelName: String = "base") async throws {
        if whisperKit == nil, isLoading {
            return
        }
        // WhisperKitの設定を作成
        let config = WhisperKitConfig(
            model: modelName,
            modelRepo: modelRepo,
            verbose: true,
            logLevel: .debug,
            download: true
        )
        do {
            // モデルを初期化
            let whisperKit = try await WhisperKit(config)
            // モデルの読み込み
            try await whisperKit.loadModels()
            // モデルの読み込みが成功した場合、WhisperKitインスタンスを保存
            self.whisperKit = whisperKit
        } catch {
            throw WhisperError.failedToInitialize
        }
    }

    func supportedModel() -> [String] {
        return WhisperKit.recommendedModels().supported
    }

    // 音声ファイルを文字起こしする
    func transcribe(url: URL) async throws -> [TranscriptSegment] {
        try await setupWhisperIfNeeded()
        // ファイル形式を確認
        let fileExtension = url.pathExtension.lowercased()
        let supportedFormats = ["wav", "mp3", "m4a", "flac", "mp4"]
        guard supportedFormats.contains(fileExtension) else {
            throw WhisperError.unsupportedFormat
        }
        
        guard let whisperKit = whisperKit else {
            throw WhisperError.uninitialized
        }
        // 文字起こし処理を実行
        return try await transcribeAudio(whisperKit: whisperKit, url: url)
    }

    // MARK: Private Functions

    // 文字起こしを実行（WhisperKitを使用）
    private func transcribeAudio(whisperKit: WhisperKit, url: URL) async throws -> [TranscriptSegment]{
        // 音声ファイルをロード
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
                decodeOptions: decodeOptions
            )
            // WhisperKitの結果からTranscriptSegmentを生成
            var segments: [TranscriptSegment] = []
            guard let result = results.first else {
                return []
            }

            for segment in result.segments {
                let cleanedText = removeTagsFromText(segment.text)
                let transcriptSegment = TranscriptSegment(
                    text: cleanedText.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end)
                )
                segments.append(transcriptSegment)
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
            print("正規表現エラー: \(error.localizedDescription)")
            return text
        }
    }
}
