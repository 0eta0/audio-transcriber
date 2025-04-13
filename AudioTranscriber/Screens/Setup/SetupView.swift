import SwiftUI

struct SetupView<ViewModel: SetupViewModelType>: View {

    // MARK: Properties

    @StateObject var viewModel: ViewModel
    @Binding var showSetupModal: Bool

    // MARK: Lifecycle

    var body: some View {
        VStack(spacing: 20) {
            Text("音声文字起こしモデルの変更")
                .font(.title)
                .padding(.top, 24)
                .padding(.leading, 24)

            Text("文字起こしに使用するWhisperモデルを変更できます。\nモデルによって精度と処理速度が異なります。")
                .multilineTextAlignment(.center)

            Divider()
                .padding(.vertical, 4)

            VStack {
                switch viewModel.status {
                case .waitingSelection(let description):
                    SelectionView(
                        selectedModel: $viewModel.selectedModel,
                        currentModel: viewModel.currentModel,
                        description: description,
                        supportedModels: viewModel.supportedModels
                    ) {
                        viewModel.changeModel()
                    }
                case .changing(let description, let status):
                    LoadingView(description: description, status: status)
                case .error(let description):
                    ErrorView(description: description) {
                        viewModel.changeModel()
                    }
                case .completed(let description):
                    CompletionView(description: description) {
                        showSetupModal = false
                    }
                }
            }
            .padding(.all, 24)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - Component Views

struct SelectionView: View {

    // MARK: Properties

    @Binding var selectedModel: String

    var currentModel: String

    let description: String
    let supportedModels: [String]
    let changeAction: () -> Void

    // MARK: Lifecycle

    var body: some View {
        VStack(spacing: 16) {
            Text(description)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("現在のモデル: \(currentModel)")
                .padding(.top, 5)

            Picker("モデルの選択", selection: $selectedModel) {
                ForEach(supportedModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .frame(width: 320)

            Button("モデルを変更", action: changeAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 10)
        }
    }
}

struct LoadingView: View {

    // MARK: Properties

    let description: String
    let status: WhisperInitializeStatus

    // MARK: Lifecycle

    var body: some View {
        VStack(spacing: 16) {
            Text(description)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(status.description)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ProgressView()
        }
    }
}

struct ErrorView: View {

    // MARK: Properties

    let description: String
    let retryAction: () -> Void

    // MARK: Lifecycle

    var body: some View {
        VStack(spacing: 16) {
            Text(description)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("再試行", action: retryAction)
                .buttonStyle(.borderedProminent)
                .padding(.top)
        }
    }
}

struct CompletionView: View {

    // MARK: Properties

    let description: String
    let dismissAction: () -> Void

    // MARK: Lifecycle

    var body: some View {
        VStack(spacing: 16) {
            Text(description)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("アプリに戻る", action: dismissAction)
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
}

#Preview {
    let vm = SetupViewModel(whisperManager: WhisperManager(), status: .waitingSelection(description: "ステータスの表示"))
    SetupView(viewModel: vm, showSetupModal: .constant(true))
        .frame(width: 550, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .padding()
}

