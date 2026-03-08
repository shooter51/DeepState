import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DiveLogListView()
                .tabItem {
                    Label("Dive Log", systemImage: "water.waves")
                }

            DivePlannerView()
                .tabItem {
                    Label("Planner", systemImage: "chart.line.downtrend.xyaxis")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
}
