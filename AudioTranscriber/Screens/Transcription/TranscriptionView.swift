import SwiftUI
import AVFoundation
import AVKit

struct TranscriptionView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @Environment(\.dependency) private var dependency

    @StateObject var viewModel: ViewModel
    
    @State private var isFilePickerPresented = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showSetupModal = false

    // MARK: Lifecycle

    var body: some View {
        if let dependency = dependency {
            ZStack(alignment: .topTrailing) {
                if viewModel.isFileLoaded {
                    VStack(spacing: 0) {
                        ToolbarView(
                            viewModel: viewModel,
                            isFilePickerPresented: $isFilePickerPresented,
                            showingAlert: $showingAlert,
                            alertMessage: $alertMessage,
                            showSetupModal: $showSetupModal
                        )

                        Divider()
                        
                        DraggableVideoPlayerArea {
                            TranscriptionContentView(viewModel: viewModel)

                            if (viewModel.isPlayingVideo) {
                                DraggableVideoPlayer(viewModel: viewModel)
                            }
                        }

                        Divider()
                        
                        AudioPlayerView(viewModel: viewModel)
                    }
                } else {
                    // Initial screen when no file is loaded
                    FileLoadingPromptView(
                        showSetupModal: $showSetupModal,
                        isFilePickerPresented: $isFilePickerPresented,
                        viewModel: viewModel
                    )
                }
            }
            .onChange(of: viewModel.error, { _, value in
                if let error = value {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            })
            .alert(alertMessage, isPresented: $showingAlert) {
                Button(L10n.Common.okButton, role: .cancel) {
                    showingAlert = false
                }
            }
            .sheet(isPresented: $showSetupModal) {
                let setupViewModel = SetupViewModel(whisperManager: dependency.whisperManager)
                SetupView(viewModel: setupViewModel, showSetupModal: $showSetupModal)
            }
            .fileImporter(
                isPresented: $isFilePickerPresented,
                allowedContentTypes: SupportMediaType.allCasesAsUTType,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        return
                    }
                    Task { @MainActor in
                        await viewModel.loadFile(url: url)
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

private struct DraggableVideoPlayerArea<Content> : View where Content : View {
    
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            content()
        }
        .coordinateSpace(.named("VideoPlayerArea"))
    }
}

private struct DraggableVideoPlayer<ViewModel: TranscriptionViewModelType>: View {
    
    @ObservedObject var viewModel: ViewModel

    // Offset that the player will be dragged
    @State private var playerOffset: CGPoint = .zero
    // Offset inside the player
    @State private var insideOffset: CGPoint = .zero
    // Size of the player
    @State private var playerSize = CGSize(width: 240, height: 240 * 9 / 16)
    // Size of the player when magnified
    @State private var baseSize: CGSize = .zero
    // Size of the area that allows dragging
    @State private var areaSize = CGSize.zero

    // margin around the player
    private let padding: CGFloat = 16
    // minimum width of the player
    private let minVideoPlayerWidth: CGFloat = 120
    // maximum width of the player
    private var maxVideoPlayerWidth: CGFloat {
        return areaSize.width - 2 * padding
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                CustomVideoPlayer(player: viewModel.player)
                
                Color.clear
                    .contentShape(Rectangle())
            }
            .frame(width: playerSize.width, height: playerSize.height)
            .cornerRadius(8)
            .onAppear {
                areaSize = geo.size
                playerOffset = CGPoint(
                    x: geo.size.width - playerSize.width - padding,
                    y: padding
                )
            }
            .onChange(of: geo.size) { _, area in
                areaSize = area
                clampOffset()
                clampSize()
            }
            .simultaneousGesture(
                DragGesture(coordinateSpace: .named("VideoPlayerArea"))
                    .onChanged { value in
                        playerOffset = CGPoint(
                            x: value.location.x - insideOffset.x,
                            y: value.location.y - insideOffset.y
                        )
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        insideOffset = value.startLocation
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        if baseSize == .zero {
                            baseSize = playerSize
                        }
                        playerSize = magnifySize(value.magnification)
                        clampOffset()
                    }
                    .onEnded { value in
                        baseSize = .zero
                    }
            )
            .offset(x: playerOffset.x, y: playerOffset.y)
        }
    }
    
    private func magnifySize(_ value: CGFloat) -> CGSize {
        let width = max(minVideoPlayerWidth, min(maxVideoPlayerWidth, baseSize.width * value))
        let height = width * 9 / 16
        return CGSize(width: width, height: height)
    }
    
    private func clampOffset() {
        let maxX = max(0, areaSize.width - playerSize.width - padding)
        let maxY = max(0, areaSize.height - playerSize.height - padding)
        playerOffset.x = clamp(playerOffset.x, padding, maxX)
        playerOffset.y = clamp(playerOffset.y, padding, maxY)
    }

    private func clampSize() {
        if playerSize.width > areaSize.width - 2 * padding || playerSize.height > areaSize.height - 2 * padding {
            let w = min(playerSize.width, areaSize.width - 2 * padding, areaSize.height * 16 / 9 - 2 * padding)
            playerSize = CGSize(width: w, height: w * 9 / 16)
        }
    }
    
    @inline(__always)
    private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
        min(max(v, lo), hi)
    }
}

