
import SwiftUI
import SwiftData
import Combine

struct WeekKey: Hashable, Identifiable {
    var year: Int
    var week: Int
    var id: String { "\(year)-W\(week)" }
}

struct StatsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.modelContext) private var context
    

    @State private var selectedWeek: WeekKey?
    @State private var editing: DailySummary?        // ⬅️ NEW: current day being edited


    var weeks: [WeekKey] {
        //let cal = Calendar.current
        let weeks = Set(app.all.map { dateKey(for: $0.date) })
        return Array(weeks).sorted(by: { ($0.year, $0.week) > ($1.year, $1.week) })
    }

    var body: some View {
        VStack {
            if weeks.isEmpty {
                Text("Noch keine Daten.")
            } else {
                Picker("Woche", selection: $selectedWeek) {
                    ForEach(weeks) { w in
                        Text("\(w.id)").tag(Optional.some(w))
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                let days = daysForSelectedWeek()
                List(days) { ds in
                    VStack(alignment: .leading) {
                        // neu Text(dateString(ds.date)).font(.headline)
                        
                        HStack {
                            Text(dateString(ds.date)).font(.headline)
                            Spacer()
                            Button("✏️") { editing = ds }   // ⬅️ NEW: pencil button
                                .buttonStyle(.plain)
                                .accessibilityLabel("Bearbeiten")
                        }

                        HStack {
                            Label("\(ds.steps) Schritte", systemImage: "shoeprints.fill")
                            Spacer()
                            Label("\(ds.kcal) kcal", systemImage: "flame.fill")
                        }
                        HStack {
                            Label("Schlaf: \(formatDuration(ds.sleepDurationMinutes))", systemImage: "bed.double.fill")
                            Spacer()
                            Label("Stress: \(ds.stressLevel)", systemImage: "bolt.heart.fill")
                        }
                        HStack {
                            Label("Screen: \(formatDuration(ds.screenTimeMinutes))", systemImage: "iphone")
                            Spacer()
                            Label("Score: \(ds.immuneScore)", systemImage: "star.circle.fill")
                        }
                    }
                }.listStyle(.plain)
            }
        }
        .onAppear {
            if selectedWeek == nil { selectedWeek = weeks.first }
        }
        .navigationTitle("Statistiken")
        // ⬇️ NEW: Editor sheet
        .sheet(item: $editing) { day in
            DaySummaryEditor(day: day)
                .environmentObject(app)
                .environment(\.modelContext, context)
        }
    }

    private func daysForSelectedWeek() -> [DailySummary] {
        guard let sel = selectedWeek else { return [] }
        return app.all.filter { dateKey(for: $0.date) == sel }.sorted { $0.date < $1.date }
    }

    private func dateKey(for date: Date) -> WeekKey {
        let cal = Calendar.current
        let comps = cal.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
        return WeekKey(year: comps.yearForWeekOfYear ?? 0, week: comps.weekOfYear ?? 0)
    }

    private func dateString(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: d)
    }
    private func formatDuration(_ m: Int) -> String {
        let h = m/60
        let min = m%60
        return String(format: "%d:%02d h", h, min)
    }
    
    //neu
    private struct DaySummaryEditor: View {
        @Environment(\.modelContext) private var context
        @EnvironmentObject private var app: AppState
        @Environment(\.dismiss) private var dismiss

        @State var day: DailySummary

        // Local editable copies
        @State private var sleepHours: Double = 8.0
        @State private var stress: Double = 4
        @State private var screenHours: Double = 4.0
        

        var body: some View {
            NavigationStack {
                Form {
                    Section("Schlafdauer") {
                        HStack {
                            Text("Dauer")
                            Spacer()
                            Text(formatDuration(Int(sleepHours * 60)))
                                .font(.headline)
                        }
                        Slider(value: $sleepHours, in: 0...14, step: 0.25)
                    }
                    Section("Stress") {
                        HStack {
                            Text("Level")
                            Spacer()
                            Text("\(Int(stress))")
                                .font(.headline)
                        }
                        Slider(value: $stress, in: 0...10, step: 1)
                    }
                    Section("Bildschirmzeit") {
                        HStack {
                            Text("Dauer")
                            Spacer()
                            Text(formatDuration(Int(screenHours * 60)))
                                .font(.headline)
                        }
                        Slider(value: $screenHours, in: 0...12, step: 0.25)
                    }
                }
                .navigationTitle(Text(dateString(day.date)))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            dismiss() //schliesst die Ansicht
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            save()
                            dismiss() //nach dem Speichern schliessen
                        }
                            .bold()
                    }
                }
                .onAppear {
                    sleepHours = Double(day.sleepDurationMinutes) / 60.0
                    stress = Double(day.stressLevel)
                    screenHours = Double(day.screenTimeMinutes) / 60.0
                }
            }
        }
        
        private func save() {
            day.sleepDurationMinutes = Int(sleepHours * 60)
            day.stressLevel = Int(stress)
            day.screenTimeMinutes = Int(screenHours * 60)

            // Recompute ImmuneScore with your ML model
            let predicted = MLLinearModel.shared.predict(
                sleepMin: day.sleepDurationMinutes,
                steps: day.steps,
                kcal: day.kcal,
                stress: day.stressLevel,
                screenMin: day.screenTimeMinutes
            )
            day.immuneScore = predicted

            try? context.save()
            // Refresh parent lists
            Task { @MainActor in
                await app.reload(context: context)
            }

            // Programmatic dismiss
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        }
        private func formatDuration(_ m: Int) -> String {
            let h = m/60
            let min = m%60
            return String(format: "%d:%02d h", h, min)
        }
        private func dateString(_ d: Date) -> String {
            let df = DateFormatter()
            df.dateStyle = .medium
            return df.string(from: d)
        }

        
    }

}
