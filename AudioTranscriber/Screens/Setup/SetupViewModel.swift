import Foundation

protocol SetupViewModelType: ObservableObject {

    var isDownloading: Bool { get set }
    var isError: Bool { get set }
    var hasStarted: Bool { get set }
    var statusMessage: String { get set }
    var downloadProgress: Float { get set }
    var errorDetails: String? { get set }

    func downloadModel()
    func resetAndRedownloadModel()
}

final class SetupViewModel: SetupViewModelType {

    // MARK: Properties

    @Published var isDownloading = false
    @Published var isError = false
    @Published var hasStarted = false
    @Published var statusMessage = "モデルをダウンロードしています..."
    @Published var downloadProgress: Float = 0.0
    @Published var errorDetails: String?

    private let whisperManager = WhisperManager()
    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: Public Functions

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
