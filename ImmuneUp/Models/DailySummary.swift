
import Foundation
import SwiftData
import Combine

@Model
final class DailySummary: Identifiable {
    // Unique key per day (YYYY-MM-DD) for easy fetch/update
    @Attribute(.unique) var dateKey: String
    var date: Date

    // Sleep
    var sleepDurationMinutes: Int
    var bedTime: Date?
    var wakeTime: Date?

    // Movement
    var steps: Int
    var kcal: Int

    // Manual inputs
    var stressLevel: Int        // 0...10
    var screenTimeMinutes: Int  // minutes

    // Goal (per-day snapshot)
    var sleepGoalMinutes: Int

    // Target output (ML prediction)
    var immuneScore: Int        // 1...100

    init(date: Date,
         sleepDurationMinutes: Int = 0,
         bedTime: Date? = nil,
         wakeTime: Date? = nil,
         steps: Int = 0,
         kcal: Int = 0,
         stressLevel: Int = 0,
         screenTimeMinutes: Int = 0,
         sleepGoalMinutes: Int = 8*60,
         immuneScore: Int = 50) {
        self.date = date
        self.dateKey = Self.makeDateKey(date)
        self.sleepDurationMinutes = sleepDurationMinutes
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.steps = steps
        self.kcal = kcal
        self.stressLevel = stressLevel
        self.screenTimeMinutes = screenTimeMinutes
        self.sleepGoalMinutes = sleepGoalMinutes
        self.immuneScore = immuneScore
    }

    static func makeDateKey(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}
