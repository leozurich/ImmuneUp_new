
import SwiftUI
import Combine
import UserNotifications

final class UserSettings: ObservableObject {
    static let shared = UserSettings()
       
        @Published var sleepGoalMinutes: Int
        @Published var stepGoal: Int
        @Published var kcalGoal: Int
        @Published var screenGoalMinutes: Int
        @Published var notificationsEnabled: Bool
        @Published var weekdayWakeMinutes: [Int: Int] {
            didSet {
                let dict = Dictionary(uniqueKeysWithValues: weekdayWakeMinutes.map { (String($0.key), $0.value) })
                UserDefaults.standard.set(dict, forKey: "weekdayWakeMinutes.mon1sun7")
            }
        }
        
        private let defaultWakeMinutes = 7 * 60 // 07:00

        
    
        private init() {
                let d = UserDefaults.standard

                // Rohwerte holen
                let rawSleep  = d.integer(forKey: "sleepGoalMinutes")
                let rawSteps  = d.integer(forKey: "stepGoal")
                let rawKcal   = d.integer(forKey: "kcalGoal")
                let rawScreen = d.integer(forKey: "screenGoalMinutes")
                let notif     = d.bool(forKey: "notificationsEnabled")
            
            
                if let stored = d.dictionary(forKey: "weekdayWakeMinutes.mon1sun7") as? [String: Int] {
                        var map: [Int: Int] = [:]
                        for (k, v) in stored { if let ik = Int(k) { map[ik] = v } }
                        self.weekdayWakeMinutes = map
                    } else {
                        var map: [Int: Int] = [:]
                        for wd in 1...7 { map[wd] = defaultWakeMinutes } // Mo–So = 07:00
                        self.weekdayWakeMinutes = map
                        let dict = Dictionary(uniqueKeysWithValues: map.map { (String($0.key), $0.value) })
                        d.set(dict, forKey: "weekdayWakeMinutes.mon1sun7")
                    }
                
                

                // Erst ALLE Properties initialisieren (kein Zugriff auf self vorher!)
                self.sleepGoalMinutes   = (rawSleep  == 0 ? 8*60  : rawSleep)
                self.stepGoal           = (rawSteps  == 0 ? 7500  : rawSteps)
                self.kcalGoal           = (rawKcal   == 0 ? 400   : rawKcal)
                self.screenGoalMinutes  = (rawScreen == 0 ? 240   : rawScreen)
                self.notificationsEnabled = notif
            }
    
    // Zugriff/Änderung
        func wakeMinutes(for mondayIndex: Int) -> Int {
            weekdayWakeMinutes[mondayIndex] ?? defaultWakeMinutes
        }

        func setWakeMinutes(_ minutes: Int, for mondayIndex: Int) {
            var map = weekdayWakeMinutes
            map[mondayIndex] = max(0, min(24*60 - 1, minutes))
            weekdayWakeMinutes = map
        }

/*
    @Published var sleepGoalMinutes: Int {
        didSet { UserDefaults.standard.set(sleepGoalMinutes, forKey: "sleepGoalMinutes") }
    }
    @Published var stepGoal: Int {
        didSet { UserDefaults.standard.set(stepGoal, forKey: "stepGoal") }
    }
    @Published var kcalGoal: Int {
        didSet { UserDefaults.standard.set(kcalGoal, forKey: "kcalGoal") }
    }
    @Published var screenGoalMinutes: Int {
        didSet { UserDefaults.standard.set(screenGoalMinutes, forKey: "screenGoalMinutes") }
    }
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            if notificationsEnabled { Self.requestNotifications() } else { Self.removePending() }
        }
    }
 

    private init() {
        self.sleepGoalMinutes = UserDefaults.standard.integer(forKey: "sleepGoalMinutes")
        if self.sleepGoalMinutes == 0 { self.sleepGoalMinutes = 8*60 }
        self.stepGoal = UserDefaults.standard.integer(forKey: "stepGoal")
        if self.stepGoal == 0 { self.stepGoal = 7500 }
        self.kcalGoal = UserDefaults.standard.integer(forKey: "kcalGoal")
        if self.kcalGoal == 0 { self.kcalGoal = 400 }
        self.screenGoalMinutes = UserDefaults.standard.integer(forKey: "screenGoalMinutes")
        if self.screenGoalMinutes == 0 { self.screenGoalMinutes = 240 }
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    }
*/
    static func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound]) { granted, _ in
            if granted {
                scheduleDailyReminder()
            }
        }
    }

    static func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Tagesdaten ausfüllen"
        content.body = "Schlaf, Stress & Bildschirmzeit für heute prüfen."
        var date = DateComponents()
        date.hour = 21; date.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let req = UNNotificationRequest(identifier: "daily.reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    static func removePending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily.reminder"])
    }
}

