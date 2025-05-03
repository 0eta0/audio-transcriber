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
        .commands {
            CommandGroup(after: .textEditing) {
                Divider()
                Button(L10n.TranscriptionView.find) {
                    // Post notification to focus search field
                    NotificationCenter.default.post(name: .focusSearchField, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}
