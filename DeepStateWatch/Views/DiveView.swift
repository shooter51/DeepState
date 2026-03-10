import SwiftUI
import WatchKit
import DiveCore



struct DiveView: View {

    let viewModel: DiveViewModel

    @State private var lastHapticNDL: Int?
    @State private var lastHapticAscent: AscentRateMonitor.AscentRateStatus?
    @State private var safetyStopHapticFired = false
    @State private var depthWarningHapticTimer: Timer?
    @State private var lastDepthLimitStatus: DepthLimits.DepthLimitStatus = .safe
    @State private var batteryLevel: Float = -1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top row: elapsed time and NDL
                    topRow
                        .frame(height: geo.size.height * 0.2)

                    // Center: current depth
                    depthDisplay
                        .frame(height: geo.size.height * 0.5)

                    // Bottom row: temp, ascent rate, battery
                    bottomRow
                        .frame(height: geo.size.height * 0.2)
                }
                .padding(.horizontal, 4)

                // Safety stop overlay
                if viewModel.safetyStopIsActive {
                    safetyStopOverlay(size: geo.size)
                }

                // Depth limit overlays
                depthLimitOverlay

                // Sensor stale overlay
                if viewModel.isSensorDataStale {
                    sensorStaleOverlay
                }
            }
        }
        .onChange(of: viewModel.ndl) { _, newNDL in
            fireNDLHaptics(ndl: newNDL)
        }
        .onChange(of: viewModel.ascentRateStatus) { _, newStatus in
            fireAscentHaptics(status: newStatus)
        }
        .onChange(of: viewModel.safetyStopIsActive) { _, isStop in
            if isStop && !safetyStopHapticFired {
                WKInterfaceDevice.current().play(.click)
                safetyStopHapticFired = true
            } else if !isStop {
                safetyStopHapticFired = false
            }
        }
        .onChange(of: viewModel.depthLimitStatus) { _, newStatus in
            fireDepthLimitHaptics(status: newStatus)
        }
        .onChange(of: viewModel.isSensorDataStale) { _, isStale in
            if isStale {
                WKInterfaceDevice.current().play(.failure)
            }
        }
        .onAppear {
            let device = WKInterfaceDevice.current()
            device.isBatteryMonitoringEnabled = true
            batteryLevel = device.batteryLevel
        }
        .onChange(of: viewModel.elapsedTime) { _, newTime in
            if Int(newTime) % 60 == 0 {
                batteryLevel = WKInterfaceDevice.current().batteryLevel
            }
        }
        .onDisappear {
            depthWarningHapticTimer?.invalidate()
            depthWarningHapticTimer = nil
        }
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack {
            // Elapsed time
            Text(formattedElapsedTime)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityLabel("Elapsed time \(formattedElapsedTime)")

            Spacer()

            // NDL or Deco
            ndlDisplay
        }
    }

    private var formattedElapsedTime: String {
        let minutes = Int(viewModel.elapsedTime) / 60
        let seconds = Int(viewModel.elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @ViewBuilder
    private var ndlDisplay: some View {
        if viewModel.ceilingDepth > 0 {
            Text("DECO: \(String(format: "%.1f", viewModel.ceilingDepth))m")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.red)
                .accessibilityLabel("Decompression required, ceiling \(String(format: "%.1f", viewModel.ceilingDepth)) meters")
        } else if viewModel.ndl <= 5 {
            Text("NDL: \(viewModel.ndl)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
                .accessibilityLabel("No decompression limit \(viewModel.ndl) minutes")
        } else {
            Text("NDL: \(viewModel.ndl)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .accessibilityLabel("No decompression limit \(viewModel.ndl) minutes")
        }
    }

    // MARK: - Depth Display

    private var depthDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(String(format: "%.1f", viewModel.currentDepth))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(depthColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("m")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(depthColor.opacity(0.7))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current depth \(String(format: "%.1f", viewModel.currentDepth)) meters")
    }

    private var depthColor: Color {
        if viewModel.ceilingDepth > 0 {
            return .red
        } else if viewModel.ndl <= 5 {
            return .yellow
        } else {
            return .green
        }
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack {
            // Temperature
            Text(String(format: "%.0f\u{00B0}C", viewModel.temperature))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.cyan)
                .accessibilityLabel("Temperature \(String(format: "%.0f", viewModel.temperature)) degrees")

            Spacer()

            // Ascent rate
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%.0f", viewModel.ascentRate))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                Text("m/m")
                    .font(.system(size: 10))
            }
            .foregroundStyle(ascentRateColor)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ascent rate \(String(format: "%.0f", viewModel.ascentRate)) meters per minute, \(viewModel.ascentRateStatus)")

            Spacer()

            // Battery
            HStack(spacing: 2) {
                Image(systemName: batteryIconName)
                    .font(.system(size: 12))
                Text(batteryText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var batteryText: String {
        guard batteryLevel >= 0 else { return "--%" }
        return "\(Int(batteryLevel * 100))%"
    }

    private var batteryIconName: String {
        guard batteryLevel >= 0 else { return "battery.0percent" }
        let pct = Int(batteryLevel * 100)
        if pct >= 75 { return "battery.100percent" }
        if pct >= 50 { return "battery.75percent" }
        if pct >= 25 { return "battery.50percent" }
        return "battery.25percent"
    }

    private var ascentRateColor: Color {
        switch viewModel.ascentRateStatus {
        case .safe: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    // MARK: - Safety Stop Overlay

    private func safetyStopOverlay(size: CGSize) -> some View {
        let remaining = viewModel.safetyStopRemainingTime
        let total = viewModel.safetyStopDuration
        let progress = 1.0 - (remaining / total)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60

        return ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 6)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("STOP")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Text(String(format: "%d:%02d", minutes, seconds))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.yellow)
                }
            }
        }
    }

    // MARK: - Depth Limit Overlay

    @ViewBuilder
    private var depthLimitOverlay: some View {
        switch viewModel.depthLimitStatus {
        case .safe:
            EmptyView()

        case .approachingLimit:
            VStack {
                Text("DEPTH ALARM: \(String(format: "%.1f", viewModel.currentDepth))m")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.yellow, in: RoundedRectangle(cornerRadius: 6))
                Spacer()
            }
            .padding(.top, 2)

        case .maxDepthWarning:
            ZStack {
                Color.red.ignoresSafeArea()

                VStack(spacing: 8) {
                    Text("MAX DEPTH")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("ASCEND NOW")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(String(format: "%.1f m", viewModel.currentDepth))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

        case .depthLimitReached:
            ZStack {
                Color.red.ignoresSafeArea()

                VStack(spacing: 8) {
                    Text("DEPTH LIMIT REACHED")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("ASCEND NOW")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(String(format: "%.1f m", viewModel.currentDepth))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("NDL: ---")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Sensor Stale Overlay

    private var sensorStaleOverlay: some View {
        ZStack {
            Color.orange.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 8) {
                Text("SENSOR DATA STALE")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Last: \(String(format: "%.1f", viewModel.currentDepth)) m")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("NDL: ---")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Depth Limit Haptics

    private func fireDepthLimitHaptics(status: DepthLimits.DepthLimitStatus) {
        // Stop any existing continuous haptic timer
        depthWarningHapticTimer?.invalidate()
        depthWarningHapticTimer = nil

        switch status {
        case .safe:
            break
        case .approachingLimit:
            WKInterfaceDevice.current().play(.notification)
        case .maxDepthWarning, .depthLimitReached:
            // Fire continuous haptic every second
            WKInterfaceDevice.current().play(.stop)
            depthWarningHapticTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                WKInterfaceDevice.current().play(.stop)
            }
        }
        lastDepthLimitStatus = status
    }

    // MARK: - Haptics

    private func fireNDLHaptics(ndl: Int) {
        if ndl <= 5 && (lastHapticNDL == nil || lastHapticNDL! > 5) {
            WKInterfaceDevice.current().play(.notification)
        }
        if ndl <= 0 && (lastHapticNDL == nil || lastHapticNDL! > 0) {
            WKInterfaceDevice.current().play(.failure)
        }
        lastHapticNDL = ndl
    }

    private func fireAscentHaptics(status: AscentRateMonitor.AscentRateStatus) {
        guard status != lastHapticAscent else { return }
        switch status {
        case .warning:
            WKInterfaceDevice.current().play(.directionUp)
        case .critical:
            WKInterfaceDevice.current().play(.stop)
        case .safe:
            break
        }
        lastHapticAscent = status
    }
}

#Preview {
    DiveView(viewModel: DiveViewModel(gasMix: .air))
}
