import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var audioViewModel = AudioViewModel()
    @State private var isFilePickerPresented = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isDraggingOver = false
    @State private var showModelSetup = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // ツールバー
                HStack {
                    Button(action: {
                        isFilePickerPresented = true
                    }) {
                        Label("音声ファイルを開く", systemImage: "doc")
                    }
                    .fileImporter(
                        isPresented: $isFilePickerPresented,
                        allowedContentTypes: [.audio, .mpeg4Movie],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                audioViewModel.loadAudioFile(url: url)
                            }
                        case .failure(let error):
                            alertMessage = "ファイル選択エラー: \(error.localizedDescription)"
                            showingAlert = true
                        }
                    }
                    
                    Spacer()
                    
                    if audioViewModel.isTranscribing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.horizontal)
                        Text("文字起こし中...")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // メインコンテンツ
                VStack(spacing: 0) {
                    // 音声プレーヤー部分
                    VStack {
                        if audioViewModel.isFileLoaded, let audioFile = audioViewModel.audioFile {
                            Text(audioFile.lastPathComponent)
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(.horizontal)
                            
                            HStack {
                                Button(action: {
                                    audioViewModel.togglePlayback()
                                }) {
                                    Image(systemName: audioViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.borderless)
                                .keyboardShortcut(.space, modifiers: [])
                                
                                Button(action: {
                                    audioViewModel.seekRelative(seconds: -10)
                                }) {
                                    Image(systemName: "gobackward.10")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(.borderless)
                                .keyboardShortcut(.leftArrow, modifiers: [])
                                
                                Button(action: {
                                    audioViewModel.seekRelative(seconds: 10)
                                }) {
                                    Image(systemName: "goforward.10")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(.borderless)
                                .keyboardShortcut(.rightArrow, modifiers: [])
                                
                                VStack(spacing: 2) {
                                    Slider(value: $audioViewModel.playbackProgress, in: 0...1) { editing in
                                        if !editing {
                                            audioViewModel.seekToPosition(audioViewModel.playbackProgress)
                                        }
                                    }
                                    
                                    HStack {
                                        Text(formatTime(audioViewModel.currentTime))
                                        Spacer()
                                        Text(formatTime(audioViewModel.duration))
                                    }
                                    .font(.caption)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            Text("音声ファイルを選択してください")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 100)
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                    
                    // 文字起こし表示部分
                    ScrollViewReader { scrollView in
                        VStack {
                            if audioViewModel.transcribedSegments.isEmpty {
                                VStack {
                                    if audioViewModel.isTranscribing {
                                        VStack {
                                            ProgressView()
                                                .scaleEffect(1.2)
                                            Text("文字起こしを処理中...")
                                                .padding(.top)
                                        }
                                    } else {
                                        Text("文字起こしがありません")
                                            .foregroundColor(.secondary)
                                        
                                        if audioViewModel.isFileLoaded, let audioFile = audioViewModel.audioFile {
                                            Button("文字起こしを開始") {
                                                audioViewModel.transcribeAudio()
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .padding(.top)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(audioViewModel.transcribedSegments) { segment in
                                            TranscriptSegmentView(
                                                segment: segment,
                                                isActive: audioViewModel.currentSegmentID == segment.id
                                            )
                                            .id(segment.id)
                                            .onTapGesture {
                                                audioViewModel.playFromSegment(segment)
                                            }
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.textBackgroundColor))
                        .onChange(of: audioViewModel.currentSegmentID) { id in
                            if let id = id {
                                withAnimation {
                                    scrollView.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            }
            .onDrop(of: [.fileURL, .item, .text, .data, .audio, .mpeg4Movie], isTargeted: $isDraggingOver) { providers in
                for provider in providers {
                    // 利用可能なタイプ識別子を確認
                    let availableTypes = provider.registeredTypeIdentifiers
                    print("利用可能なタイプ: \(availableTypes)")
                    
                    // 使える識別子を探す
                    let identifierToUse = availableTypes.first(where: { ident in
                        // ファイルURLの可能性のある識別子を優先的に利用
                        return ident == "public.file-url" || 
                               ident == UTType.fileURL.identifier || 
                               ident == "public.url" ||
                               ident.contains("file") || 
                               ident.contains("url")
                    }) ?? availableTypes.first
                    
                    if let identifierToUse = identifierToUse {
                        print("使用する識別子: \(identifierToUse)")
                        
                        provider.loadItem(forTypeIdentifier: identifierToUse) { item, error in
                            if let error = error {
                                print("項目読み込みエラー: \(error.localizedDescription)")
                                return
                            }
                            
                            var fileURL: URL? = nil
                            
                            // 様々なデータ形式に対応
                            if let url = item as? URL {
                                fileURL = url
                                print("URLとして処理: \(url.path)")
                            } else if let data = item as? Data {
                                if let url = URL(dataRepresentation: data, relativeTo: nil) {
                                    fileURL = url
                                    print("Dataから変換したURL: \(url.path)")
                                } else if let string = String(data: data, encoding: .utf8),
                                          let url = URL(string: string) {
                                    fileURL = url
                                    print("文字列から変換したURL: \(url.path)")
                                }
                            } else if let string = item as? String {
                                if let url = URL(string: string) {
                                    fileURL = url
                                    print("文字列から直接変換したURL: \(url.path)")
                                } else {
                                    // オプショナルでないURLイニシャライザはif letで使用できないので直接代入
                                    let url = URL(fileURLWithPath: string)
                                    fileURL = url
                                    print("パス文字列からURLを作成: \(url.path)")
                                }
                            } else {
                                print("未対応の項目タイプ: \(String(describing: type(of: item)))")
                            }
                            
                            // ファイルURLが取得できたら処理
                            if let url = fileURL {
                                DispatchQueue.main.async {
                                    self.audioViewModel.loadAudioFile(url: url)
                                }
                            }
                        }
                        
                        // 最初に成功した項目だけを処理
                        return true
                    }
                }
                return false
            }
            
            if isDraggingOver {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(Color.accentColor.opacity(0.1))
                    .overlay(
                        VStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.largeTitle)
                            Text("ここに音声ファイルをドロップ")
                                .font(.headline)
                        }
                        .foregroundColor(.accentColor)
                    )
                    .padding(20)
            }
        }
        .sheet(isPresented: $showModelSetup) {
            InitialSetupView(isSetupCompleted: $showModelSetup)
                .frame(minWidth: 500, minHeight: 400)
        }
        .onAppear {
            // モデルのダウンロード通知を監視
            setupNotificationObserver()
        }
    }
    
    // 通知を監視する設定
    private func setupNotificationObserver() {
        // モデルダウンロード通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WhisperModelDownloadNeeded"),
            object: nil,
            queue: .main
        ) { _ in
            // モデルがない場合はダウンロード画面を表示
            showModelSetup = true
        }
        
        // 文字起こしエラー通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TranscriptionError"),
            object: nil,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?["error"] as? WhisperError {
                // エラータイプに応じたメッセージを表示
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    // 時間のフォーマット関数
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// 文字起こしのセグメント表示用ビュー
struct TranscriptSegmentView: View {
    var segment: TranscriptSegment
    var isActive: Bool
    
    var body: some View {
        Text(segment.text)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .foregroundColor(isActive ? .primary : .secondary)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, 2)
    }
}
