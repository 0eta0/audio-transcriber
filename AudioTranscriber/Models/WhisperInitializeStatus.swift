enum WhisperInitializeStatus {
    case uninitialized
    case checkingModel
    case downloadingModel(progress: Double)
    case loadingModel
    case ready

    var description: String {
        switch self {
        case .uninitialized:
            return "WhisperKitが初期化されていません"
        case .checkingModel:
            return "モデルを確認中..."
        case .downloadingModel(let progress):
            return "モデルをダウンロード中... \(Int(progress * 100))%"
        case .loadingModel:
            return "モデルを読み込み中..."
        case .ready:
            return "WhisperKitが準備完了"
        }
    }
}
