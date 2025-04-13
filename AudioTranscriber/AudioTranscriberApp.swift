import SwiftUI

@main
struct AudioTranscriberApp: App {

    // MARK: Properties

    private var dependency = Dependency()

    // MARK: Body

    var body: some Scene {
        WindowGroup {
            TranscriptionView(viewModel: TranscriptionViewModel(whisperManager: dependency.whisperManager))
                .frame(minWidth: 800, minHeight: 600)
                .environment(\.dependency, dependency)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
