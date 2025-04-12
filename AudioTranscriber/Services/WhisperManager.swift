import Foundation
import AVFoundation
@preconcurrency import WhisperKit


protocol WhisperManagerType {

    func setupWhisperIfNeeded(modelName: String) async throws
    func supportedModel() -> [String]
    func transcribe(url: URL, progressCallback: @escaping (TimeInterval) -> Void) async throws -> [TranscriptSegment]
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
    func transcribe(url: URL, progressCallback: @escaping (TimeInterval) -> Void) async throws -> [TranscriptSegment] {
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
        if url.pathExtension.lowercased() == "mp4" {
            let asset = AVAsset(url: url)
            return try await TimeInterval(CMTimeGetSeconds(asset.load(.duration)))
        } else {
            // 通常の音声ファイル
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            return audioPlayer.duration
        }
    }

    // 文字起こしを実行（WhisperKitを使用）
    private func transcribeAudio(
        whisperKit: WhisperKit,
        url: URL,
        audioDuration: TimeInterval,
        progressCallback: @escaping (TimeInterval) -> Void
    ) async throws -> [TranscriptSegment]{
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
            print("正規表現エラー: \(error.localizedDescription)")
            return text
        }
    }
}
