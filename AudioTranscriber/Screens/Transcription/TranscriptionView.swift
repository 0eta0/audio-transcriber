import SwiftUI
import AVFoundation

struct TranscriptionView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @Environment(\.dependency) private var dependency

    @StateObject private var viewModel: ViewModel
    
    @State private var isFilePickerPresented = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isDraggingOver = false
    @State private var showSetupModal = true

    // MARK: Initializer

    init(viewModel: ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

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
                        isDraggingOver: $isDraggingOver
                    )
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            }
            .onDrop(of: [.audio], isTargeted: $isDraggingOver) { providers in
                viewModel.handleDrop(providers: providers)
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
                    alertMessage = "ファイル選択エラー: \(error.localizedDescription)"
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
struct ToolbarView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject private var viewModel: ViewModel

    @Binding var isFilePickerPresented: Bool
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    @State private var showingSavePanel = false
    @State private var showingResetConfirmation = false
    @Binding var showSetupModal: Bool
    @State private var showingRetranscribeConfirmation = false

    // MARK: Initializer

    init(viewModel: ViewModel,
            isFilePickerPresented: Binding<Bool>,
            showingAlert: Binding<Bool>,
            alertMessage: Binding<String>,
         showSetupModal: Binding<Bool>) {
        self.viewModel = viewModel
        self._isFilePickerPresented = isFilePickerPresented
        self._showingAlert = showingAlert
        self._alertMessage = alertMessage
        self._showSetupModal = showSetupModal
    }

    // MARK: Lifecycle
    
    var body: some View {
        HStack {
            Text(viewModel.audioFile?.lastPathComponent ?? "untitled")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            
            Button(action: {
                showSetupModal = true
            }) {
                Label("モデル選択", systemImage: "brain")
            }
            .help("文字起こしモデルを選択")
            .buttonStyle(.bordered)
            
            if !viewModel.transcribedSegments.isEmpty {
                Button(action: {
                    showingRetranscribeConfirmation = true
                }) {
                    Label("再文字起こし", systemImage: "arrow.triangle.2.circlepath")
                }
                .help("音声ファイルを再度文字起こしする")
                .buttonStyle(.bordered)
                .confirmationDialog(
                    "文字起こしを再実行しますか？現在の文字起こし結果は消去されます。",
                    isPresented: $showingRetranscribeConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("再実行", role: .destructive) {
                        viewModel.retranscribeAudio()
                    }
                    Button("キャンセル", role: .cancel) {}
                }
                
                Button(action: {
                    showingSavePanel = true
                }) {
                    Label("テキストファイルとして保存", systemImage: "arrow.down.doc")
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
                        alertMessage = "ファイルの保存に成功しました"
                        showingAlert = true
                    case .failure(let error):
                        alertMessage = "ファイルの保存に失敗しました: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
            
            Button(action: {
                showingResetConfirmation = true
            }) {
                Label("リセット", systemImage: "arrow.counterclockwise")
            }
            .confirmationDialog(
                "ファイルと文字起こしをリセットしますか？",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("リセット", role: .destructive) {
                    viewModel.resetAll()
                }
                Button("キャンセル", role: .cancel) {}
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// オーディオプレーヤーコンポーネント
struct AudioPlayerView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Lifecycle
    
    var body: some View {
        HStack(alignment: .center) {
            Button(action: {
                viewModel.togglePlayback()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
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

            VStack(spacing: 2) {
                Slider(value: $viewModel.playbackProgress, in: 0...1) { editing in
                    if !editing {
                        viewModel.seekToPosition(viewModel.playbackProgress)
                    }
                }

                HStack {
                    Text(formatTime(viewModel.currentTime))
                    Spacer()
                    Text(formatTime(viewModel.duration))
                }
                .font(.caption)
            }
            .padding(.top, 16)
        }
        .padding(.all, 24)
        .padding(.top, 0)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // 時間のフォーマット関数
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// 文字起こし表示コンポーネント
struct TranscriptionContentView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject private var viewModel: ViewModel

    // MARK: Initializer

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

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
                        Label("現在の場所を表示", systemImage: "text.insert")
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
struct EmptyTranscriptionView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject private var viewModel: ViewModel

    // MARK: Initializer

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Lifecycle
    
    var body: some View {
        VStack {
            if viewModel.isTranscribing {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("文字起こしを処理中...")
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
                Text("文字起こしがありません")
                    .foregroundColor(.secondary)
                
                if viewModel.isFileLoaded, let _ = viewModel.audioFile {
                    Button("文字起こしを開始") {
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
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// 文字起こしリスト表示
struct TranscriptionListView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject private var viewModel: ViewModel
    @State private var previousOffset: CGFloat = 0

    // MARK: Initializer

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

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


struct OffsetPreferenceKey: PreferenceKey {

    typealias Value = CGFloat

    static var defaultValue = CGFloat.zero

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

// ドラッグオーバーレイ表示
struct DragOverlayView: View {

    // MARK: Lifecycle
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.accentColor, lineWidth: 2)
            .background(Color.accentColor.opacity(0.1))
            .overlay(
                VStack {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                    Text("ここに音声ファイルをドロップ")
                        .font(.headline)
                }
                .foregroundColor(.accentColor)
            )
            .padding(20)
    }
}

// 文字起こしのセグメント表示用ビュー
struct TranscriptSegmentView: View {

    // MARK: Properties
    
    // Model Data
    var segment: TranscriptSegment
    var isActive: Bool
    
    // MARK: Lifecycle
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(formatTime(segment.startTime))
                .frame(width: 80, alignment: .leading)
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
        return String(format: "%d分%02d秒", minutes, seconds)
    }
}

// ファイル読み込み前の初期画面
struct FileLoadingPromptView: View {

    // MARK: Properties

    @Binding var showSetupModal: Bool
    @Binding var isFilePickerPresented: Bool
    @Binding var isDraggingOver: Bool

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
    }

    // MARK: Private Functions

    private func audioInputView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("音声ファイルをドラッグ＆ドロップ")
                .font(.title2)
                .fontWeight(.medium)

            Text("または")
                .foregroundColor(.secondary)

            Button(action: {
                isFilePickerPresented = true
            }) {
                Label("音声ファイルを選択", systemImage: "folder")
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
            Label("モデル選択", systemImage: "brain")
        }
        .help("文字起こしモデルを選択")
        .buttonStyle(.bordered)
    }
}
