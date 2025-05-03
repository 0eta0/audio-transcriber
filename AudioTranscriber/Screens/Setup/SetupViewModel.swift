import Foundation
import SwiftUICore

enum SetupStatusType: Equatable {
    case waitingSelection
    case changing(description: String, status: WhisperInitializeStatus)
    case error(description: String)
    case completed

    static func == (lhs: SetupStatusType, rhs: SetupStatusType) -> Bool {
        switch (lhs, rhs) {
        case (.waitingSelection, .waitingSelection):
            return true
        case let (.changing(lhsDescription, lhsStatus), .changing(rhsDescription, rhsStatus)):
            return lhsDescription == rhsDescription && lhsStatus == rhsStatus
        case let (.error(lhsDescription), .error(rhsDescription)):
            return lhsDescription == rhsDescription
        case (.completed, .completed):
            return true
        default:
            return false
        }
    }

    var description: String {
        switch self {
        case .waitingSelection, .completed:
            return ""
        case .changing(let description, _), .error(let description):
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

    init(whisperManager: WhisperManagerType, status: SetupStatusType = .waitingSelection) {
        self.whisperManager = whisperManager

        self.status = status
        self.selectedModel = whisperManager.currentModel()
    }

    // MARK: Public Functions

    func changeModel() {
        Task { @MainActor in
            let changingDescription = L10n.SetupViewModel.changingDescriptionFormat(selectedModel)
            status = .changing(description: changingDescription, status: .uninitialized)
            do {
                try await whisperManager.setupWhisperIfNeeded(modelName: selectedModel, progressCallback: { [weak self] progress in
                    Task { @MainActor in
                        guard let self = self else { return }

                        self.status = .changing(description: changingDescription, status: progress)
                    }
                })
                status = .completed
            } catch {
                status = .error(description: L10n.SetupViewModel.changeModelErrorFormat(error.localizedDescription))
            }
        }
    }
}
