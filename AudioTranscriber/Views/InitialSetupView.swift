import SwiftUI

struct InitialSetupView: View {
    @ObservedObject var setupViewModel = SetupViewModel()
    @Binding var isSetupCompleted: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("音声文字起こしモデルが必要です")
                    .font(.title)
                    .padding(.top, 30)
                    .padding(.leading, 30)

                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding([.top, .trailing], 20)
            }
            
            Text("文字起こしを行うために必要なWhisperモデルをダウンロードする必要があります。\nダウンロードはアプリ内でできます。")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical, 5)
            
            VStack(spacing: 20) {
                if setupViewModel.isDownloading {
                    ProgressView(value: setupViewModel.downloadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 10)
                        .padding(.horizontal)
                    
                    Text("\(Int(setupViewModel.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(setupViewModel.statusMessage)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if setupViewModel.isError {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.red)
                        .padding()
                    
                    Text("モデルのダウンロードに失敗しました")
                        .foregroundColor(.red)
                        .font(.headline)
                    
                    Text(setupViewModel.statusMessage)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        Button("再試行") {
                            setupViewModel.downloadModel()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                        
                        Button("既存のモデルをクリーンアップして再ダウンロード") {
                            setupViewModel.resetAndRedownloadModel()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else if !setupViewModel.hasStarted {
                    Image(systemName: "arrow.down.circle")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.accentColor)
                        .padding()
                    
                    Text("このアプリは、すべての処理をローカルで実行するためのAIモデルが必要です。")
                        .multilineTextAlignment(.center)
                    
                    Text("お使いのデバイスに応じて500MB〜1GBのダウンロードが必要です。")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                    
                    Button("モデルをダウンロード") {
                        setupViewModel.downloadModel()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 10)
                } else {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.green)
                        .padding()
                    
                    Text("セットアップが完了しました")
                        .foregroundColor(.green)
                        .font(.headline)
                    
                    Button("アプリに戻る") {
                        isSetupCompleted = true
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Spacer()
            
            HStack(spacing: 15) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                
                Text("モデルは一度ダウンロードすれば、今後ダウンロードは不要です")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal)
        .frame(width: 550)
        .onAppear {
            setupViewModel.setupNotifications()
        }
        .onDisappear {
            setupViewModel.cleanupNotifications()
        }
    }
}

class SetupViewModel: ObservableObject {
    @Published var isDownloading = false
    @Published var isError = false
    @Published var hasStarted = false
    @Published var statusMessage = "モデルをダウンロードしています..."
    @Published var downloadProgress: Float = 0.0
    @Published var errorDetails: String?
    
    private let whisperManager = WhisperManager()
    private var notificationObservers: [NSObjectProtocol] = []
    
    deinit {
        cleanupNotifications()
    }
    
    func setupNotifications() {
        // モデルのダウンロード進捗を監視
        let progressObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WhisperModelDownloadProgress"),
            object: nil,
            queue: .main) { [weak self] notification in
                if let progress = notification.userInfo?["progress"] as? Float {
                    self?.downloadProgress = progress
                }
            }
        
        // モデルのダウンロード失敗を監視
        let failureObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WhisperModelDownloadFailed"),
            object: nil,
            queue: .main) { [weak self] notification in
                self?.isDownloading = false
                self?.isError = true
                if let error = notification.userInfo?["error"] as? String {
                    self?.statusMessage = "エラー: \(error)"
                    self?.errorDetails = error
                } else {
                    self?.statusMessage = "モデルのダウンロードに失敗しました。\nネットワーク接続を確認してください。"
                }
            }
        
        // モデルのダウンロード成功を監視
        let successObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WhisperModelLoaded"),
            object: nil,
            queue: .main) { [weak self] _ in
                self?.isDownloading = false
                self?.isError = false
                self?.hasStarted = true
                self?.statusMessage = "モデルのダウンロードに成功しました！"
            }
        
        notificationObservers.append(contentsOf: [progressObserver, failureObserver, successObserver])
    }
    
    func cleanupNotifications() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }
    
    func downloadModel() {
        isDownloading = true
        hasStarted = true
        isError = false
        downloadProgress = 0.0
        statusMessage = "Whisperモデルをダウンロードしています...\nこれには数分かかる場合があります"
    }
    
    func resetAndRedownloadModel() {
        isDownloading = true
        hasStarted = true
        isError = false
        downloadProgress = 0.0
        statusMessage = "モデルファイルをリセットし、再ダウンロードしています...\nこれには数分かかる場合があります"
    }
}
