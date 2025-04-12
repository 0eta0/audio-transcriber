import Foundation
import AVFoundation
import Combine

protocol TranscriptionViewModelType: ObservableObject {

    var audioFile: URL? { get set }
    var duration: TimeInterval { get set }
    var currentTime: TimeInterval { get set }
    var playbackProgress: Double { get set }
    var isPlaying: Bool { get set }
    var isFileLoaded: Bool { get set }

    var transcribedSegments: [TranscriptSegment] { get set }
    var isTranscribing: Bool { get set }
    var currentSegmentID: UUID { get set }
    var error: WhisperError? { get set }

    func loadAudioFile(url: URL) async
    func togglePlayback()
    func startPlayback()
    func pausePlayback()
    func stopPlayback()
    func seekToPosition(_ position: Double)
    func seekRelative(seconds: Double)
    func transcribeAudio()
    func saveTranscription(to url: URL)
    func playFromSegment(_ segment: TranscriptSegment)
}

final class TranscriptionViewModel: TranscriptionViewModelType {

    // MARK: - Properties

    // 音声ファイル関連
    @Published var audioFile: URL?
    @Published var duration: TimeInterval = 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var playbackProgress: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var isFileLoaded: Bool = false
    
    // 文字起こし関連
    @Published var transcribedSegments: [TranscriptSegment] = []
    @Published var isTranscribing: Bool = false
    @Published var currentSegmentID: UUID = UUID()
    @Published var error: WhisperError?

    // 音声処理関連
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var whisperManager: WhisperManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer

    init() {
        whisperManager = WhisperManager()
        Task {
            do {
                try await whisperManager?.setupWhisperIfNeeded()
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    // MARK: - Public Functions

    // 音声ファイルを読み込む
    func loadAudioFile(url: URL) async {
        Task { @MainActor in
            stopPlayback()
            resetTranscription()

            do {
                // ファイルのセキュリティアクセス処理とコピー
                let tempURL = try await secureCopyFile(from: url)
                // ファイルの種類に応じた処理
                if url.pathExtension.lowercased() == "mp4" {
                    try await loadVideoFile(at: tempURL)
                } else {
                    try await loadAudioPlayer(with: tempURL)
                }
            } catch let error as WhisperError {
                print("音声ファイル読み込みエラー: \(error.localizedDescription)")
                Task { @MainActor in
                    self.error = error
                }
            } catch {
                Task { @MainActor in
                    self.error = WhisperError.fileLoadError
                }
            }
        }
    }

    // 再生／一時停止を切り替え
    func togglePlayback() {
        Task { @MainActor in
            if isPlaying {
                pausePlayback()
            } else {
                startPlayback()
            }
        }
    }
    
    // 再生開始
    func startPlayback() {
        guard let player = audioPlayer, !isPlaying else { return }

        Task { @MainActor in
            player.play()
            isPlaying = true

            // タイマーで現在の再生位置を更新
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let player = self?.audioPlayer else { return }
                self?.updateCurrentTime(player.currentTime)
            }
        }
    }
    
    // 一時停止
    func pausePlayback() {
        guard isPlaying else { return }

        Task { @MainActor in
            audioPlayer?.pause()
            isPlaying = false
            timer?.invalidate()
        }
    }
    
    // 再生停止
    func stopPlayback() {
        Task { @MainActor in
            audioPlayer?.stop()
            isPlaying = false
            timer?.invalidate()
            updateCurrentTime(0)
        }
    }
    
    // 再生位置をシーク
    func seekToPosition(_ position: Double) {
        guard let player = audioPlayer else { return }

        Task { @MainActor [self] in
            let targetTime = position * duration
            player.currentTime = targetTime
            updateCurrentTime(targetTime)
        }
    }
    
    // 相対的にシーク（前後に移動）
    func seekRelative(seconds: Double) {
        guard let player = audioPlayer else { return }

        Task { @MainActor [self] in
            // 現在位置から相対的に移動
            var newTime = player.currentTime + seconds
            // 範囲を制限
            newTime = max(0, min(duration, newTime))
            // シーク実行
            player.currentTime = newTime
            updateCurrentTime(newTime)
        }
    }

    // 音声を文字起こし
    func transcribeAudio() {
        guard let audioFileURL = audioFile, !isTranscribing else { return }

        Task { @MainActor [self] in
            isTranscribing = true
            do {
                if let result = try await self.whisperManager?.transcribe(url: audioFileURL) {
                    transcribedSegments = result
                }
            } catch let e as WhisperError {
                print("文字起こしエラー: \(e.localizedDescription)")
                self.error = error
            } catch {
                self.error = .unknown
            }
            isTranscribing = false
        }
    }

    // 文字起こし結果を保存
    func saveTranscription(to url: URL) {
        guard !transcribedSegments.isEmpty else { return }

        Task { @MainActor [self] in
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
    }

    // 特定のセグメントから再生
    func playFromSegment(_ segment: TranscriptSegment) {
        guard let player = audioPlayer else { return }

        Task { @MainActor [self] in
            // セグメントの開始時間にシーク
            player.currentTime = segment.startTime
            updateCurrentTime(segment.startTime)
            // 再生開始
            startPlayback()
        }
    }

    // MARK: - Private Functions

    // 文字起こしをリセット
    private func resetTranscription() {
        transcribedSegments = []
        currentSegmentID = UUID()
    }

    // 現在の時間を更新
    private func updateCurrentTime(_ time: TimeInterval) {
        currentTime = time
        playbackProgress = time / duration
        
        // 現在のセグメントを更新
        updateCurrentSegment(for: time)
    }
    
    // 現在のセグメントを更新
    private func updateCurrentSegment(for time: TimeInterval) {
        for segment in transcribedSegments {
            if time >= segment.startTime && time <= segment.endTime {
                currentSegmentID = segment.id
                return
            }
        }
        currentSegmentID = UUID()
    }

    // 時間のフォーマット
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - Double(Int(time))) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }

    // セキュリティスコープドリソースへのアクセスと一時ファイルのコピー
    private func secureCopyFile(from url: URL) async throws -> URL {
        // アクセス権を維持するために一時的なコピーを作成
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tempURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)

        try? FileManager.default.removeItem(at: tempURL)
        try FileManager.default.copyItem(at: url, to: tempURL)
        
        return tempURL
    }
    
    // ビデオファイルから音声トラックを読み込む
    private func loadVideoFile(at url: URL) async throws {
        let asset = AVAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard !audioTracks.isEmpty else {
            throw WhisperError.noAudioTrackFound
        }
        
        // AVPlayerを使用して音声を再生（MP4対応）
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        
        // 音声の長さを取得
        guard let playerItem = player.currentItem else {
            throw WhisperError.fileLoadError
        }
        
        let duration = try await playerItem.asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        
        Task { @MainActor in
            self.duration = seconds
            self.audioFile = url
            self.isFileLoaded = true
        }
        print("MP4ファイル読み込み: \(url.path)")
    }
    
    // 通常の音声ファイルを読み込む
    private func loadAudioPlayer(with url: URL) async throws {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            
            guard let duration = audioPlayer?.duration else {
                throw WhisperError.fileLoadError
            }
            
            Task { @MainActor in
                self.duration = duration
                self.audioFile = url
                self.isFileLoaded = true
            }
            print("音声ファイルを読み込みました: \(url.path)")
        } catch {
            throw WhisperError.fileLoadError
        }
    }
}
