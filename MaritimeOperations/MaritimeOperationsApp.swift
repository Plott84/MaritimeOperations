import SwiftUI
import SwiftData

@main
struct MaritimeOperationsApp: App {
    private let modelContainer: ModelContainer

    init() {
        LaunchEnvironment.applyResetIfRequested()
        modelContainer = LaunchEnvironment.makeModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
