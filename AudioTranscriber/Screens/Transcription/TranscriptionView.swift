import SwiftUI
import AVFoundation

struct TranscriptionView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @Environment(\.dependency) private var dependency

    @StateObject var viewModel: ViewModel
    
    @State private var isFilePickerPresented = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showSetupModal = true

    // MARK: Lifecycle

    var body: some View {
        if let dependency = dependency {
            ZStack {
                if viewModel.isFileLoaded {
                    // ファイルが読み込まれている場合の通常のレイアウト
                    VStack(spacing: 0) {
                        ToolbarView(
                            viewModel: viewModel,
                            isFilePickerPresented: $isFilePickerPresented,
                            showingAlert: $showingAlert,
                            alertMessage: $alertMessage,
                            showSetupModal: $showSetupModal
                        )

                        Divider()

                        VStack(spacing: 0) {
                            TranscriptionContentView(viewModel: viewModel)

                            Divider()

                            AudioPlayerView(viewModel: viewModel)
                        }
                    }
                } else {
                    // ファイルが読み込まれていない場合の初期画面
                    FileLoadingPromptView(
                        showSetupModal: $showSetupModal,
                        isFilePickerPresented: $isFilePickerPresented,
                        viewModel: viewModel
                    )
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button(L10n.Common.okButton, role: .cancel) {}
            }
            .sheet(isPresented: $showSetupModal) {
                let setupViewModel = SetupViewModel(whisperManager: dependency.whisperManager)
                SetupView(viewModel: setupViewModel, showSetupModal: $showSetupModal)
            }
            .fileImporter(
                isPresented: $isFilePickerPresented,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        return
                    }
                    Task { @MainActor in
                        await viewModel.loadAudioFile(url: url)
                    }
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - Subviews

// ツールバーコンポーネント
private struct ToolbarView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject var viewModel: ViewModel

    @Binding var isFilePickerPresented: Bool
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    @Binding var showSetupModal: Bool

    @State private var showingSavePanel = false
    @State private var showingResetConfirmation = false
    @State private var showingRetranscribeConfirmation = false

    // MARK: Lifecycle
    
    var body: some View {
        HStack {
            Text(viewModel.audioFile?.lastPathComponent ?? L10n.TranscriptionView.untitled)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            
            Button(action: {
                showSetupModal = true
            }) {
                Label(L10n.TranscriptionView.selectModel, systemImage: "brain")
            }
            .help(L10n.TranscriptionView.selectModelHelp)
            .buttonStyle(.bordered)
            
            if !viewModel.transcribedSegments.isEmpty {
                Button(action: {
                    showingRetranscribeConfirmation = true
                }) {
                    Label(L10n.TranscriptionView.retranscribe, systemImage: "arrow.triangle.2.circlepath")
                }
                .help(L10n.TranscriptionView.retranscribeHelp)
                .buttonStyle(.bordered)
                .confirmationDialog(
                    L10n.TranscriptionView.retranscribeConfirmationMessage,
                    isPresented: $showingRetranscribeConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.TranscriptionView.retranscribeConfirmationButton, role: .destructive) {
                        viewModel.retranscribeAudio()
                    }
                    Button(L10n.Common.cancelButton, role: .cancel) {}
                }
                
                Button(action: {
                    showingSavePanel = true
                }) {
                    Label(L10n.TranscriptionView.saveAsTextFile, systemImage: "arrow.down.doc")
                }
                .buttonStyle(.borderedProminent)
                .fileExporter(
                    isPresented: $showingSavePanel,
                    document: TranscriptionTextDocument(content: viewModel.exportTranscriptionText()),
                    contentType: .plainText,
                    defaultFilename: viewModel.createDefaultFilename()
                ) { result in
                    switch result {
                    case .success:
                        alertMessage = L10n.TranscriptionView.exportSuccessMessage
                        showingAlert = true
                    case .failure(let error):
                        alertMessage = L10n.TranscriptionView.exportErrorMessageFormat(error.localizedDescription)
                        showingAlert = true
                    }
                }
            }
            
            Button(action: {
                showingResetConfirmation = true
            }) {
                Label(L10n.TranscriptionView.reset, systemImage: "arrow.counterclockwise")
            }
            .confirmationDialog(
                L10n.TranscriptionView.resetConfirmationMessage,
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.TranscriptionView.resetConfirmationButton, role: .destructive) {
                    viewModel.resetAll()
                }
                Button(L10n.Common.cancelButton, role: .cancel) {}
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// オーディオプレーヤーコンポーネント
private struct AudioPlayerView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject var viewModel: ViewModel
    @State private var isDragging = false
    @State private var sliderPosition: CGFloat = 0
    
    // Available playback speeds
    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    // MARK: Lifecycle
    
    var body: some View {
        HStack(alignment: .center) {
            Button(action: {
                viewModel.togglePlayback()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.space, modifiers: [])

            Spacer()
                .frame(width: 16)

            Button(action: {
                viewModel.seekRelative(seconds: -10)
            }) {
                Image(systemName: "gobackward.10")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button(action: {
                viewModel.seekRelative(seconds: 10)
            }) {
                Image(systemName: "goforward.10")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.rightArrow, modifiers: [])

            Spacer()
                .frame(width: 16)
            
            // Playback speed control
            Menu {
                ForEach(speedOptions, id: \.self) { speed in
                    Button(action: {
                        viewModel.setPlaybackSpeed(speed)
                    }) {
                        HStack {
                            if viewModel.playbackSpeed == speed {
                                Image(systemName: "checkmark")
                            }
                            Text("\(speed, specifier: "%.2f")x")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .frame(width: 20, height: 20)
                    Text("\(viewModel.playbackSpeed, specifier: "%.2f")x")
                        .font(.caption)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()
                .frame(width: 16)

            VStack(spacing: 2) {
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        Slider(value: $sliderPosition, in: 0...1) { editing in
                            isDragging = editing
                            if !editing {
                                viewModel.seekToPosition(sliderPosition)
                            }
                        }
                        .zIndex(1)
                        .onChange(of: viewModel.playbackProgress, { _, value in
                            if !isDragging {
                                sliderPosition = value
                            }
                        })

                        if isDragging {
                            SeekTooltip(time: viewModel.duration * sliderPosition)
                                .zIndex(2)
                        }
                    }
                }
                .frame(height: 24)

                HStack {
                    Text(formatTime(viewModel.currentTime))
                    Spacer()
                    Text(formatTime(viewModel.duration))
                }
                .font(.caption)
            }
            .padding(.top, 20)
        }
        .padding(.all, 24)
        .padding(.top, 0)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // 時間のフォーマット関数
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return L10n.TranscriptionView.timeFormat(minutes, seconds)
    }
}

// シークバーの時間表示用ツールチップ
private struct SeekTooltip: View {

    let time: TimeInterval
    
    var body: some View {
        Text(formatTime(time))
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .frame(height: 32)
            .offset(y: -32)
    }
    
    // 時間のフォーマット関数
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return L10n.TranscriptionView.timeFormat(minutes, seconds)
    }
}

// 文字起こし表示コンポーネント
private struct TranscriptionContentView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject var viewModel: ViewModel

    // MARK: Lifecycle
    
    var body: some View {
        ScrollViewReader { scrollView in
            ZStack(alignment: .bottomTrailing) {
                VStack {
                    if viewModel.transcribedSegments.isEmpty {
                        EmptyTranscriptionView(viewModel: viewModel)
                    } else {
                        TranscriptionListView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))

                if !viewModel.autoScrollEnabled && !viewModel.transcribedSegments.isEmpty {
                    Button(action: {
                        viewModel.autoScrollEnabled(with: 1.0)
                        withAnimation {
                            scrollView.scrollTo(viewModel.currentSegmentID, anchor: .center)
                        }
                    }) {
                        Label(L10n.TranscriptionView.showCurrentLocation, systemImage: "text.insert")
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.borderless)
                    .padding(16)
                }
            }
            .onChange(of: viewModel.currentSegmentID) { _, id in
                if viewModel.autoScrollEnabled {
                    viewModel.autoScrollEnabled(with: 1.0)
                    withAnimation {
                        scrollView.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}

// 文字起こしがない場合の表示
private struct EmptyTranscriptionView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject var viewModel: ViewModel

    // MARK: Lifecycle
    
    var body: some View {
        VStack {
            if viewModel.isTranscribing {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(L10n.TranscriptionView.transcribing)
                        .padding(.top)
                    
                    // Progress bar to show transcription progress
                    VStack(alignment: .center, spacing: 8) {
                        HStack {
                            Text("\(Int(viewModel.transcribingProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(viewModel.transcribingProgress * viewModel.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("/")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(viewModel.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ProgressView(value: viewModel.transcribingProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(width: 300)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                }
            } else {
                Text(L10n.TranscriptionView.noTranscription)
                    .foregroundColor(.secondary)
                
                if viewModel.isFileLoaded, let _ = viewModel.audioFile {
                    Button(L10n.TranscriptionView.startTranscription) {
                        viewModel.transcribeAudio()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.headline)
                    .padding(.top, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Time format function for progress display
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return L10n.TranscriptionView.timeFormat(minutes, seconds)
    }
}

// 文字起こしリスト表示
private struct TranscriptionListView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject var viewModel: ViewModel

    @State private var previousOffset: CGFloat = 0

    // MARK: Lifecycle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.transcribedSegments) { segment in
                    TranscriptSegmentView(
                        segment: segment,
                        isActive: $viewModel.currentSegmentID.wrappedValue == segment.id
                    )
                    .id(segment.id)
                    .onTapGesture {
                        viewModel.autoScrollEnabled(with: 1.0)
                        viewModel.playFromSegment(segment)
                    }
                }
            }
            .padding()
            .background(GeometryReader {
                Color.clear.preference(
                    key: OffsetPreferenceKey.self,
                    value: $0.frame(in: .global).origin.y
                )
            })
        }
        .onPreferenceChange(OffsetPreferenceKey.self) { offset in
            let delta = abs(offset - previousOffset) / 100
            previousOffset = offset
            if delta > 0.3 {
                viewModel.autoScrollDisabled()
            }
        }
    }
}


private struct OffsetPreferenceKey: PreferenceKey {

    typealias Value = CGFloat

    static var defaultValue = CGFloat.zero

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

// 文字起こしのセグメント表示用ビュー
private struct TranscriptSegmentView: View {

    // MARK: Properties
    
    // Model Data
    var segment: TranscriptSegment
    var isActive: Bool
    
    // MARK: Lifecycle
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(formatTime(segment.startTime))
                .frame(width: 100, alignment: .leading)
                .multilineTextAlignment(.leading)
                .foregroundColor(isActive ? .primary : .secondary)

            Text(segment.text)
                .foregroundColor(isActive ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .font(.body)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    // MARK: Private Functions

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return L10n.TranscriptionView.timeFormat(minutes, seconds)
    }
}

// ファイル読み込み前の初期画面
private struct FileLoadingPromptView<ViewModel: TranscriptionViewModelType>: View {
    
    // MARK: Properties

    @Binding var showSetupModal: Bool
    @Binding var isFilePickerPresented: Bool
    @ObservedObject var viewModel: ViewModel
    @State private var isDraggingOver = false

    // MARK: Lifecycle
    
    var body: some View {
        VStack {
            if isDraggingOver {
                DragOverlayView()
            } else {
                VStack {
                    audioInputView()
                    changeModel()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onDrop(of: [.audio], isTargeted: $isDraggingOver) { providers in
            _ = viewModel.handleDrop(providers: providers)
            return true
        }
    }

    // MARK: Private Functions

    private func audioInputView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text(L10n.TranscriptionView.dragAndDropAudioFile)
                .font(.title2)
                .fontWeight(.medium)

            Text(L10n.TranscriptionView.or)
                .foregroundColor(.secondary)

            Button(action: {
                isFilePickerPresented = true
            }) {
                Label(L10n.TranscriptionView.selectAudioFile, systemImage: "folder")
                    .padding()
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                .background(Color(NSColor.windowBackgroundColor))
        )
        .padding(40)
    }

    private func changeModel() -> some View {
        Button(action: {
            showSetupModal = true
        }) {
            Label(L10n.TranscriptionView.selectModel, systemImage: "brain")
        }
        .help(L10n.TranscriptionView.selectModelHelp)
        .buttonStyle(.bordered)
    }
}

// ドラッグオーバーレイ表示
private struct DragOverlayView: View {

    // MARK: Lifecycle
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.accentColor, lineWidth: 2)
            .background(Color.accentColor.opacity(0.1))
            .overlay(
                VStack {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                    Text(L10n.TranscriptionView.dropAudioFileHere)
                        .font(.headline)
                }
                .foregroundColor(.accentColor)
            )
            .padding(20)
    }
}

#Preview {
    let viewModel = TranscriptionViewModel(whisperManager: WhisperManager())
    TranscriptionView(viewModel: viewModel)
        .frame(minWidth: 800, minHeight: 600)
}
