import Foundation

enum WhisperError: Error {
    case fileNotFound
    case unsupportedFormat
    case failedToInitialize
    case uninitialized
    case transcriptionFailed
    case unsupportedModel
    case audioFileLoadFailed
    case exportAudioFailed
}

extension WhisperError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return L10n.WhisperError.fileNotFound
        case .unsupportedFormat:
            return L10n.WhisperError.unsupportedFormat
        case .failedToInitialize:
            return L10n.WhisperError.failedToInitialize
        case .uninitialized:
            return L10n.WhisperError.uninitialized
        case .transcriptionFailed:
            return L10n.WhisperError.transcriptionFailed
        case .unsupportedModel:
            return L10n.WhisperError.unsupportedModel
        case .audioFileLoadFailed:
            return L10n.WhisperError.audioFileLoadFailed
        case .exportAudioFailed:
            return L10n.WhisperError.audioExportFailed
        }
    }
}
