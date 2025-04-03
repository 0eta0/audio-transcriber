import Foundation
import AVFoundation
@preconcurrency import WhisperKit

// Whisperによる文字起こしのエラー型
enum WhisperError: Int, Error {
    case conversionFailed = 1
    case transcriptionFailed = 2
    case modelLoadFailed = 3
    case fileAccessError = 4
    case networkError = 5
    case operationStopped = 6
    case modelDownloadFailed = 7
    
    var localizedDescription: String {
        switch self {
        case .conversionFailed:
            return "音声変換に失敗しました。ファイル形式を確認してください。"
        case .transcriptionFailed:
            return "文字起こしに失敗しました。音声ファイルを確認してください。"
        case .modelLoadFailed:
            return "モデルの読み込みに失敗しました。モデルをダウンロードしてください。"
        case .fileAccessError:
            return "ファイルアクセスに失敗しました。権限を確認してください。"
        case .networkError:
            return "ネットワークエラーが発生しました。接続を確認してください。"
        case .operationStopped:
            return "処理が中断されました。再度お試しください。"
        case .modelDownloadFailed:
            return "モデルのダウンロードに失敗しました。ネットワーク接続を確認して再度お試しください。"
        }
    }
}

// Making WhisperManager sendable by adding @unchecked Sendable conformance
class WhisperManager: @unchecked Sendable {
    // WhisperKitの各種モデルコンポーネント
    private var whisperKit: WhisperKit?
    
    // モデル設定
    private let modelName = "large-v3"  // tiny モデルの方が起動が速く小さいファイルでテストしやすい

    // 言語設定
    private let language = "ja" // 日本語文字起こし用
    
    // WhisperKitのダウンロード設定
    private let modelRepo = "argmaxinc/whisperkit-coreml" // 正式なリポジトリ名
    
    init() {
        setupWhisper()
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
    
    // アプリのコンテナ内のDocumentsフォルダのURLを取得
    private func getContainerDocumentsDirectory() -> URL {
        // コンテナ内のDocumentsフォルダのURLを取得
        let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return containerURL
    }
    
    // WhisperKitの初期設定
    private func setupWhisper() {
        // WhisperKitの初期化
        Task {
            do {
                // WhisperKitの設定を作成
                let config = WhisperKitConfig(
                    model: self.modelName,
                    modelRepo: self.modelRepo,
                    verbose: true,
                    logLevel: .debug,
                    download: true
                )
                
                // モデルを初期化
                let whisperKit = try await WhisperKit(config)
                
                // モデルの読み込み（すでにダウンロード済みの場合）
                do {
                    try await whisperKit.loadModels()
                    print("WhisperKitモデルを読み込みました")
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.whisperKit = whisperKit

                        // モデル読み込み成功の通知
                        NotificationCenter.default.post(
                            name: NSNotification.Name("WhisperModelLoaded"),
                            object: nil
                        )
                    }
                } catch {
                    print("既存のモデル読み込みに失敗しました: \(error.localizedDescription)")
                    
                    // モデルが存在しない場合は、モデルダウンロードが必要なことを通知する
                    DispatchQueue.main.async {
                        // モデルが必要なことをアプリに伝えるために通知を送信
                        NotificationCenter.default.post(
                            name: NSNotification.Name("WhisperModelDownloadNeeded"),
                            object: nil
                        )
                    }
                }
            } catch {
                print("WhisperKitの初期化に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    // 音声ファイルを文字起こしする
    func transcribeAudio(url: URL, completion: @escaping (Result<[TranscriptSegment], WhisperError>) -> Void) {        
        // ファイル形式を確認
        let fileExtension = url.pathExtension.lowercased()
        let directSupportedFormats = ["wav", "mp3", "m4a", "flac"]
        
        // WAV, MP3, M4A, FLACの場合は直接処理
        if directSupportedFormats.contains(fileExtension) {
            guard let whisperKit = self.whisperKit else {
                print("WhisperKitのインスタンスが初期化されていません。")
                completion(.failure(.modelLoadFailed))
                return
            }
            
            // 直接文字起こし処理を実行
            self.performTranscription(wavURL: url, whisperKit: whisperKit, completion: completion)
            return
        }
    }

    // 文字起こしを実行（WhisperKitを使用）
    private func performTranscription(wavURL: URL, whisperKit: WhisperKit, completion: @escaping (Result<[TranscriptSegment], WhisperError>) -> Void) {
        print("文字起こしを開始します: \(wavURL.path)")
        
        // 音声ファイルをロード
        Task {
            do {
                // 文字起こし設定
                let decodeOptions = DecodingOptions(
                    task: .transcribe,
                    language: self.language,
                    temperature: 0.0
                )
                
                print("transcribe メソッドを呼び出します")
                
                // 文字起こしを実行 - audioPathを使用
                let results = try await whisperKit.transcribe(
                    audioPath: wavURL.path,
                    decodeOptions: decodeOptions
                )
                
                print("transcribe メソッドが完了しました")
                
                // WhisperKitの結果からTranscriptSegmentを生成
                var segments: [TranscriptSegment] = []
                
                guard let result = results.first else {
                    print("文字起こし結果が空です")
                    DispatchQueue.main.async {
                        completion(.failure(.transcriptionFailed))
                    }
                    return
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
                
                print("セグメント数: \(segments.count)")
                
                // メインスレッドで結果を返す
                DispatchQueue.main.async {
                    completion(.success(segments))
                }
            } catch let error as NSError {
                print("文字起こし処理エラー: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    // エラーの種類に応じて適切なWhisperErrorに変換
                    if error.domain == "WhisperKit" {
                        if error.localizedDescription.contains("model") {
                            completion(.failure(.modelLoadFailed))
                        } else {
                            completion(.failure(.transcriptionFailed))
                        }
                    } else if error.localizedDescription.contains("cancelled") || 
                              error.localizedDescription.contains("stopped") {
                        completion(.failure(.operationStopped))
                    } else {
                        completion(.failure(.transcriptionFailed))
                    }
                }
            } catch {
                print("文字起こし処理エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.transcriptionFailed))
                }
            }
        }
    }
}
