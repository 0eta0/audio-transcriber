// Whisperによる文字起こしのエラー型
enum WhisperError: Error {
    case unsupportedFormat
    case uninitialized
    case failedToInitialize
    case transcriptionFailed
    case fileAccessDenied
    case fileLoadError
    case noAudioTrackFound
    case unknown

    var localizedDescription: String {
        switch self {
        case .unsupportedFormat:
            return "Unsupported audio format."
        case .uninitialized:
            return "WhisperKit is not initialized."
        case .failedToInitialize:
            return "Failed to initialize WhisperKit."
        case .transcriptionFailed:
            return "Transcription failed."
        case .fileAccessDenied:
            return "File access denied."
        case .fileLoadError:
            return "Failed to load the audio file."
        case .noAudioTrackFound:
            return "No audio track found in the file."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
