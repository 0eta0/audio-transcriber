import Foundation

// 文字起こしの各セグメントを表すモデル
struct TranscriptSegment: Identifiable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}