
import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    @EnvironmentObject private var app: AppState

    var trendData: [TrendPoint] {
        let days = app.last3.isEmpty ? app.all.prefix(3).reversed() : app.last3
        return days.map { TrendPoint(date: $0.date, score: $0.immuneScore) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ScoreCard(score: app.today?.immuneScore ?? 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trend (letzte Tage)").font(.headline)
                    TrendChart(data: trendData)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SleepTile()
                    MovementTile()
                    StressTile()
                    ScreenTimeTile()
                }
            }
            .padding()
        }
        .navigationTitle("Home")
    }
}

//repo
