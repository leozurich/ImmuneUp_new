
import SwiftUI
import Combine

struct SleepTile: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var app: AppState
    @State private var bedTime = Date()
    @State private var wakeTime = Date()
    @State private var sleepHours: Double = 8.0
    @State private var showingEditor = false
    
    @StateObject private var settings = UserSettings.shared
    //NEU
    

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bed.double.fill")
                Text("Schlaf")
                Spacer()
                Button("Bearbeiten") { showingEditor = true }
            }.font(.headline)

            if let ds = app.today {
                //Text("Einschlafzeit: \(formatTime(ds.bedTime))")
                Text("Aufwachzeit: \(formatTime(ds.wakeTime))")
                Text("Dauer: \(formatDuration(ds.sleepDurationMinutes))")
                Text("Einschlafzeit (heute): \(formatTime(predictedBedtimeToday()))")
                
                
            } else {
                Text("Keine Daten für heute").foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                Form {
                    DatePicker("Einschlafzeit (gestern)", selection: $bedTime, displayedComponents: [.hourAndMinute])
                    DatePicker("Aufwachzeit", selection: $wakeTime, displayedComponents: [.hourAndMinute])
                    HStack {
                        Text("Schlafdauer")
                        Spacer()
                        let mins = Int(sleepHours * 60.0)
                        //Text(String(format: "%.1f h", sleepHours))
                        Text("\(formatDuration(mins))  ")
                                    .font(.headline)
                    }
                    //Slider(value: $sleepHours, in: 0...16, step: 0.25)
                    Slider(value: $sleepHours, in: 0...16, step: 0.25) {
                            Text("Schlafdauer")
                        } minimumValueLabel: {
                            Text("0h")
                        } maximumValueLabel: {
                            Text("16h")
                        }
                    }
                
                
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                Task { @MainActor in
                                    let minutes = Int(sleepHours * 60.0)
                                    await app.updateToday(
                                        context: context,
                                        bedTime: bedTime,
                                        wakeTime: wakeTime,
                                        sleepDurationMinutes: minutes
                                    )
                                    showingEditor = false
                                }
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { showingEditor = false }
                        }
                    }
                
                
                
                }
                .navigationTitle("Schlaf bearbeiten")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { showingEditor = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            Task { @MainActor in
                                let minutes = Int(sleepHours * 60.0)
                                await app.updateToday(context: context,
                                                      bedTime: bedTime,
                                                      wakeTime: wakeTime,
                                                      sleepDurationMinutes: minutes)
                                showingEditor = false
                            }
                        }
                    }
                }
                
                
                // ⬇️ HIER die Kopplungs-Logik als Modifier anhängen
                .onChange(of: sleepHours) { _, newVal in
                    let mins = Int(newVal * 60.0)
                    bedTime = bedTimeFrom(wake: wakeTime, durationMin: mins)
                }
                .onChange(of: bedTime) { _, _ in
                    let mins = minutesBetween(bed: bedTime, wake: wakeTime)
                    sleepHours = Double(mins) / 60.0
                }
                .onChange(of: wakeTime) { _, _ in
                    let mins = minutesBetween(bed: bedTime, wake: wakeTime)
                    sleepHours = Double(mins) / 60.0
                }
                .onAppear {
                    if let ds = app.today {
                        bedTime = ds.bedTime ?? bedTime
                        wakeTime = ds.wakeTime ?? wakeTime
                        if ds.sleepDurationMinutes > 0 {
                            sleepHours = Double(ds.sleepDurationMinutes) / 60.0
                        } else {
                            let mins = minutesBetween(bed: bedTime, wake: wakeTime)
                            sleepHours = Double(mins) / 60.0
                        }
                    } else {
                        let mins = minutesBetween(bed: bedTime, wake: wakeTime)
                        sleepHours = Double(mins) / 60.0
                    }
                }
            
            
            
            }
        }
    
        private func mondayIndex(for date: Date) -> Int {
            let w = Calendar.current.component(.weekday, from: date) // iOS: 1=So … 7=Sa
            return ((w + 5) % 7) + 1 // → 1=Mo … 7=So
        }
        
        // Erzeuge eine Date mit HH:mm auf einem bestimmten Kalendertag
        private func timeOnDay(_ day: Date, minutesSinceMidnight mins: Int) -> Date {
            let cal = Calendar.current
            let h = mins / 60, m = mins % 60
            return cal.date(bySettingHour: h, minute: m, second: 0, of: day) ?? day
        }
        
        // Aufwachzeit aus Settings für morgen (als Date auf MORGEN)
        private func wakeTimeTomorrowFromSettings() -> Date {
            let cal = Calendar.current
            let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
            let mondayIdx = mondayIndex(for: tomorrow)
            let mins = settings.wakeMinutes(for: mondayIdx)
            return timeOnDay(tomorrow, minutesSinceMidnight: mins)
        }

        // Prognostizierte Einschlafzeit HEUTE (heutiger Abend), basierend auf Aufwachzeit von morgen
        private func predictedBedtimeToday() -> Date {
            let cal = Calendar.current
            let wakeTomorrow = wakeTimeTomorrowFromSettings()
            // Schlafziel in Minuten abziehen → ergibt die Einschlafzeit HEUTE (kann am Vortag  ─ also heute ─ liegen)
            return cal.date(byAdding: .minute, value: -settings.sleepGoalMinutes, to: wakeTomorrow) ?? Date()
        }

        // Dein vorhandenes Format
        private func formatTime(_ d: Date?) -> String {
            guard let d else { return "—" }
            let df = DateFormatter()
            df.timeStyle = .short
            return df.string(from: d)
        }

    
    }

    private func formatTime(_ d: Date?) -> String {
        guard let d else { return "—" }
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: d)
    }
    private func formatDuration(_ m: Int) -> String {
        let h = m/60
        let min = m%60
        return String(format: "%d:%02d h", h, min)
    }
    
    private func normalized(_ time: Date) -> Date {
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: Date())!
    }
    private func minutesBetween(bed: Date, wake: Date) -> Int {
        let cal = Calendar.current
        let b = normalized(bed)
        var w = normalized(wake)
        if w <= b { w = cal.date(byAdding: .day, value: 1, to: w)! }
        return max(0, Int(w.timeIntervalSince(b) / 60))
    }

    private func bedTimeFrom(wake: Date, durationMin: Int) -> Date {
        let cal = Calendar.current
        let w = normalized(wake)
        return cal.date(byAdding: .minute, value: -durationMin, to: w)!
    }
    








