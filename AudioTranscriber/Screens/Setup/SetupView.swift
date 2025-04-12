import SwiftUI

struct SetupView<ViewModel: SetupViewModelType>: View {

    // MARK: Properties

    @Environment(\.presentationMode) var presentationMode

    @StateObject var viewModel: ViewModel
    @Binding var isSetupCompleted: Bool

    // MARK: Lifecycle

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
                if viewModel.isDownloading {
                    ProgressView(value: viewModel.downloadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 10)
                        .padding(.horizontal)
                    
                    Text("\(Int(viewModel.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.statusMessage)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if viewModel.isError {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.red)
                        .padding()
                    
                    Text("モデルのダウンロードに失敗しました")
                        .foregroundColor(.red)
                        .font(.headline)
                    
                    Text(viewModel.statusMessage)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        Button("再試行") {
                            viewModel.downloadModel()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                        
                        Button("既存のモデルをクリーンアップして再ダウンロード") {
                            viewModel.resetAndRedownloadModel()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else if !viewModel.hasStarted {
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
                        viewModel.downloadModel()
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
    }
}
