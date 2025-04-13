import Foundation
import AVFoundation
import Combine

protocol TranscriptionViewModelType: ObservableObject, Sendable {

    var autoScrollEnabled: Bool { get set }

    var audioFile: URL? { get set }
    var duration: TimeInterval { get set }
    var currentTime: TimeInterval { get set }
    var playbackProgress: Double { get set }
    var isPlaying: Bool { get set }
    var isFileLoaded: Bool { get set }

    var transcribedSegments: [TranscriptSegment] { get set }
    var isTranscribing: Bool { get set }
    var transcribingProgress: TimeInterval { get set }
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
    
    // Added new methods
    func exportTranscriptionText() -> String
    func formatTimeForExport(_ time: TimeInterval) -> String
    func createDefaultFilename() -> String
    func resetAll()
    func autoScrollEnabled(with duration: TimeInterval?)
    func autoScrollDisabled()
}

final class TranscriptionViewModel: TranscriptionViewModelType {

    // MARK: - Properties

    // UI
    @Published var autoScrollEnabled: Bool = false

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
    @Published var transcribingProgress: TimeInterval = .zero
    @Published var currentSegmentID: UUID = UUID()
    @Published var error: WhisperError?

    // UI
    private var forceAutoScrollEnabled: Bool = false
    private var forceAutoScrollDurationTimer: Timer?

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
                let supports = ["mp4"]
                if supports.contains(url.pathExtension.lowercased()) {
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
                let result = try await self.whisperManager?.transcribe(url: audioFileURL) { [weak self] progress in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.transcribingProgress = progress
                    }
                }
                if let result = result {
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
            currentSegmentID = segment.id
            // セグメントの開始時間にシーク
            player.currentTime = segment.startTime
            updateCurrentTime(segment.startTime)
            // 再生開始
            startPlayback()
        }
    }
    
    // Export transcription text
    func exportTranscriptionText() -> String {
        transcribedSegments
            .map { segment in
                let timeString = formatTimeForExport(segment.startTime)
                return "[\(timeString)] \(segment.text)"
            }
            .joined(separator: "\n\n")
    }

    // Format time for export
    func formatTimeForExport(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }

    // Create default filename
    func createDefaultFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
        let dateString = dateFormatter.string(from: Date())
        
        if let fileName = audioFile?.lastPathComponent.components(separatedBy: ".").first {
            return "\(fileName)_文字起こし_\(dateString).txt"
        } else {
            return "文字起こし_\(dateString).txt"
        }
    }

    // Reset all loaded data and transcription
    func resetAll() {
        Task { @MainActor in
            stopPlayback()
            resetTranscription()
            audioFile = nil
            duration = 0.0
            currentTime = 0.0
            playbackProgress = 0.0
            isFileLoaded = false
            transcribingProgress = 0
            audioPlayer = nil
        }
    }

    func autoScrollEnabled(with duration: TimeInterval?) {
        autoScrollEnabled = true
        guard let duration = duration else { return }

        forceAutoScrollEnabled = true
        forceAutoScrollDurationTimer?.invalidate()
        forceAutoScrollDurationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.forceAutoScrollEnabled = false
        }
    }

    func autoScrollDisabled() {
        guard !forceAutoScrollEnabled else { return }

        autoScrollEnabled = false
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
        // セキュリティスコープドリソースへのアクセスを開始
        let accessGranted = url.startAccessingSecurityScopedResource()
        
        defer {
            // 関数が終了するときにアクセス権を解放
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
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
