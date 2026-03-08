import SwiftUI
import DiveCore

struct DetailView: View {

    let viewModel: DiveViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Max Depth
                statRow(label: "MAX DEPTH", value: String(format: "%.1f m", viewModel.maxDepth))

                // Average Depth
                statRow(label: "AVG DEPTH", value: String(format: "%.1f m", viewModel.averageDepth))

                Divider().background(.gray)

                // CNS%
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CNS")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", viewModel.cnsPercent))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(cnsColor)
                    }
                    ProgressView(value: min(viewModel.cnsPercent / 100.0, 1.5), total: 1.5)
                        .tint(cnsColor)
                }

                // ppO2
                HStack {
                    Text("ppO\u{2082}")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", viewModel.ppO2))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(ppO2Color)
                }

                Divider().background(.gray)

                // Gas Mix
                statRow(label: "GAS MIX", value: viewModel.gasDescription)

                // GF
                statRow(label: "GF", value: viewModel.gfDescription)

                Divider().background(.gray)

                // Compass placeholder
                HStack {
                    Text("COMPASS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("---\u{00B0}")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Text("Compass N/A")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 8)
        }
        .background(.black)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var cnsColor: Color {
        if viewModel.cnsPercent > 100 { return .red }
        if viewModel.cnsPercent >= 80 { return .yellow }
        return .green
    }

    private var ppO2Color: Color {
        if viewModel.ppO2 > 1.6 { return .red }
        if viewModel.ppO2 >= 1.4 { return .yellow }
        return .green
    }
}

#Preview {
    DetailView(viewModel: DiveViewModel(gasMix: .ean32))
}
