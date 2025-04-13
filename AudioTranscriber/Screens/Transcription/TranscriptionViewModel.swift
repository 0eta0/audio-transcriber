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

    var currentModelName: String { get }
    var supportedModels: [String] { get }

    func loadAudioFile(url: URL) async
    func togglePlayback()
    func seekToPosition(_ position: Double)
    func seekRelative(seconds: Double)
    func transcribeAudio()
    func retranscribeAudio()
    func saveTranscription(to url: URL)
    func playFromSegment(_ segment: TranscriptSegment)
    func exportTranscriptionText() -> String
    func createDefaultFilename() -> String
    func resetAll()
    func autoScrollEnabled(with duration: TimeInterval?)
    func autoScrollDisabled()
    func handleDrop(providers: [NSItemProvider]) -> Bool
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
    @Published var transcribingProgress: TimeInterval = .zero
    @Published var currentSegmentID: UUID = UUID()
    @Published var error: WhisperError?

    // UI
    @Published var autoScrollEnabled: Bool = false
    private var forceAutoScrollEnabled: Bool = false
    private var forceAutoScrollDurationTimer: Timer?

    // 音声処理関連
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var whisperManager: WhisperManagerType?
    private var cancellables = Set<AnyCancellable>()
    
    // Model related properties
    var currentModelName: String {
        return whisperManager?.currentModel() ?? "base"
    }
    
    var supportedModels: [String] {
        return whisperManager?.supportedModel() ?? []
    }

    // MARK: - Initializer

    init(whisperManager: any WhisperManagerType) {
        self.whisperManager = whisperManager

        Task {
            do {
                try await whisperManager.setupWhisperIfNeeded(
                    modelName: whisperManager.currentModel(),
                    progressCallback: nil
                )
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
                // サポートされているオーディオファイル形式かチェック
                let supportedFormats = SupportAudioType.allCases.map { $0.rawValue }
                if !supportedFormats.contains(url.pathExtension.lowercased()) {
                    throw WhisperError.unsupportedFormat
                }
                
                // オーディオプレーヤーの読み込み
                try await loadAudioPlayer(with: tempURL)
            } catch let error as WhisperError {
                Task { @MainActor in
                    self.error = error
                }
            } catch {
                Task { @MainActor in
                    self.error = WhisperError.audioFileLoadFailed
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
                self.error = error
            } catch {
                self.error = WhisperError.transcriptionFailed
            }
            isTranscribing = false
        }
    }

    func retranscribeAudio() {
        Task { @MainActor [self] in
            resetTranscription()
            transcribeAudio()
        }
    }

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

    func exportTranscriptionText() -> String {
        transcribedSegments
            .map { segment in
                let timeString = formatTimeForExport(segment.startTime)
                return "[\(timeString)] \(segment.text)"
            }
            .joined(separator: "\n\n")
    }

    func formatTimeForExport(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }

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
    
    // ドラッグ＆ドロップの処理
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // 利用可能なタイプ識別子を確認
            let availableTypes = provider.registeredTypeIdentifiers
            // 使える識別子を探す
            let identifierToUse = availableTypes.first(where: { ident in
                return ident == "public.file-url" || 
                       ident == UTType.fileURL.identifier || 
                       ident == "public.url"
            }) ?? availableTypes.first
            
            if let identifierToUse = identifierToUse {
                provider.loadItem(forTypeIdentifier: identifierToUse) { item, error in
                    if error != nil { return }

                    var fileURL: URL? = nil
                    // 様々なデータ形式に対応
                    if let url = item as? URL {
                        fileURL = url
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        fileURL = url
                    } else if let string = item as? String, let url = URL(string: string) {
                        fileURL = url
                    }
                    // ファイルURLが取得できたら処理
                    if let url = fileURL {
                        // オーディオファイルかチェック
                        let supportedFormats = SupportAudioType.allCases.map { $0.rawValue }
                        if supportedFormats.contains(url.pathExtension.lowercased()) {
                            Task { @MainActor in
                                await self.loadAudioFile(url: url)
                            }
                        }
                    }
                }
                // 最初に成功した項目だけを処理
                return true
            }
        }
        return false
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
    
    // 通常の音声ファイルを読み込む
    private func loadAudioPlayer(with url: URL) async throws {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            
            guard let duration = audioPlayer?.duration else {
                throw WhisperError.audioFileLoadFailed
            }
            
            Task { @MainActor in
                self.duration = duration
                self.audioFile = url
                self.isFileLoaded = true
            }
        } catch {
            throw WhisperError.audioFileLoadFailed
        }
    }
}
