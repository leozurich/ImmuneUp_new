
import SwiftUI
import SwiftData

@main
struct ImmuneUpApp: App {
    var sharedModelContainer: ModelContainer = makeModelContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
