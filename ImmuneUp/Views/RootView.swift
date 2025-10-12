
import SwiftUI
import SwiftData
import Combine

struct RootView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var app = AppState()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            StatsView()
                .tabItem { Label("Statistiken", systemImage: "chart.bar.xaxis") }
            CoachView()
                .tabItem { Label("Coach", systemImage: "figure.walk.motion") }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .task { await app.bootstrap(context: context) }
        .environmentObject(app)
    }
}
