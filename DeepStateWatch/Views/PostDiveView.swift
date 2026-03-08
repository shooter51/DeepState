import SwiftUI
import SwiftData
import DiveCore

struct PostDiveView: View {

    let viewModel: DiveViewModel
    var onNewDive: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var surfaceInterval: TimeInterval = 0
    @State private var surfaceTimer: Timer?
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header
                Text("DIVE COMPLETE")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .padding(.top, 4)

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    statCell(label: "Max Depth", value: String(format: "%.1f m", viewModel.maxDepth))
                    statCell(label: "Duration", value: formattedDuration)
                    statCell(label: "Avg Depth", value: String(format: "%.1f m", viewModel.averageDepth))
                    statCell(label: "Min Temp", value: String(format: "%.0f\u{00B0}C", viewModel.minTemperature))
                }

                Divider().background(.gray)

                // Tissue Loading
                Text("TISSUE LOADING")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                tissueLoadingChart

                Divider().background(.gray)

                // Surface Interval
                HStack {
                    Text("SURFACE")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedSurfaceInterval)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }

                // Action Buttons
                VStack(spacing: 8) {
                    Button(action: saveDive) {
                        Text(saved ? "SAVED" : "SAVE")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(saved ? .gray : .blue, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(saved)

                    Button(action: onNewDive) {
                        Text("NEW DIVE")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.green, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 8)
        }
        .background(.black)
        .onAppear { startSurfaceTimer() }
        .onDisappear { stopSurfaceTimer() }
    }

    // MARK: - Stats

    private var formattedDuration: String {
        let minutes = Int(viewModel.elapsedTime) / 60
        let seconds = Int(viewModel.elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var formattedSurfaceInterval: String {
        let hours = Int(surfaceInterval) / 3600
        let minutes = (Int(surfaceInterval) % 3600) / 60
        let seconds = Int(surfaceInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tissue Loading Chart

    private var tissueLoadingChart: some View {
        let loadings = viewModel.tissueLoadingPercent

        return VStack(spacing: 2) {
            ForEach(0..<16, id: \.self) { i in
                HStack(spacing: 4) {
                    Text("\(i + 1)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, alignment: .trailing)

                    GeometryReader { geo in
                        let loading = i < loadings.count ? loadings[i] : 0
                        let width = geo.size.width * min(loading / 100.0, 1.2)

                        Rectangle()
                            .fill(tissueColor(loading: loading))
                            .frame(width: max(1, width), height: geo.size.height)
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func tissueColor(loading: Double) -> Color {
        if loading > 80 { return .red }
        if loading > 50 { return .yellow }
        return .green
    }

    // MARK: - Surface Timer

    private func startSurfaceTimer() {
        updateSurfaceInterval()
        surfaceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateSurfaceInterval()
        }
    }

    private func stopSurfaceTimer() {
        surfaceTimer?.invalidate()
        surfaceTimer = nil
    }

    private func updateSurfaceInterval() {
        if let start = viewModel.surfaceIntervalStart {
            surfaceInterval = Date().timeIntervalSince(start)
        }
    }

    // MARK: - Save

    private func saveDive() {
        let session = DiveSession(
            startDate: viewModel.surfaceIntervalStart?.addingTimeInterval(-viewModel.elapsedTime) ?? Date(),
            endDate: viewModel.surfaceIntervalStart,
            maxDepth: viewModel.maxDepth,
            avgDepth: viewModel.averageDepth,
            duration: viewModel.elapsedTime,
            minTemp: viewModel.minTemperature,
            maxTemp: viewModel.temperature,
            o2Percent: Int(viewModel.gasMix.o2Fraction * 100),
            gfLow: viewModel.engine.gfLow,
            gfHigh: viewModel.engine.gfHigh
        )
        session.cnsPercent = viewModel.cnsPercent
        session.otuTotal = viewModel.otuTotal
        session.tissueLoadingAtEnd = viewModel.tissueLoadingPercent

        modelContext.insert(session)
        saved = true
    }
}

#Preview {
    PostDiveView(viewModel: DiveViewModel(gasMix: .air)) {}
}
