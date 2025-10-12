
import Foundation
import HealthKit
import Combine

final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    
    private init() {}
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.isAuthorized = false
            return
        }
        let readTypes: Set = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, _ in
            DispatchQueue.main.async {
                self.isAuthorized = success
            }
        }
    }
    
    // MARK: - NEU: Schritte & Kcal für EINEN TAG (00:00–24:00, lokale Zeit)
       func fetchStepsAndKcalByDate(for date: Date, completion: @escaping (_ steps: Int, _ kcal: Int) -> Void) {
           let calendar = Calendar.current
           let startOfDay = calendar.startOfDay(for: date)
           guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
               DispatchQueue.main.async { completion(0, 0) }
               return
           }

           let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
           let kcalType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

           // Wichtig: Tagesfenster ist startOfDay ... endOfDay (nicht "jetzt"),
           // damit es auch für zurückliegende Tage funktioniert.
           let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

           // 1) Schritte
           let stepsQuery = HKStatisticsQuery(quantityType: stepType,
                                              quantitySamplePredicate: predicate,
                                              options: .cumulativeSum) { _, stats, _ in
               let steps = Int(stats?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)

               // 2) Kcal
               let kcalQuery = HKStatisticsQuery(quantityType: kcalType,
                                                 quantitySamplePredicate: predicate,
                                                 options: .cumulativeSum) { _, stats2, _ in
                   let kcal = Int(stats2?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0)
                   DispatchQueue.main.async { completion(steps, kcal) }
               }
               self.healthStore.execute(kcalQuery)
           }
           healthStore.execute(stepsQuery)
       }
}
