import SwiftUI
import DiveCore

struct SessionRecoveryView: View {

    var onResume: () -> Void
    var onEnd: () -> Void

    @State private var lastDepth: Double = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var tissueLoadingSummary: String = "N/A"

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)

                Text("Interrupted Dive Detected")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)

                VStack(spacing: 6) {
                    stateRow(label: "Last Depth", value: String(format: "%.1f m", lastDepth))
                    stateRow(label: "Elapsed", value: formattedElapsed)
                    stateRow(label: "Tissue Load", value: tissueLoadingSummary)
                }
                .padding(.vertical, 4)

                Button(action: onResume) {
                    Text("Resume Dive")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button(action: onEnd) {
                    Text("End Dive")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.gray, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .background(.black)
        .onAppear { loadPersistedState() }
    }

    private var formattedElapsed: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func stateRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func loadPersistedState() {
        if let state = TissueStatePersistence.loadPersistedState() {
            lastDepth = state.lastDepth
            elapsedTime = state.elapsedTime
            let maxLoading = state.tissueLoadings.max() ?? 0
            tissueLoadingSummary = String(format: "Peak: %.0f%%", maxLoading)
        }
    }
}

#Preview {
    SessionRecoveryView(onResume: {}, onEnd: {})
}
