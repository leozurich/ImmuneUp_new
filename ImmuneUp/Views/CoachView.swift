
import SwiftUI
import Combine

struct CoachView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.modelContext) private var context
    @State private var predicted: Int = 0
    @State private var explanation: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Zusammenfassung").font(.title2).bold()

                let avg = app.averagesForLast3()
                Group {
                    HStack { Text("Schlaf (Ø7):"); Spacer(); Text(formatDuration(avg.sleepMin)) }
                    HStack { Text("Schritte (Ø7):"); Spacer(); Text("\(avg.steps)") }
                    HStack { Text("Kcal (Ø7):"); Spacer(); Text("\(avg.kcal)") }
                    HStack { Text("Stress (Ø7):"); Spacer(); Text("\(avg.stress)") }
                    HStack { Text("Screen (Ø7):"); Spacer(); Text(formatDuration(avg.screenMin)) }
                }
                .padding(.horizontal)

                Divider()

                Text("Prediction für morgen").font(.title3).bold()
                Text("\(predicted) / 100")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .padding(.bottom, 8)
                Text(explanation).foregroundStyle(.secondary)

                Button("Model mit deinen Daten updaten") {
                    Task { await app.updateModelFromData(); await recompute() }
                }
                .buttonStyle(.borderedProminent)

                Divider()

                Text("Empfehlung").font(.title3).bold()
                Text(recommendationText())
                    .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle("Coach")
        .task { await recompute() }
    }

    func recompute() async {
        let avg = app.averagesForLast3()
        let p = MLLinearModel.shared.predict(sleepMin: avg.sleepMin, steps: avg.steps, kcal: avg.kcal, stress: avg.stress, screenMin: avg.screenMin)
        predicted = p
        explanation = "Wenn du dich ähnlich verhältst wie in den letzten 7 Tagen, liegt dein erwarteter Score um \(p)."
    }

    func recommendationText() -> String {
        guard let today = app.today else {
            return "Lege Ziele im Profil fest und füge Daten für heute hinzu, um konkrete Empfehlungen zu erhalten."
        }
        var tips: [String] = []

        // Heuristics: nudge towards better inputs
        if today.sleepDurationMinutes < today.sleepGoalMinutes {
            tips.append("Plane heute \(max(30, (today.sleepGoalMinutes - today.sleepDurationMinutes))) Minuten mehr Schlaf ein (früher ins Bett, Abendroutine).")
        }
        if today.stressLevel > 6 {
            tips.append("Baue 10–15 Min. Entspannung ein (Atemübung, Spaziergang), um den Stress zu senken.")
        }
        if today.screenTimeMinutes > 240 {
            tips.append("Reduziere heute deine Bildschirmzeit vor dem Schlafen (Night Shift, feste Offline-Zeit).")
        }
        if today.steps < 7500 {
            tips.append("Ziel: +2000 Schritte (z. B. 20–25 Min. flotter Spaziergang).")
        }
        if today.kcal < 400 {
            tips.append("Erhöhe die aktive Bewegung (z. B. Training), um auf ~400 kcal Aktivitätskalorien zu kommen.")
        }

        if tips.isEmpty {
            tips.append("Weiter so – halte Routinen stabil (Schlaf, Bewegung, Stressmanagement, weniger Bildschirmzeit).")
        }
        return tips.joined(separator: " ")
    }

    private func formatDuration(_ m: Int) -> String {
        let h = m/60
        let min = m%60
        return String(format: "%dh %02dmin", h, min)
    }
}
