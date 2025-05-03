import SwiftUI

struct SetupView<ViewModel: SetupViewModelType>: View {

    // MARK: Properties

    @StateObject var viewModel: ViewModel
    @Binding var showSetupModal: Bool

    // MARK: Lifecycle

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 20) {
                Text(L10n.SetupView.title)
                    .font(.title)
                    .padding(.top, 24)
                    .padding(.leading, 24)

                Text(L10n.SetupView.description)
                    .multilineTextAlignment(.center)

                Divider()
                    .padding(.vertical, 4)

                VStack {
                    switch viewModel.status {
                    case .waitingSelection:
                        SelectionView(
                            selectedModel: $viewModel.selectedModel,
                            currentModel: viewModel.currentModel,
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
                    case .completed:
                        CompletionView {
                            showSetupModal = false
                        }
                    }
                }
                .padding(.all, 24)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.all, 24)
            }
            .onChange(of: viewModel.status) { _, value in
                if value == .completed {
                    showSetupModal = false
                }
            }

            Button {
                showSetupModal = false
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding([.top, .trailing], 16)
        }
    }
}

// MARK: - Component Views

private struct SelectionView: View {

    // MARK: Properties

    @Binding var selectedModel: String

    var currentModel: String

    let supportedModels: [String]
    let changeAction: () -> Void

    // MARK: Lifecycle

    var body: some View {
        VStack(spacing: 16) {
            Text(L10n.SetupView.currentModelLabel(currentModel))
                .padding(.top, 5)

            Picker("", selection: $selectedModel) {
                ForEach(supportedModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .frame(width: 320)

            Button(L10n.SetupView.changeModelButton, action: changeAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 10)
        }
    }
}

private struct LoadingView: View {

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

private struct ErrorView: View {

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

            Button(L10n.Common.retryButton, action: retryAction)
                .buttonStyle(.borderedProminent)
                .padding(.top)
        }
    }
}

private struct CompletionView: View {

    // MARK: Properties

    let dismissAction: () -> Void

    // MARK: Lifecycle

    var body: some View {
        Button(L10n.Common.backToAppButton, action: dismissAction)
            .buttonStyle(.borderedProminent)
            .padding()
    }
}

#Preview {
    let vm = SetupViewModel(whisperManager: WhisperManager(), status: .waitingSelection)
    SetupView(viewModel: vm, showSetupModal: .constant(true))
        .frame(width: 550, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .padding()
}

