import SwiftUI

protocol DependencyType {

    var whisperManager: WhisperManagerType { get }
}

final class Dependency: DependencyType {

    // MARK: Properties

    var whisperManager: WhisperManagerType

    // MARK: Initialize

    init() {
        whisperManager = WhisperManager()
    }
}
