import SwiftUI
import DiveCore

struct DivePlannerView: View {
    // MARK: - Input State

    @State private var targetDepth: Int = 18
    @State private var gasSelection: GasSelection = .air
    @State private var customO2: Int = 32
    @State private var gfLow: Double = 0.40
    @State private var gfHigh: Double = 0.85

    enum GasSelection: String, CaseIterable, Identifiable {
        case air = "Air"
        case ean32 = "EAN32"
        case ean36 = "EAN36"
        case custom = "Custom"

        var id: String { rawValue }
    }

    // MARK: - Computed Properties

    private var gasMix: GasMix {
        switch gasSelection {
        case .air: return .air
        case .ean32: return .ean32
        case .ean36: return .ean36
        case .custom: return .nitrox(o2Percent: customO2)
        }
    }

    private var o2Percent: Int {
        switch gasSelection {
        case .air: return 21
        case .ean32: return 32
        case .ean36: return 36
        case .custom: return customO2
        }
    }

    private var depth: Double {
        Double(targetDepth)
    }

    private var ppO2AtDepth: Double {
        let ambientPressure = 1.013 + depth / 10.0
        return ambientPressure * gasMix.o2Fraction
    }

    private var mod: Double {
        // MOD = (ppO2Max / fO2 - 1) * 10
        (1.4 / gasMix.o2Fraction - 1.0) * 10.0
    }

    private var ead: Double? {
        guard gasMix.isNitrox else { return nil }
        // EAD = (depth + 10) * fN2 / 0.79 - 10
        return (depth + 10.0) * gasMix.n2Fraction / 0.79 - 10.0
    }

    private var ndl: Int {
        let engine = BuhlmannEngine(gfLow: gfLow, gfHigh: gfHigh)
        return engine.ndl(depth: depth, gasMix: gasMix)
    }

    private var depthExceedsMOD: Bool {
        depth > mod
    }

    // Simulated profile calculations
    private var descentRate: Double { 18.0 } // m/min
    private var ascentRate: Double { 9.0 }   // m/min

    private var descentTime: Double {
        depth / descentRate
    }

    private var bottomTime: Double {
        Double(ndl)
    }

    private var ascentTime: Double {
        let ascentDepth = depth > 10 ? depth - 5.0 : depth
        return ascentDepth / ascentRate
    }

    private var safetyStopTime: Double {
        depth > 10 ? 3.0 : 0.0
    }

    private var finalAscentTime: Double {
        depth > 10 ? 5.0 / ascentRate : 0.0
    }

    private var totalDiveTime: Double {
        descentTime + bottomTime + ascentTime + safetyStopTime + finalAscentTime
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                inputSection
                if depthExceedsMOD {
                    modWarningSection
                }
                resultsSection
                simulatedProfileSection
            }
            .navigationTitle("Planner")
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        Section("Dive Parameters") {
            Stepper("Target Depth: \(targetDepth)m", value: $targetDepth, in: 5...60, step: 1)

            Picker("Gas Mix", selection: $gasSelection) {
                ForEach(GasSelection.allCases) { gas in
                    Text(gas.rawValue).tag(gas)
                }
            }

            if gasSelection == .custom {
                Stepper("O\u{2082}: \(customO2)%", value: $customO2, in: 21...40, step: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Stepper("GF Low: \(Int(gfLow * 100))%", value: $gfLow, in: 0.10...0.95, step: 0.05)
                Stepper("GF High: \(Int(gfHigh * 100))%", value: $gfHigh, in: 0.10...0.95, step: 0.05)
            }
        }
    }

    // MARK: - MOD Warning

    private var modWarningSection: some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Depth Exceeds MOD")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Target depth \(targetDepth)m exceeds the maximum operating depth of \(String(format: "%.0f", mod))m for this gas mix.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .listRowBackground(Color.red)
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        Section("Calculations") {
            resultRow(label: "NDL", value: ndl >= 999 ? "999+ min" : "\(ndl) min", icon: "timer")

            resultRow(label: "MOD", value: String(format: "%.0fm", mod), icon: "arrow.down.to.line")

            HStack {
                Label("ppO\u{2082}", systemImage: "aqi.medium")
                Spacer()
                Text(String(format: "%.2f ata", ppO2AtDepth))
                    .foregroundStyle(ppO2Color)
                    .fontWeight(.medium)
            }

            if let ead = ead {
                resultRow(label: "EAD", value: String(format: "%.1fm", ead), icon: "equal.circle")
            }
        }
    }

    private var ppO2Color: Color {
        if ppO2AtDepth > 1.6 {
            return .red
        } else if ppO2AtDepth > 1.4 {
            return .orange
        } else {
            return .green
        }
    }

    private func resultRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Simulated Profile Section

    private var simulatedProfileSection: some View {
        Section("Simulated Square Profile") {
            profileRow(label: "Descent", value: String(format: "%.1f min", descentTime), detail: "at \(Int(descentRate))m/min")
            profileRow(label: "Bottom Time", value: "\(Int(bottomTime)) min", detail: "at \(targetDepth)m")
            profileRow(label: "Ascent", value: String(format: "%.1f min", ascentTime), detail: "at \(Int(ascentRate))m/min")

            if safetyStopTime > 0 {
                profileRow(label: "Safety Stop", value: "3 min", detail: "at 5m")
                profileRow(label: "Final Ascent", value: String(format: "%.1f min", finalAscentTime), detail: "5m to surface")
            }

            Divider()

            HStack {
                Text("Total Dive Time")
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "%.0f min", totalDiveTime))
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
        }
    }

    private func profileRow(label: String, value: String, detail: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    DivePlannerView()
}