private struct CustomVideoPlayer : NSViewRepresentable {
    
    var player : AVPlayer?
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.player = player
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}

// Toolbar component
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

    @FocusState private var isSearchFieldFocused: Bool
    
    // MARK: Lifecycle
    
    var body: some View {
        HStack {
            Text(viewModel.mediaFile?.lastPathComponent ?? L10n.TranscriptionView.untitled)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            // Add Search Field
            if !viewModel.transcribedSegments.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(L10n.TranscriptionView.searchPlaceholder, text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFieldFocused)
                        .frame(width: 140)
                        .onKeyPress(.escape) {
                            isSearchFieldFocused = false
                            return .handled
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .focusSearchField)) { _ in
                            isSearchFieldFocused = true
                        }
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            }
            
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
        .onTapGesture {
            isSearchFieldFocused = false
        }
    }
}

// Audio player component
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
                    Text("\(viewModel.playbackSpeed, specifier: "%.2f")x")
                        .font(.system(size: 14))
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
                        Spacer()
                        Text("\(formatTime(viewModel.currentTime)) / \(formatTime(viewModel.duration))")
                    }
                    .font(.caption)
                }
                .padding(.top, 20)
            
        }
        .padding(.all, 24)
        .padding(.top, 0)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // Time formatting function
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return L10n.TranscriptionView.timeFormat(minutes, seconds)
    }
}

// Tooltip for seek bar time display
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
    
    // Time formatting function
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return L10n.TranscriptionView.timeFormat(minutes, seconds)
    }
}

// Transcription display component
private struct TranscriptionContentView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject var viewModel: ViewModel

    // MARK: Lifecycle
    
    var body: some View {
        ScrollViewReader { scrollView in
            ZStack(alignment: .bottomTrailing) {
                VStack {
                    // Use filteredSegments for display
                    if viewModel.filteredSegments.isEmpty {
                        if viewModel.isTranscribing {
                            EmptyTranscriptionView(viewModel: viewModel)
                        } else if !viewModel.searchText.isEmpty {
                            Text(L10n.TranscriptionView.noSearchResults) // Show no search results message
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            EmptyTranscriptionView(viewModel: viewModel)
                        }
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
                    // Only scroll if the current segment is visible in the filtered list
                    if viewModel.filteredSegments.contains(where: { $0.id == id }) {
                        withAnimation {
                            scrollView.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

// Display when there is no transcription
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
                
                if viewModel.isFileLoaded, let _ = viewModel.mediaFile {
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

// Transcription list display
private struct TranscriptionListView<ViewModel: TranscriptionViewModelType>: View {

    // MARK: Properties

    @ObservedObject var viewModel: ViewModel

    @State private var previousOffset: CGFloat = 0

    // MARK: Lifecycle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Iterate over filteredSegments
                ForEach(viewModel.filteredSegments) { segment in
                    TranscriptSegmentView(
                        segment: segment,
                        isActive: $viewModel.currentSegmentID.wrappedValue == segment.id,
                        searchText: viewModel.searchText // Pass search text for highlighting
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
                Task { @MainActor in
                    viewModel.autoScrollDisabled()
                }
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

// View for displaying transcription segments
private struct TranscriptSegmentView: View {

    // MARK: Properties
    
    // Model Data
    var segment: TranscriptSegment
    var isActive: Bool
    var searchText: String // Receive search text
    
    // MARK: Lifecycle
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(formatTime(segment.startTime))
                .frame(width: 100, alignment: .leading)
                .multilineTextAlignment(.leading)
                .foregroundColor(isActive ? .primary : .secondary)

            // Highlight search text
            highlightedText(segment.text, search: searchText)
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

    // Function to highlight search text
    private func highlightedText(_ text: String, search: String) -> Text {
        guard !search.isEmpty, let range = text.range(of: search, options: .caseInsensitive) else {
            return Text(text)
        }

        let before = text[..<range.lowerBound]
        let highlighted = text[range]
        let after = text[range.upperBound...]

        return Text(before) +
               Text(highlighted).bold().foregroundColor(.accentColor) + // Highlight style
               highlightedText(String(after), search: search) // Recursively highlight remaining parts
    }
}

// Initial screen before file loading
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
        .onDrop(of: SupportMediaType.allCasesAsUTType, isTargeted: $isDraggingOver) { providers in
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

            Text(L10n.TranscriptionView.dragAndDropMediaFile)
                .font(.title2)
                .fontWeight(.medium)

            Text(L10n.TranscriptionView.or)
                .foregroundColor(.secondary)

            Button(action: {
                isFilePickerPresented = true
            }) {
                Label(L10n.TranscriptionView.selectMediaFile, systemImage: "folder")
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

// Drag overlay display
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
                    Text(L10n.TranscriptionView.dropMediaFileHere)
                        .font(.headline)
                }
                .foregroundColor(.accentColor)
            )
            .padding(20)
    }
}
