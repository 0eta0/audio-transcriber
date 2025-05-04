import UniformTypeIdentifiers

enum SupportMediaType: String, CaseIterable {
    case mp3 = "mp3"
    case wav = "wav"
    case aac = "aac"
    case flac = "flac"
    case m4a = "m4a"
    case mp4 = "mp4"
    case mov = "mov"
    case m4v = "m4v"
    case avi = "avi"
    case mkv = "mkv"
    case webm = "webm"
    case flv = "flv"
    
    static var allCasesAsUTType: [UTType] {
        return allCases.map { UTType(filenameExtension: $0.rawValue)! }
    }
    
    static var allVideoTypes: [SupportMediaType] {
        return [.mp4, .mov, .m4v, .avi, .mkv, .webm, .flv]
    }
}

