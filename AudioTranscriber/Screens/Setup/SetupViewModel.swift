import Foundation
import SwiftUICore

enum SetupStatusType {
    case waitingSelection(description: String)
    case changing(description: String, status: WhisperInitializeStatus)
    case error(description: String)
    case completed(description: String)

    var description: String {
        switch self {
        case .waitingSelection(let description),
                .changing(let description, _),
                .error(let description),
                .completed(let description):
            return description
        }
    }
}

protocol SetupViewModelType: ObservableObject {

    var status: SetupStatusType { get set }
    var selectedModel: String { get set }
    var supportedModels: [String] { get }
    var currentModel: String { get }

    func changeModel()
}

final class SetupViewModel: SetupViewModelType {

    // MARK: Properties

    @Published var status: SetupStatusType
    @Published var selectedModel: String

    var supportedModels: [String] {
        return whisperManager.supportedModel()
    }
    var currentModel: String {
        return whisperManager.currentModel()
    }

    private let whisperManager: WhisperManagerType

    // MARK: Initializers

    init(whisperManager: WhisperManagerType, status: SetupStatusType = .waitingSelection(description: "モデルを選択してください")) {
        self.whisperManager = whisperManager

        self.status = status
        self.selectedModel = whisperManager.currentModel()
    }

    // MARK: Public Functions

    func changeModel() {
        Task { @MainActor in
            let changingDescription = "\(selectedModel)\nに変更しています..."
            status = .changing(description: changingDescription, status: .uninitialized)
            do {
                try await whisperManager.setupWhisperIfNeeded(modelName: selectedModel, progressCallback: { [weak self] progress in
                    Task { @MainActor in
                        guard let self = self else { return }

                        self.status = .changing(description: changingDescription, status: progress)
                    }
                })
                status = .completed(description: "\(selectedModel)\nモデルの変更が完了しました")
            } catch {
                status = .error(description: "モデルの変更に失敗しました: \(error.localizedDescription)")
            }
        }
    }
}
