import SwiftUI
import SwiftData
import DiveCore

// Note: For production, configure in build settings / Info.plist:
// - WKApplication: true
// - UIBackgroundModes: workout-processing
// - NSHealthShareUsageDescription / NSHealthUpdateUsageDescription

@main
struct DeepStateWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DiveSession.self, DepthSample.self, DiveSettings.self])
    }
}
