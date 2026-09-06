import SwiftUI
import SwiftData

@main
struct MaritimeOperationsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: DPEntry.self)
    }
}
