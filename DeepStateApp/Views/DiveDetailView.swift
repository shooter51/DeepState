import SwiftUI
import SwiftData
import Charts
import DiveCore

struct DiveDetailView: View {
    let session: DiveSession

    private var sortedSamples: [DepthSample] {
        (session.depthSamples ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    private var startTime: Date {
        sortedSamples.first?.timestamp ?? session.startDate
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard
                depthProfileChart
                if hasTemperatureData {
                    temperatureChart
                }
                tissueLoadingSection
                phaseTimelineSection
            }
            .padding()
        }
        .navigationTitle(session.startDate.formatted(.dateTime.month(.abbreviated).day().year()))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryItem(title: "Max Depth", value: String(format: "%.1fm", session.maxDepth), icon: "arrow.down.to.line")
                summaryItem(title: "Duration", value: formatDuration(session.duration), icon: "clock")
                summaryItem(title: "Avg Depth", value: String(format: "%.1fm", session.avgDepth), icon: "minus.circle")
                summaryItem(title: "Min Temp", value: session.minTemp.map { String(format: "%.1f\u{00B0}C", $0) } ?? "--", icon: "thermometer.low")
            }

            Divider()

            HStack(spacing: 20) {
                detailChip(label: "Gas", value: gasName(o2Percent: session.o2Percent))
                detailChip(label: "GF", value: "\(Int(session.gfLow * 100))/\(Int(session.gfHigh * 100))")
                detailChip(label: "CNS", value: String(format: "%.0f%%", session.cnsPercent))
                detailChip(label: "OTU", value: String(format: "%.0f", session.otuTotal))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summaryItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailChip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Depth Profile Chart

    private var depthProfileChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Depth Profile")
                .font(.headline)

            if sortedSamples.isEmpty {
                Text("No depth samples available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(sortedSamples, id: \.timestamp) { sample in
                        let elapsed = sample.timestamp.timeIntervalSince(startTime) / 60.0

                        LineMark(
                            x: .value("Time (min)", elapsed),
                            y: .value("Depth (m)", sample.depth)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time (min)", elapsed),
                            y: .value("Depth (m)", sample.depth)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.4), .blue.opacity(0.05)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Safety stop zone
                    if session.maxDepth > 10 {
                        RuleMark(y: .value("Safety Stop", 5.0))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(.green.opacity(0.6))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("5m Safety Stop")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                    }

                    // Max depth annotation
                    if let maxSample = sortedSamples.max(by: { $0.depth < $1.depth }) {
                        let maxElapsed = maxSample.timestamp.timeIntervalSince(startTime) / 60.0
                        PointMark(
                            x: .value("Time (min)", maxElapsed),
                            y: .value("Depth (m)", maxSample.depth)
                        )
                        .foregroundStyle(.red)
                        .symbolSize(60)
                        .annotation(position: .bottom) {
                            Text(String(format: "%.1fm", maxSample.depth))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true, reversed: true))
                .chartXAxisLabel("Time (min)")
                .chartYAxisLabel("Depth (m)")
                .frame(height: 250)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Temperature Chart

    private var hasTemperatureData: Bool {
        sortedSamples.contains { $0.temperature != nil }
    }

    private var temperatureChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperature")
                .font(.headline)

            Chart {
                ForEach(sortedSamples.filter { $0.temperature != nil }, id: \.timestamp) { sample in
                    let elapsed = sample.timestamp.timeIntervalSince(startTime) / 60.0
                    LineMark(
                        x: .value("Time (min)", elapsed),
                        y: .value("Temp (\u{00B0}C)", sample.temperature ?? 0)
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time (min)", elapsed),
                        y: .value("Temp (\u{00B0}C)", sample.temperature ?? 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .red.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxisLabel("Time (min)")
            .chartYAxisLabel("Temp (\u{00B0}C)")
            .frame(height: 180)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Tissue Loading

    private var tissueLoadingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tissue Loading")
                .font(.headline)

            if session.tissueLoadingAtEnd.isEmpty {
                Text("No tissue data available.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(session.tissueLoadingAtEnd.enumerated()), id: \.offset) { index, loading in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption2)
                                .frame(width: 20, alignment: .trailing)
                                .foregroundStyle(.secondary)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(.gray.opacity(0.2))

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(tissueColor(loading: loading))
                                        .frame(width: max(0, geo.size.width * min(loading / 100.0, 1.0)))
                                }
                            }
                            .frame(height: 14)

                            Text(String(format: "%.0f%%", loading))
                                .font(.caption2)
                                .frame(width: 36, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tissueColor(loading: Double) -> Color {
        if loading < 50 {
            return .green
        } else if loading < 80 {
            return .yellow
        } else {
            return .red
        }
    }

    // MARK: - Phase Timeline

    private var phaseTimelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase Timeline")
                .font(.headline)

            if session.phaseHistory.isEmpty {
                Text("No phase data available.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(session.phaseHistory.enumerated()), id: \.offset) { index, phase in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(phaseColor(phase))
                                .frame(width: 8, height: 8)

                            Text(phaseDisplayName(phase))
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func phaseColor(_ phase: String) -> Color {
        switch phase.lowercased() {
        case "surface": return .gray
        case "predive": return .yellow
        case "descending": return .blue
        case "atdepth": return .cyan
        case "ascending": return .green
        case "safetystop": return .orange
        case "surfaceinterval": return .gray
        default: return .secondary
        }
    }

    private func phaseDisplayName(_ phase: String) -> String {
        switch phase.lowercased() {
        case "surface": return "Surface"
        case "predive": return "Pre-Dive"
        case "descending": return "Descending"
        case "atdepth": return "At Depth"
        case "ascending": return "Ascending"
        case "safetystop": return "Safety Stop"
        case "surfaceinterval": return "Surface Interval"
        default: return phase
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func gasName(o2Percent: Int) -> String {
        switch o2Percent {
        case 21: return "Air"
        case 32: return "EAN32"
        case 36: return "EAN36"
        default: return "EAN\(o2Percent)"
        }
    }
}
