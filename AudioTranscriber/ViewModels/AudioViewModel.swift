import Foundation
import AVFoundation
import Combine

class AudioViewModel: ObservableObject {
    // 音声ファイル関連
    @Published var audioFile: URL?
    @Published var duration: TimeInterval = 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var playbackProgress: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var isFileLoaded: Bool = false  // ファイル読み込み状態を追加
    
    // 文字起こし関連
    @Published var transcribedSegments: [TranscriptSegment] = []
    @Published var isTranscribing: Bool = false
    @Published var currentSegmentID: UUID?
    @Published var isModelReady: Bool = false
    @Published var isModelDownloading: Bool = false
    
    // 音声処理関連
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var whisper: WhisperManager?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.whisper = WhisperManager()
        setupNotifications()
    }
    
    private func setupNotifications() {
        // モデルのダウンロードが必要な通知を受け取る
        NotificationCenter.default.publisher(for: NSNotification.Name("WhisperModelDownloadNeeded"))
            .sink { [weak self] _ in
                self?.isModelReady = false
            }
            .store(in: &cancellables)
        
        // モデル読み込み完了の通知を受け取る
        NotificationCenter.default.publisher(for: NSNotification.Name("WhisperModelLoaded"))
            .sink { [weak self] _ in
                self?.isModelReady = true
                self?.isModelDownloading = false
            }
            .store(in: &cancellables)
    }

    // モデルのダウンロードを開始
    func downloadWhisperModel(completion: ((Bool) -> Void)? = nil) {
        guard !isModelDownloading else { return }
        
        isModelDownloading = true
    }
    
    // 音声ファイルを読み込む
    func loadAudioFile(url: URL) {
        stopPlayback()
        resetTranscription()
        
        // ファイルのセキュリティスコープドアクセスを取得
        guard url.startAccessingSecurityScopedResource() else {
            print("ファイルにアクセスできませんでした")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // アクセス権を維持するために一時的なコピーを作成
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tempURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            try? FileManager.default.removeItem(at: tempURL)
            try FileManager.default.copyItem(at: url, to: tempURL)
            
            // ファイルの種類を確認
            let isVideoFile = url.pathExtension.lowercased() == "mp4"
            
            if isVideoFile {
                // MP4の場合は音声トラックをプレビュー用に抽出
                let asset = AVAsset(url: tempURL)
                let audioTracks = asset.tracks(withMediaType: .audio)
                
                if !audioTracks.isEmpty {
                    // 音声プレーヤーを初期化（AVAudioPlayerではMP4から直接再生できないため）
                    do {
                        // AVPlayerを使用して音声を再生（MP4対応）
                        let playerItem = AVPlayerItem(url: tempURL)
                        let player = AVPlayer(playerItem: playerItem)
                        
                        // 音声の長さを取得
                        if let playerItem = player.currentItem {
                            let duration = playerItem.asset.duration
                            DispatchQueue.main.async {
                                self.duration = CMTimeGetSeconds(duration)
                                self.audioFile = tempURL
                                self.isFileLoaded = true  // 明示的にロード状態を更新
                            }
                        }
                        
                        print("MP4ファイル読み込み: \(tempURL.path)")
                    } catch {
                        print("MP4音声設定エラー: \(error.localizedDescription)")
                    }
                } else {
                    print("MP4ファイルに音声トラックが見つかりません")
                }
            } else {
                // 通常の音声ファイルの場合
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
                    audioPlayer?.prepareToPlay()
                    
                    DispatchQueue.main.async {
                        self.duration = self.audioPlayer?.duration ?? 0.0
                        self.audioFile = tempURL
                        self.isFileLoaded = true  // 明示的にロード状態を更新
                    }
                    
                    print("音声ファイルを読み込みました: \(tempURL.path)")
                } catch {
                    print("AVAudioPlayer初期化エラー: \(error.localizedDescription)")
                }
            }
        } catch {
            print("音声ファイル読み込みエラー: \(error.localizedDescription)")
        }
    }
    
    // 再生／一時停止を切り替え
    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }
    
    // 再生開始
    func startPlayback() {
        guard let player = audioPlayer, !isPlaying else { return }
        
        player.play()
        isPlaying = true
        
        // タイマーで現在の再生位置を更新
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.updateCurrentTime(player.currentTime)
        }
    }
    
    // 一時停止
    func pausePlayback() {
        guard isPlaying else { return }
        
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    // 再生停止
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        timer?.invalidate()
        updateCurrentTime(0)
    }
    
    // 再生位置をシーク
    func seekToPosition(_ position: Double) {
        guard let player = audioPlayer else { return }
        
        let targetTime = position * duration
        player.currentTime = targetTime
        updateCurrentTime(targetTime)
        
        // セグメントIDも更新
        updateCurrentSegment(for: targetTime)
    }
    
    // 相対的にシーク（前後に移動）
    func seekRelative(seconds: Double) {
        guard let player = audioPlayer else { return }
        
        // 現在位置から相対的に移動
        var newTime = player.currentTime + seconds
        
        // 範囲を制限
        newTime = max(0, min(duration, newTime))
        
        // シーク実行
        player.currentTime = newTime
        updateCurrentTime(newTime)
        
        // セグメントIDも更新
        updateCurrentSegment(for: newTime)
    }
    
    // 現在の時間を更新
    private func updateCurrentTime(_ time: TimeInterval) {
        currentTime = time
        playbackProgress = time / duration
        
        // 現在のセグメントを更新
        updateCurrentSegment(for: time)
    }
    
    // 特定のセグメントから再生
    func playFromSegment(_ segment: TranscriptSegment) {
        guard let player = audioPlayer else { return }
        
        // セグメントの開始時間にシーク
        player.currentTime = segment.startTime
        updateCurrentTime(segment.startTime)
        
        // 再生開始
        startPlayback()
    }
    
    // 現在のセグメントを更新
    private func updateCurrentSegment(for time: TimeInterval) {
        for segment in transcribedSegments {
            if time >= segment.startTime && time <= segment.endTime {
                currentSegmentID = segment.id
                return
            }
        }
        currentSegmentID = nil
    }
    
    // 文字起こしをリセット
    func resetTranscription() {
        transcribedSegments = []
        currentSegmentID = nil
    }
    
    // 音声を文字起こし
    func transcribeAudio() {
        guard let audioFileURL = audioFile, !isTranscribing else { return }
        
        isTranscribing = true
        
        // モデルの状態を確認
        if !isModelReady {
            print("モデルが準備できていません。ダウンロードを開始します。")
            
            // モデルをダウンロード
            downloadWhisperModel { [weak self] success in
                if success {
                    // ダウンロードに成功したら文字起こしを実行
                    self?.performTranscription(audioFileURL: audioFileURL)
                } else {
                    // ダウンロードに失敗
                    DispatchQueue.main.async {
                        self?.isTranscribing = false
                        
                        // エラーメッセージを表示する通知を送信
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TranscriptionError"),
                            object: nil,
                            userInfo: ["error": WhisperError.modelLoadFailed]
                        )
                    }
                }
            }
        } else {
            // モデルが準備できている場合は直接実行
            performTranscription(audioFileURL: audioFileURL)
        }
    }
    
    // 実際の文字起こし処理
    private func performTranscription(audioFileURL: URL) {
        // WhisperManager を使って文字起こし
        whisper?.transcribeAudio(url: audioFileURL) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isTranscribing = false
                
                switch result {
                case .success(let segments):
                    self.transcribedSegments = segments
                case .failure(let error):
                    print("文字起こしエラー: \(error.localizedDescription)")
                    
                    // エラーメッセージを表示する通知を送信
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TranscriptionError"),
                        object: nil,
                        userInfo: ["error": error]
                    )
                    
                    // モデルロードエラーの場合はダウンロード画面を表示するための通知を送信
                    if case WhisperError.modelLoadFailed = error {
                        self.isModelReady = false
                        NotificationCenter.default.post(
                            name: NSNotification.Name("WhisperModelDownloadNeeded"),
                            object: nil
                        )
                    }
                }
            }
        }
    }
    
    // 文字起こし結果を保存
    func saveTranscription(to url: URL) {
        guard !transcribedSegments.isEmpty else { return }
        
        var text = ""
        for segment in transcribedSegments {
            let timeStr = formatTime(segment.startTime)
            text += "[\(timeStr)] \(segment.text)\n"
        }
        
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("文字起こし保存エラー: \(error.localizedDescription)")
        }
    }
    
    // 時間のフォーマット
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - Double(Int(time))) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }
}
