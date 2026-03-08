import SwiftUI
import DiveCore

struct ContentView: View {

    @State private var diveViewModel = DiveViewModel(gasMix: .air, gfLow: 0.40, gfHigh: 0.85)
    @State private var sensorBridge = DiveSensorBridge()
    @State private var updateTimer: Timer?

    var body: some View {
        Group {
            switch diveViewModel.phase {
            case .surface, .predive:
                PreDiveView { gasMix, gfLow, gfHigh in
                    diveViewModel.reconfigure(gasMix: gasMix, gfLow: gfLow, gfHigh: gfHigh)
                    diveViewModel.startDive()
                    sensorBridge.startMonitoring()
                    startUpdateLoop()
                }

            case .descending, .atDepth, .ascending, .safetyStop:
                TabView {
                    DiveView(viewModel: diveViewModel)
                    DetailView(viewModel: diveViewModel)
                }
                .tabViewStyle(.verticalPage)
                .onAppear { startUpdateLoop() }

            case .surfaceInterval:
                PostDiveView(viewModel: diveViewModel) {
                    stopUpdateLoop()
                    diveViewModel.resetForNewDive()
                    sensorBridge.stopMonitoring()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startUpdateLoop() {
        stopUpdateLoop()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            diveViewModel.updateDepth(sensorBridge.depth)
            diveViewModel.updateTemperature(sensorBridge.temperature)
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

#Preview {
    ContentView()
}
