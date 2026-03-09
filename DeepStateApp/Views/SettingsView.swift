import SwiftUI
import SwiftData
import DiveCore

struct SettingsView: View {
    @Query private var allSettings: [DiveSettings]
    @Environment(\.modelContext) private var modelContext

    private var settings: DiveSettings? {
        allSettings.first
    }

    // Version check
    @State private var versionStatus: VersionCheckService.Status = .unknown
    private let versionService = VersionCheckService()

    // Local state mirroring model for responsive UI
    @State private var unitSystem: String = "metric"
    @State private var gasSelection: GasPreset = .air
    @State private var customO2: Int = 21
    @State private var gfLow: Int = 40
    @State private var gfHigh: Int = 85
    @State private var ppO2Max: Double = 1.4
    @State private var ascentRateWarning: Double = 12.0
    @State private var ascentRateCritical: Double = 18.0
    @State private var hasLoadedSettings = false

    enum GasPreset: String, CaseIterable, Identifiable {
        case air = "Air"
        case ean32 = "EAN32"
        case ean36 = "EAN36"
        case custom = "Custom"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                unitsSection
                defaultGasSection
                gradientFactorsSection
                oxygenLimitsSection
                ascentRateSection
                supportSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear(perform: loadOrCreateSettings)
            .task { versionStatus = await versionService.check() }
            .onChange(of: unitSystem) { _, _ in saveSettings() }
            .onChange(of: gasSelection) { _, _ in saveSettings() }
            .onChange(of: customO2) { _, _ in saveSettings() }
            .onChange(of: gfLow) { _, _ in saveSettings() }
            .onChange(of: gfHigh) { _, _ in saveSettings() }
            .onChange(of: ppO2Max) { _, _ in saveSettings() }
            .onChange(of: ascentRateWarning) { _, _ in saveSettings() }
            .onChange(of: ascentRateCritical) { _, _ in saveSettings() }
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        Section("Units") {
            Picker("Unit System", selection: $unitSystem) {
                Text("Metric").tag("metric")
                Text("Imperial").tag("imperial")
            }
        }
    }

    // MARK: - Default Gas

    private var defaultGasSection: some View {
        Section("Default Gas") {
            Picker("Gas Mix", selection: $gasSelection) {
                ForEach(GasPreset.allCases) { gas in
                    Text(gas.rawValue).tag(gas)
                }
            }

            if gasSelection == .custom {
                Stepper("O\u{2082}: \(customO2)%", value: $customO2, in: 21...40, step: 1)
            }
        }
    }

    // MARK: - Gradient Factors

    private var gradientFactorsSection: some View {
        Section("Gradient Factors") {
            Stepper("GF Low: \(gfLow)%", value: $gfLow, in: 10...95, step: 5)
            Stepper("GF High: \(gfHigh)%", value: $gfHigh, in: 50...95, step: 5)

            HStack(spacing: 12) {
                Button("Default (40/85)") {
                    gfLow = 40
                    gfHigh = 85
                }
                .buttonStyle(.bordered)
                .font(.caption)

                Button("Conservative (30/70)") {
                    gfLow = 30
                    gfHigh = 70
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
    }

    // MARK: - Oxygen Limits

    private var oxygenLimitsSection: some View {
        Section("Oxygen Limits") {
            Stepper("ppO\u{2082} Max: \(String(format: "%.1f", ppO2Max)) ata", value: $ppO2Max, in: 1.2...1.6, step: 0.1)
        }
    }

    // MARK: - Ascent Rate

    private var ascentRateSection: some View {
        Section("Ascent Rate Alerts") {
            Stepper("Warning: \(Int(ascentRateWarning)) m/min", value: $ascentRateWarning, in: 6...18, step: 1)
            Stepper("Critical: \(Int(ascentRateCritical)) m/min", value: $ascentRateCritical, in: 12...30, step: 1)
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        Section("Support") {
            NavigationLink("Report an Issue") {
                FeedbackView()
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("App")
                Spacer()
                Text("DeepState")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("App Status")
                Spacer()
                switch versionStatus {
                case .unknown:
                    Text("Checking...")
                        .foregroundStyle(.secondary)
                case .upToDate:
                    Text("Up to Date")
                        .foregroundStyle(.green)
                case .updateRequired:
                    Text("Update Required")
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                case .checkFailed:
                    Text("Check Failed")
                        .foregroundStyle(.orange)
                }
            }

            if case .updateRequired(let notice) = versionStatus {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Safety Update Available", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                    if let notice {
                        Text(notice)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Update DeepState before your next dive. Dive mode is blocked until you update.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("This is a recreational dive computer tool. Not certified for life-safety use.")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Persistence

    private func loadOrCreateSettings() {
        guard !hasLoadedSettings else { return }
        hasLoadedSettings = true

        if let s = settings {
            loadFromModel(s)
        } else {
            let newSettings = DiveSettings()
            modelContext.insert(newSettings)
            loadFromModel(newSettings)
        }
    }

    private func loadFromModel(_ s: DiveSettings) {
        unitSystem = s.unitSystem
        gfLow = Int(s.gfLow * 100)
        gfHigh = Int(s.gfHigh * 100)
        ppO2Max = s.ppO2Max
        ascentRateWarning = s.ascentRateWarning
        ascentRateCritical = s.ascentRateCritical

        switch s.defaultO2Percent {
        case 21:
            gasSelection = .air
            customO2 = 21
        case 32:
            gasSelection = .ean32
            customO2 = 32
        case 36:
            gasSelection = .ean36
            customO2 = 36
        default:
            gasSelection = .custom
            customO2 = s.defaultO2Percent
        }
    }

    private func saveSettings() {
        guard hasLoadedSettings else { return }

        let s: DiveSettings
        if let existing = settings {
            s = existing
        } else {
            s = DiveSettings()
            modelContext.insert(s)
        }

        s.unitSystem = unitSystem
        s.gfLow = Double(gfLow) / 100.0
        s.gfHigh = Double(gfHigh) / 100.0
        s.ppO2Max = ppO2Max
        s.ascentRateWarning = ascentRateWarning
        s.ascentRateCritical = ascentRateCritical

        switch gasSelection {
        case .air: s.defaultO2Percent = 21
        case .ean32: s.defaultO2Percent = 32
        case .ean36: s.defaultO2Percent = 36
        case .custom: s.defaultO2Percent = customO2
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [DiveSettings.self])
}
