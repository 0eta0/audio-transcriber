import Foundation
import AVFoundation
import Combine
import SwiftUI
import AVKit

@MainActor
protocol TranscriptionViewModelType: ObservableObject, Sendable {

    var autoScrollEnabled: Bool { get set }

    var player: AVPlayer { get }

    var mediaFile: URL? { get set }
    var duration: TimeInterval { get set }
    var currentTime: TimeInterval { get set }
    var playbackProgress: Double { get set }
    var isPlaying: Bool { get set }
    var isFileLoaded: Bool { get set }
    var playbackSpeed: Float { get }
    var isPlayingVideo: Bool { get set }

    var transcribedSegments: [TranscriptSegment] { get set }
    var isTranscribing: Bool { get set }
    var transcribingProgress: TimeInterval { get set }
    var currentSegmentID: UUID { get set }
    var error: WhisperError? { get set }

    var currentModelName: String { get }
    var supportedModels: [String] { get }

    // Search related
    var searchText: String { get set }
    var filteredSegments: [TranscriptSegment] { get }

    func loadFile(url: URL) async
    func togglePlayback()
    func seekToPosition(_ position: Double)
    func seekRelative(seconds: Double)
    func transcribeAudio()
    func retranscribeAudio()
    func playFromSegment(_ segment: TranscriptSegment)
    func exportTranscriptionText() -> String
    func createDefaultFilename() -> String
    func resetAll()
    func autoScrollEnabled(with duration: TimeInterval?)
    func autoScrollDisabled()
    func handleDrop(providers: [NSItemProvider]) -> Bool
    func setPlaybackSpeed(_ speed: Float)
}

final class TranscriptionViewModel: TranscriptionViewModelType {

    // MARK: - Properties

    // media file related
    var player: AVPlayer = AVPlayer()
    var isPlayingVideo: Bool = false
    private let timeObserverQueue = DispatchQueue(label: "audio-tanscriber.time-observer")
    private var timeObserver: Any?

    @Published var mediaFile: URL?
    @Published var duration: TimeInterval = 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var playbackProgress: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var isFileLoaded: Bool = false
    @Published var playbackSpeed: Float = 1.0
    
    // Transcription related
    @Published var transcribedSegments: [TranscriptSegment] = []
    @Published var isTranscribing: Bool = false
    @Published var transcribingProgress: TimeInterval = .zero
    @Published var currentSegmentID: UUID = UUID()
    @Published var error: WhisperError?

    // UI
    @Published var autoScrollEnabled: Bool = false
    private var forceAutoScrollEnabled: Bool = false
    private var forceAutoScrollDurationTimer: Timer?

    // Search
    @Published var searchText: String = ""

    // WhisperKit related
    private var whisperManager: WhisperManagerType?
    private var cancellables = Set<AnyCancellable>()
    
    // Model related properties
    var currentModelName: String {
        return whisperManager?.currentModel() ?? "base"
    }
    
    var supportedModels: [String] {
        return whisperManager?.supportedModel() ?? []
    }

    // MARK: - Computed Properties

