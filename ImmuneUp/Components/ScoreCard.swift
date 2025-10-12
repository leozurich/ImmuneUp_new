
import SwiftUI
import Combine

struct ScoreCard: View {
    var score: Int
    var body: some View {
        VStack(spacing: 6) {
            Text("ImmuneScore")
                .font(.headline)
            Text("\(score)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)).shadow(radius: 2))
    }
}
