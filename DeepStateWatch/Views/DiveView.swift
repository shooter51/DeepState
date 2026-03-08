import SwiftUI
import WatchKit
import DiveCore

// Extend AscentRateStatus to be Equatable so onChange(of:) works
extension AscentRateMonitor.AscentRateStatus: @retroactive Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.safe, .safe): return true
        case (.warning, .warning): return true
        case (.critical, .critical): return true
        default: return false
        }
    }
}

struct DiveView: View {

    let viewModel: DiveViewModel

    @State private var lastHapticNDL: Int?
    @State private var lastHapticAscent: AscentRateMonitor.AscentRateStatus?
    @State private var safetyStopHapticFired = false

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
            }
        }
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack {
            // Elapsed time
            Text(formattedElapsedTime)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

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
        } else if viewModel.ndl <= 5 {
            Text("NDL: \(viewModel.ndl)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
        } else {
            Text("NDL: \(viewModel.ndl)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
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

            Spacer()

            // Battery placeholder
            HStack(spacing: 2) {
                Image(systemName: "battery.75percent")
                    .font(.system(size: 12))
                Text("87%")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.6))
        }
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
