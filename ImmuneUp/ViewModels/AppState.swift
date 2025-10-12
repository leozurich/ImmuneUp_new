
import Foundation
import SwiftData
import Combine
import HealthKit

@MainActor
final class AppState: ObservableObject {
    @Published var today: DailySummary?
    @Published var last3: [DailySummary] = []
    @Published var all: [DailySummary] = []

    private var cancellables = Set<AnyCancellable>()

    let hk = HealthKitManager.shared
    let ml = MLLinearModel.shared

    func bootstrap(context: ModelContext) async {
        // Seed sample data on first launch
        try? await Task.sleep(nanoseconds: 150_000_000)
        //await seedIfNeeded(context: context)

        await reload(context: context)
        hk.requestAuthorization()
        //await fetchTodayFromHealthKit(context: context)
        await fetchLastNDaysFromHealthKit(context: context, n: 20)
        await updatePredictionForToday(context: context)
    }

    func reload(context: ModelContext) async {
        let descriptor = FetchDescriptor<DailySummary>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if let results = try? context.fetch(descriptor) {
            self.all = results
            self.last3 = Array(results.prefix(7)).sorted(by: { $0.date < $1.date })
            self.today = results.first(where: { Calendar.current.isDateInToday($0.date) }) ?? ensureToday(context: context)
        }
    }

    private func ensureToday(context: ModelContext) -> DailySummary {
        if let existing = all.first(where: { Calendar.current.isDateInToday($0.date) }) { return existing }
        let now = Date()
        let ds = DailySummary(date: now)
        context.insert(ds)
        try? context.save()
        return ds
    }
    /*
    func fetchTodayFromHealthKit(context: ModelContext) async {
        hk.fetchTodayStepsAndKcal { [weak self] steps, kcal in
            Task { @MainActor in
                guard let self else { return }
                let ds = self.ensureToday(context: context)
                ds.steps = steps
                ds.kcal = kcal
                try? context.save()
                await self.reload(context: context)
            }
        }
    } */
    
    func fetchFromHealthKit(for date: Date, context: ModelContext) async {
        hk.fetchStepsAndKcalByDate(for: date) { [weak self] steps, kcal in
            Task { @MainActor in
                guard let self else { return }

                let cal   = Calendar.current
                let start = cal.startOfDay(for: date)
                let key   = DailySummary.makeDateKey(start)

                // Existierenden Datensatz holen (robust direkt aus dem Store)
                let fetch = FetchDescriptor<DailySummary>(
                    predicate: #Predicate { $0.dateKey == key },
                    sortBy: [SortDescriptor(\.date)]
                )
                let existing = (try? context.fetch(fetch))?.first

                let ds: DailySummary
                if let found = existing {
                    // Nur steps & kcal überschreiben; andere Felder bleiben wie sie sind
                    found.steps = steps
                    found.kcal  = kcal
                    ds = found
                } else {
                    // Neu anlegen mit Defaults; steps/kcal setzen
                    let defaultSleepGoal = (UserSettings.shared as UserSettings?)?.sleepGoalMinutes ?? 8 * 60
                    let newDS = DailySummary(
                        date: start,
                        sleepDurationMinutes: 0,
                        bedTime: nil,
                        wakeTime: nil,
                        steps: steps,
                        kcal: kcal,
                        stressLevel: 0,
                        screenTimeMinutes: 0,
                        sleepGoalMinutes: defaultSleepGoal,
                        immuneScore: 0 // wird unten berechnet
                    )
                    context.insert(newDS)
                    ds = newDS
                }

                // ✅ IMMER: ImmuneScore neu berechnen (aus aktuellen Feldern)
                ds.immuneScore = MLLinearModel.shared.predict(
                    sleepMin: ds.sleepDurationMinutes,
                    steps: ds.steps,
                    kcal: ds.kcal,
                    stress: ds.stressLevel,
                    screenMin: ds.screenTimeMinutes
                )

                try? context.save()
                await self.reload(context: context)
            }
        }
    }
    
    func fetchLastNDaysFromHealthKit(context: ModelContext, n: Int = 10) async {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        for i in 0..<n {
            if let day = cal.date(byAdding: .day, value: -i, to: todayStart) {
                await fetchFromHealthKit(for: day, context: context)
            }
        }
        await reload(context: context)
    }



    func updatePredictionForToday(context: ModelContext) async {
        guard let ds = ensureToday(context: context) as DailySummary? else { return }
        let predicted = ml.predict(sleepMin: ds.sleepDurationMinutes, steps: ds.steps, kcal: ds.kcal, stress: ds.stressLevel, screenMin: ds.screenTimeMinutes)
        ds.immuneScore = predicted
        try? context.save()
        await reload(context: context)
    }

    // 7-day averages (including today if present)
    func averagesForLast3() -> (sleepMin: Int, steps: Int, kcal: Int, stress: Int, screenMin: Int) {
        let data: [DailySummary] = last3.isEmpty ? Array(all.prefix(3)) : last3
        guard !data.isEmpty else { return (0,0,0,0,0) }
        func avg(_ xs: [Int]) -> Int { Int(xs.reduce(0,+)) / xs.count }
        let sleep = avg(data.map { $0.sleepDurationMinutes })
        let steps = avg(data.map { $0.steps })
        let kcal = avg(data.map { $0.kcal })
        let stress = avg(data.map { $0.stressLevel })
        let screen = avg(data.map { $0.screenTimeMinutes })
        return (sleep, steps, kcal, stress, screen)
    }

    // Update (write) manual fields to today's entry
    func updateToday(context: ModelContext,
                     bedTime: Date? = nil,
                     wakeTime: Date? = nil,
                     sleepDurationMinutes: Int? = nil,
                     stress: Int? = nil,
                     screenMinutes: Int? = nil,
                     sleepGoalMinutes: Int? = nil) async {
        let ds = ensureToday(context: context)
        if let bedTime { ds.bedTime = bedTime }
        if let wakeTime { ds.wakeTime = wakeTime }
        if let sleepDurationMinutes { ds.sleepDurationMinutes = sleepDurationMinutes }
        if let stress { ds.stressLevel = stress }
        if let screenMinutes { ds.screenTimeMinutes = screenMinutes }
        if let sleepGoalMinutes { ds.sleepGoalMinutes = sleepGoalMinutes }
        try? context.save()
        await updatePredictionForToday(context: context)
    }

    // Train model from all stored days
    func updateModelFromData() async {
        let samples = all.map { ds in
            MLLinearModel.Sample(sleepMin: ds.sleepDurationMinutes,
                                 steps: ds.steps,
                                 kcal: ds.kcal,
                                 stress: ds.stressLevel,
                                 screenMin: ds.screenTimeMinutes,
                                 targetScore: ds.immuneScore)
        }
        MLLinearModel.shared.fit(samples: samples, epochs: 250, lr: 0.01)
        objectWillChange.send()
    }
}