struct ProfileView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.modelContext) private var context
    @StateObject private var settings = UserSettings.shared
    
    var body: some View {
        Form {
            Section("Ziele") {
                Stepper("Schlafziel: \(formatDuration(settings.sleepGoalMinutes))", value: $settings.sleepGoalMinutes, in: 60...14*60, step: 15)
                Stepper("Schritteziel: \(settings.stepGoal)", value: $settings.stepGoal, in: 1000...30000, step: 500)
                Stepper("Kcal Ziel: \(settings.kcalGoal)", value: $settings.kcalGoal, in: 50...3000, step: 50)
                Stepper("Bildschirmzeit Ziel: \(formatDuration(settings.screenGoalMinutes))", value: $settings.screenGoalMinutes, in: 0...12*60, step: 15)
            }
            Section("Wochenplan Aufstehzeit") {
                
                ForEach(1...7, id: \.self) { mondayIdx in
                    HStack {
                        Text(weekdayNameForMondayIndex(mondayIdx))   // „Montag“, „Dienstag“, …
                        Spacer()
                        DatePicker("",
                                   selection: bindingForMondayWake(mondayIdx),
                                   displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .frame(maxWidth: 120)
                    }
                }
            }
            
            
            
            
            Section("Benachrichtigungen") {
                Toggle("Pushs erlauben (tägliche Erinnerung 21:00)", isOn: $settings.notificationsEnabled)
            }
            Section("ML-Modell") {
                Text("Gewichte: \(MLLinearModel.shared.weights.map{ String(format: "%.2f", $0) }.joined(separator: ", "))")
                Text("Bias: \(String(format: "%.2f", MLLinearModel.shared.bias))")
                Button("Modell auf Grundeinstellungen zurücksetzen") {
                    MLLinearModel.shared.weights = Array(repeating: 0.2, count: 5)
                    MLLinearModel.shared.bias = 0
                    MLLinearModel.shared.save()
                }
            }
        }
        .navigationTitle("Profil")
        .onChange(of: settings.sleepGoalMinutes) { _, new in
            Task { @MainActor in
                await app.updateToday(context: context, sleepGoalMinutes: new)
            }
        }
    }
    
    private func formatDuration(_ m: Int) -> String {
        let h = m/60
        let min = m%60
        return String(format: "%d:%02d h", h, min)
    }
    
    private func weekdayNameForMondayIndex(_ mondayIdx: Int) -> String {
        // Lange Namen (wie in Health-Listen)
        let long = ["Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag","Sonntag"]
        return long[mondayIdx - 1]
        // Für kurze Labels alternativ:
        // let short = ["Mo","Di","Mi","Do","Fr","Sa","So"]; return short[mondayIdx - 1]
    }

    private func dateFromMinutes(_ m: Int) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: m/60, minute: m%60, second: 0, of: Date()) ?? Date()
    }

    private func minutesFromDate(_ d: Date) -> Int {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour,.minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func bindingForMondayWake(_ mondayIdx: Int) -> Binding<Date> {
        Binding<Date>(
            get: {
                let mins = settings.wakeMinutes(for: mondayIdx)
                return dateFromMinutes(mins)
            },
            set: { newDate in
                settings.setWakeMinutes(minutesFromDate(newDate), for: mondayIdx)
            }
        )
    }

    
    
    
    
    
    
}