struct MovementTile: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.walk")
                Text("Bewegung")
            }.font(.headline)
            if let ds = app.today {
                Label("\(ds.steps) Schritte", systemImage: "shoeprints.fill")
                Label("\(ds.kcal) kcal", systemImage: "flame.fill")
            } else {
                Text("Keine Daten für heute").foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

struct StressTile: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var app: AppState
    @State private var stress: Double = 4
    @State private var showing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.heart.fill")
                Text("Stresslevel (1–10)")
                Spacer()
                Button("Anpassen") { showing = true }
            }.font(.headline)
            if let ds = app.today {
                Text("\(ds.stressLevel)")
                    .font(.title2).bold()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .sheet(isPresented: $showing) {
            NavigationStack {
                Form {
                    HStack {
                        Text("Stress")
                        Spacer()
                        Text("\(Int(stress))")
                    }
                    Slider(value: $stress, in: 0...10, step: 1)
                }
                .navigationTitle("Stress einstellen")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            Task { @MainActor in
                                await app.updateToday(context: context, stress: Int(stress))
                                showing = false
                            }
                        }
                    }
                }
                .onAppear {
                    if let ds = app.today { stress = Double(ds.stressLevel) }
                }
            }
        }
    }
}

struct ScreenTimeTile: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var app: AppState
    @State private var hours: Double = 4.0
    @State private var showing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "iphone")
                Text("Bildschirmzeit")
                Spacer()
                Button("Anpassen") { showing = true }
            }.font(.headline)
            if let ds = app.today {
                Text(formatDuration(ds.screenTimeMinutes))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .sheet(isPresented: $showing) {
            NavigationStack {
                Form {
                    HStack {
                        Text("Stunden")
                        Spacer()
                        Text(String(format: "%.1f h", hours))
                    }
                    Slider(value: $hours, in: 0...12, step: 0.25)
                }
                .navigationTitle("Bildschirmzeit")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            Task { @MainActor in
                                await app.updateToday(context: context, screenMinutes: Int(hours*60))
                                showing = false
                            }
                        }
                    }
                }
                .onAppear {
                    if let ds = app.today { hours = Double(ds.screenTimeMinutes)/60.0 }
                }
            }
        }
    }

    private func formatDuration(_ m: Int) -> String {
        let h = m/60
        let min = m%60
        return String(format: "%d:%02d h", h, min)
    }
}


