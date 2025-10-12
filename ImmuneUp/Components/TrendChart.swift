
import SwiftUI
import Charts
import Combine

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Int
}

struct TrendChart: View {
    var data: [TrendPoint]

    var body: some View {
        Chart(data) { p in
            LineMark(x: .value("Datum", p.date),
                     y: .value("Score", p.score))
            PointMark(x: .value("Datum", p.date),
                      y: .value("Score", p.score))
        }
        .chartXAxis { AxisMarks(values: .stride(by: .day)) }
        .frame(height: 180)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}
