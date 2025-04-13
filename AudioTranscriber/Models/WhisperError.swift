import Foundation

enum WhisperError: Error {
    case fileNotFound
    case unsupportedFormat
    case failedToInitialize
    case uninitialized
    case transcriptionFailed
    case unsupportedModel
    case audioFileLoadFailed
}

extension WhisperError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "ファイルが見つかりませんでした"
        case .unsupportedFormat:
            return "サポートされていないファイル形式です"
        case .failedToInitialize:
            return "Whisperの初期化に失敗しました"
        case .uninitialized:
            return "Whisperが初期化されていません"
        case .transcriptionFailed:
            return "文字起こし処理に失敗しました"
        case .unsupportedModel:
            return "サポートされていないモデル名です"
        case .audioFileLoadFailed:
            return "ファイルの読み込みに失敗しました"
        }
    }
}
