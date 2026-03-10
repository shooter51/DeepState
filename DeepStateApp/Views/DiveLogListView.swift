import SwiftUI
import SwiftData
import DiveCore

struct DiveLogListView: View {
    @Query(sort: \DiveSession.startDate, order: .reverse)
    private var diveSessions: [DiveSession]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if diveSessions.isEmpty {
                    emptyState
                } else {
                    diveList
                }
            }
            .navigationTitle("Dive Log")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Dives Recorded Yet", systemImage: "figure.water.fitness")
        } description: {
            Text("Dive sessions synced from your watch will appear here.")
        }
    }

    // MARK: - Dive List

    private var diveList: some View {
        List {
            ForEach(Array(diveSessions.enumerated()), id: \.element.id) { index, session in
                NavigationLink(destination: DiveDetailView(session: session)) {
                    diveRow(session: session, number: diveSessions.count - index)
                }
            }
            .onDelete(perform: deleteDives)
        }
    }

    private func diveRow(session: DiveSession, number: Int) -> some View {
        HStack(spacing: 12) {
            Text("#\(number)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.startDate, format: .dateTime.month(.abbreviated).day().year())
                    .font(.headline)

                HStack(spacing: 16) {
                    Label(formatDepth(session.maxDepth), systemImage: "arrow.down.to.line")
                    Label(formatDuration(session.duration), systemImage: "clock")
                    Text(gasName(o2Percent: session.o2Percent))
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .clipShape(Capsule())
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func deleteDives(at offsets: IndexSet) {
        let sessionsToDelete = offsets.map { diveSessions[$0] }
        for session in sessionsToDelete {
            modelContext.delete(session)
        }
    }

    // MARK: - Formatting

    private func formatDepth(_ depth: Double) -> String {
        String(format: "%.1fm", depth)
    }

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

#Preview {
    DiveLogListView()
        .modelContainer(for: [DiveSession.self, DepthSample.self, DiveSettings.self])
}
