import Foundation

// Model representing each segment of the transcription
struct TranscriptSegment: Identifiable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}