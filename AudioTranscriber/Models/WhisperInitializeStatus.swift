enum WhisperInitializeStatus: Equatable {
    case uninitialized
    case checkingModel
    case downloadingModel(progress: Double)
    case loadingModel
    case ready

    static func == (lhs: WhisperInitializeStatus, rhs: WhisperInitializeStatus) -> Bool {
        switch (lhs, rhs) {
        case (.uninitialized, .uninitialized):
            return true
        case (.checkingModel, .checkingModel):
            return true
        case (.downloadingModel(let lhsProgress), .downloadingModel(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.loadingModel, .loadingModel):
            return true
        case (.ready, .ready):
            return true
        default:
            // Cases are different or associated values don't match
            return false
        }
    }

    var description: String {
        switch self {
        case .uninitialized:
            return L10n.WhisperInitializeStatus.uninitialized
        case .checkingModel:
            return L10n.WhisperInitializeStatus.checkingModel
        case .downloadingModel(let progress):
            return L10n.WhisperInitializeStatus.downloadingModelFormat(Int(progress * 100))
        case .loadingModel:
            return L10n.WhisperInitializeStatus.loadingModel
        case .ready:
            return L10n.WhisperInitializeStatus.ready
        }
    }
}
