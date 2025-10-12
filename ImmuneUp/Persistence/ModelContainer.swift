
import SwiftData
import Foundation

func makeModelContainer() -> ModelContainer {
    do {
        let schema = Schema([DailySummary.self])
        let config = ModelConfiguration(for: DailySummary.self)
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Failed to create ModelContainer: \(error)")
    }
}



//test
