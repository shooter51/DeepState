import SwiftUI
import DiveCore

struct PreDiveView: View {

    enum GasPreset: String, CaseIterable, Identifiable {
        case air = "Air"
        case ean32 = "EAN32"
        case ean36 = "EAN36"
        case custom = "Custom"
        var id: String { rawValue }
    }

    enum GFPreset: String, CaseIterable, Identifiable {
        case defaultGF = "Default (40/85)"
        case conservative = "Conservative (30/70)"
        case custom = "Custom"
        var id: String { rawValue }
    }

    @State private var gasPreset: GasPreset = .air
    @State private var customO2Percent: Int = 32
    @State private var gfPreset: GFPreset = .defaultGF
    @State private var customGFLow: Int = 40
    @State private var customGFHigh: Int = 85
    @State private var versionStatus: VersionCheckService.Status = .unknown
    @State private var versionCheckCompleted = false

    private let versionService = VersionCheckService()

    var onStartDive: (GasMix, Double, Double) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("DeepState")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)

                Text("Operating depth: 40m / 130ft max")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.gray)

                // Gas Selection
                VStack(alignment: .leading, spacing: 4) {
                    Text("GAS MIX")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Picker("Gas", selection: $gasPreset) {
                        ForEach(GasPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 50)

                    if gasPreset == .custom {
                        Stepper("O\u{2082}: \(customO2Percent)%", value: $customO2Percent, in: 21...40)
                            .font(.caption)
                    }
                }

                // GF Selection
                VStack(alignment: .leading, spacing: 4) {
                    Text("GRADIENT FACTORS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Picker("GF", selection: $gfPreset) {
                        ForEach(GFPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 50)

                    if gfPreset == .custom {
                        Stepper("Low: \(customGFLow)%", value: $customGFLow, in: 20...50)
                            .font(.caption)
                        Stepper("High: \(customGFHigh)%", value: $customGFHigh, in: 60...95)
                            .font(.caption)
                    }
                }
                .onChange(of: customGFLow) { _, newLow in
                    if customGFHigh < newLow + 10 {
                        customGFHigh = max(customGFHigh, newLow + 10)
                    }
                }
                .onChange(of: customGFHigh) { _, newHigh in
                    if customGFLow > newHigh - 10 {
                        customGFLow = min(customGFLow, newHigh - 10)
                    }
                }

                // Version check unavailable warning
                if versionCheckCompleted, case .checkFailed = versionStatus {
                    Text("Version check unavailable")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.yellow)
                }

                // Version gate warning
                if case .updateRequired(let notice) = versionStatus {
                    VStack(spacing: 4) {
                        Label("UPDATE REQUIRED", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                        if let notice {
                            Text(notice)
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        }
                        Text("Dive mode blocked until update")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Start Button
                Button(action: startDive) {
                    Text("START DIVE")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isDiveBlocked ? .gray : .green, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isDiveBlocked)
                .padding(.top, 8)
            }
            .padding(.horizontal, 8)
        }
        .task {
            versionStatus = await versionService.check()
            versionCheckCompleted = true
        }
    }

    private var isDiveBlocked: Bool {
        if case .updateRequired = versionStatus { return true }
        return false
    }

    private var selectedGasMix: GasMix {
        switch gasPreset {
        case .air: return .air
        case .ean32: return .ean32
        case .ean36: return .ean36
        case .custom: return .nitrox(o2Percent: customO2Percent)
        }
    }

    private var selectedGFLow: Double {
        switch gfPreset {
        case .defaultGF: return 0.40
        case .conservative: return 0.30
        case .custom: return Double(customGFLow) / 100.0
        }
    }

    private var selectedGFHigh: Double {
        switch gfPreset {
        case .defaultGF: return 0.85
        case .conservative: return 0.70
        case .custom: return Double(customGFHigh) / 100.0
        }
    }

    private func startDive() {
        onStartDive(selectedGasMix, selectedGFLow, selectedGFHigh)
    }
}

#Preview {
    PreDiveView { _, _, _ in }
}
