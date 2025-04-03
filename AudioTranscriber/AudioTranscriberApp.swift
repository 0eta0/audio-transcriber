import SwiftUI

@main
struct AudioTranscriberApp: App {
    @AppStorage("isSetupCompleted") private var isSetupCompleted = false
    
    var body: some Scene {
        WindowGroup {
            if isSetupCompleted {
                ContentView()
                    .frame(minWidth: 800, minHeight: 600)
            } else {
                InitialSetupView(isSetupCompleted: $isSetupCompleted)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}