import SwiftUI
import SwiftData
import DiveCore

@main
struct DeepStateApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [DiveSession.self, DepthSample.self, DiveSettings.self])
    }
}
