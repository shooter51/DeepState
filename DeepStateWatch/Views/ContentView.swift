import SwiftUI
import WatchKit
import DiveCore

struct ContentView: View {

    @State private var diveViewModel = DiveViewModel(gasMix: .air, gfLow: 0.40, gfHigh: 0.85)
    @State private var sensorBridge = DiveSensorBridge()
    @State private var updateTimer: Timer?
    @State private var runtimeManager = ExtendedRuntimeManager()
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showRecovery = TissueStatePersistence.hasInterruptedSession()
    @State private var persistCounter: Int = 0

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            } else if showRecovery {
                SessionRecoveryView(
                    onResume: {
                        if let state = TissueStatePersistence.loadPersistedState() {
                            diveViewModel.resumeFromPersistedState(state)
                            sensorBridge.startMonitoring()
                            runtimeManager.onSessionExpiring = { TissueStatePersistence.persist(manager: diveViewModel.manager) }
                            runtimeManager.startSession()
                            startUpdateLoop()
                        }
                        showRecovery = false
                    },
                    onEnd: {
                        TissueStatePersistence.clearPersistedState()
                        showRecovery = false
                    }
                )
            } else {
                diveContent
            }
        }
        .preferredColorScheme(.dark)
    }

    private var diveContent: some View {
        Group {
            switch diveViewModel.phase {
            case .surface, .predive:
                PreDiveView { gasMix, gfLow, gfHigh in
                    diveViewModel.reconfigure(gasMix: gasMix, gfLow: gfLow, gfHigh: gfHigh)
                    diveViewModel.startDive()
                    sensorBridge.startMonitoring()
                    runtimeManager.onSessionExpiring = { TissueStatePersistence.persist(manager: diveViewModel.manager) }
                    runtimeManager.startSession()
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
                    sensorBridge.stopMonitoring()
                    stopUpdateLoop()
                    runtimeManager.endSession()
                    TissueStatePersistence.clearPersistedState()
                    diveViewModel.resetForNewDive()
                }
            }
        }
    }

    private func startUpdateLoop() {
        stopUpdateLoop()
        persistCounter = 0
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            diveViewModel.updateDepth(sensorBridge.depth)
            diveViewModel.updateTemperature(sensorBridge.temperature)
            diveViewModel.checkSensorStaleness()

            // Auto-stop when dive ends (e.g. surfacing for 5+ seconds)
            if diveViewModel.phase == .surfaceInterval {
                sensorBridge.stopMonitoring()
                stopUpdateLoop()
                runtimeManager.endSession()
                return
            }

            // Auto-persist tissue state every 5 seconds during active dive
            persistCounter += 1
            if persistCounter >= 5 {
                persistCounter = 0
                TissueStatePersistence.persist(manager: diveViewModel.manager)
            }
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