    var filteredSegments: [TranscriptSegment] {
        if searchText.isEmpty {
            return transcribedSegments
        } else {
            return transcribedSegments.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // MARK: - Initializer

    init(whisperManager: any WhisperManagerType) {
        self.whisperManager = whisperManager
        
        Task { @MainActor in
            do {
                try await whisperManager.setupWhisperIfNeeded(
                    modelName: whisperManager.currentModel(),
                    progressCallback: nil
                )
            } catch {
                self.error = WhisperError.failedToInitialize
            }
        }
        setup()
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    // MARK: - Public Functions

    // Load file
    func loadFile(url: URL) async {
        Task { @MainActor in
            stopPlayback()
            resetTranscription()

            do {
                // File security access processing and copying
                let tempURL = try await secureCopyFile(from: url)
                let supportedFormats = SupportMediaType.allCases.map { $0.rawValue }
                if !supportedFormats.contains(url.pathExtension.lowercased()) {
                    throw WhisperError.unsupportedFormat
                }
                
                // Load audio player
                try await loadPlayer(with: tempURL)
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

    // Toggle playback
    func togglePlayback() {
        Task { @MainActor in
            if isPlaying {
                pausePlayback()
            } else {
                startPlayback()
            }
        }
    }
    
    // Start playback
    func startPlayback() {
        guard !isPlaying else { return }

        Task { @MainActor in
            player.playImmediately(atRate: playbackSpeed)
            isPlaying = true
        }
    }
    
    // Pause playback
    func pausePlayback() {
        guard isPlaying else { return }

        Task { @MainActor in
            player.pause()
            isPlaying = false
        }
    }
    
    // Stop playback
    func stopPlayback() {
        Task { @MainActor in
            await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            player.pause()
            isPlaying = false
            updateCurrentTime(0)
        }
    }
    
    // Seek to position
    func seekToPosition(_ position: Double) {
        playbackProgress = position

        Task { @MainActor in
            let time = position * duration
            let target = CMTime(seconds: time, preferredTimescale: player.currentTime().timescale)
            await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
    
    // Seek relative (move forward/backward)
    func seekRelative(seconds: Double) {
        Task { @MainActor in
            // Move relative to the current position
            var time = player.currentTime().seconds + seconds
            // Restrict range
            time = max(0, min(duration, time))
            // Perform seek
            let target = CMTime(seconds: time, preferredTimescale: player.currentTime().timescale)
            await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func transcribeAudio() {
        guard let mediaFileURL = mediaFile, !isTranscribing else { return }

        Task { @MainActor in
            isTranscribing = true
            do {
                let result = try await self.whisperManager?.transcribe(url: mediaFileURL) { [weak self] progress in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.transcribingProgress = progress
                    }
                }
                if let result = result {
                    transcribedSegments = result
                }
            } catch _ as WhisperError {
                self.error = error
            } catch {
                self.error = WhisperError.transcriptionFailed
            }
            isTranscribing = false
        }
    }

    func retranscribeAudio() {
        Task { @MainActor in
            resetTranscription()
            transcribeAudio()
        }
    }

    func playFromSegment(_ segment: TranscriptSegment) {
        Task { @MainActor in
            currentSegmentID = segment.id
            // Seek to the segment's start time
            let target = CMTime(seconds: segment.startTime, preferredTimescale: player.currentTime().timescale)
            await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
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
        
        if let fileName = mediaFile?.lastPathComponent.components(separatedBy: ".").first {
            return "\(fileName)_stt_\(dateString).txt"
        } else {
            return "\(dateString).txt"
        }
    }

    func resetAll() {
        Task { @MainActor in
            stopPlayback()
            resetTranscription()
            whisperManager?.cancelTranscribeIfNeeded()
            mediaFile = nil
            duration = 0.0
            currentTime = 0.0
            playbackProgress = 0.0
            isFileLoaded = false
            transcribingProgress = 0
            player.replaceCurrentItem(with: nil)
        }
    }

    func autoScrollEnabled(with duration: TimeInterval?) {
        autoScrollEnabled = true
        guard let duration = duration else { return }

        forceAutoScrollEnabled = true
        forceAutoScrollDurationTimer?.invalidate()
        forceAutoScrollDurationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.forceAutoScrollEnabled = false
            }
        }
    }

    func autoScrollDisabled() {
        guard !forceAutoScrollEnabled else { return }

        autoScrollEnabled = false
    }
    
    // Drag & drop processing
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Check available type identifiers
            let availableTypes = provider.registeredTypeIdentifiers
            // Find usable identifier
            let identifierToUse = availableTypes.first(where: { ident in
                return ident == "public.file-url" ||
                       ident == UTType.fileURL.identifier ||
                       ident == "public.url"
            }) ?? availableTypes.first
            
            if let identifierToUse = identifierToUse {
                provider.loadItem(forTypeIdentifier: identifierToUse) { item, error in
                    if error != nil { return }

                    var fileURL: URL? = nil
                    // Support various data formats
                    if let url = item as? URL {
                        fileURL = url
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        fileURL = url
                    } else if let string = item as? String, let url = URL(string: string) {
                        fileURL = url
                    }
                    // Process if file URL is obtained
                    if let url = fileURL {
                        let supportedFormats = SupportMediaType.allCases.map { $0.rawValue }
                        if supportedFormats.contains(url.pathExtension.lowercased()) {
                            Task { @MainActor in
                                await self.loadFile(url: url)
                            }
                        }
                    }
                }
                // Process only the first successful item
                return true
            }
        }
        return false
    }

    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed // Always update the desired speed
        player.rate = speed
        // pause if do not want to play automatically
        if !isPlaying {
            player.pause()
        }
    }

    // MARK: - Private Functions
    
    private func setup() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 1_000)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: timeObserverQueue) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateCurrentTime(ceil(time.seconds * 100) / 100)
            }
        }
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            .sink { [weak self] _ in
                self?.stopPlayback()
            }
            .store(in: &cancellables)
    }

    // Reset transcription
    private func resetTranscription() {
        transcribedSegments = []
        currentSegmentID = UUID()
    }

    // Update current time
    private func updateCurrentTime(_ time: TimeInterval) {
        currentTime = time
        playbackProgress = time / duration
        // Update current segment
        updateCurrentSegment(for: time)
    }
    
    // Update current segment
    private func updateCurrentSegment(for time: TimeInterval) {
        for segment in transcribedSegments {
            if time >= segment.startTime && time <= segment.endTime {
                currentSegmentID = segment.id
                return
            }
        }
    }

    // Format time
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - Double(Int(time))) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }

    // Access security-scoped resource and copy temporary file
    private func secureCopyFile(from url: URL) async throws -> URL {
        // Start accessing security-scoped resource
        let accessGranted = url.startAccessingSecurityScopedResource()
        
        defer {
            // Release access rights when the function ends
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Create a temporary copy to maintain access rights
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tempURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)

        try? FileManager.default.removeItem(at: tempURL)
        try FileManager.default.copyItem(at: url, to: tempURL)

        return tempURL
    }
    
    // Load regular media file
    private func loadPlayer(with url: URL) async throws {
        do {
            let currentSpeed = player.rate
            let asset = AVURLAsset(url: url)
            let item = AVPlayerItem(asset: asset)
            let duration = try await asset.load(.duration)
            isPlayingVideo = isVideoFile(url: url)

            player.replaceCurrentItem(with: item)
            player.rate = currentSpeed
            player.pause()

            self.duration = duration.seconds
            mediaFile = url
            isFileLoaded = true
        } catch {
            throw WhisperError.audioFileLoadFailed
        }
    }
    
    private func isVideoFile(url: URL) -> Bool {
        return SupportMediaType.allVideoTypes
            .map({ $0.rawValue })
            .contains(url.pathExtension.lowercased())
    }
}
