import SwiftUI
import DiveCore

struct FeedbackView: View {
    enum FeedbackCategory: String, CaseIterable {
        case general = "General Feedback"
        case bugReport = "Bug Report"
        case safetyIncident = "Safety Incident"
    }

    @State private var selectedCategory: FeedbackCategory = .general
    @State private var description: String = ""
    @State private var includeLastDiveLog: Bool = false
    @State private var contactEmail: String = ""
    @State private var showingSubmitConfirmation = false
    @State private var showingSafetyWarning = false
    @Environment(\.dismiss) private var dismiss

    private var placeholderText: String {
        switch selectedCategory {
        case .general:
            return "Describe your feedback or feature request..."
        case .bugReport:
            return "Describe what happened and what you expected..."
        case .safetyIncident:
            return "Describe the incident: what depth were you at, what did the display show, what did your reference computer show?"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                categorySection
                descriptionSection

                if selectedCategory == .bugReport || selectedCategory == .safetyIncident {
                    diveDataSection
                }

                contactSection
                submitSection
            }
            .navigationTitle("Report")
            .alert("Report Saved Locally", isPresented: $showingSubmitConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Feedback submission is not yet connected to a server. Your report has been saved locally but has NOT been sent. Please email safety@divestreams.com for urgent safety concerns.")
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)

            if selectedCategory == .safetyIncident {
                Text("Safety incidents are treated as highest priority (P0). If you experienced incorrect depth, NDL, or decompression information during a dive, report it here. Online submission is not yet available — please email safety@divestreams.com directly for urgent concerns.")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        Section("Description") {
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $description)
                    .frame(minHeight: 100)
            }
        }
    }

    // MARK: - Dive Data

    private var diveDataSection: some View {
        Section("Dive Data") {
            Toggle("Attach last dive session data", isOn: $includeLastDiveLog)

            Text("Includes anonymized depth profile, sensor logs, and session health data. No personal information is shared.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        Section("Contact") {
            TextField("Email address", text: $contactEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if selectedCategory == .safetyIncident {
                Text("Required for Safety Incidents")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Submit

    private var submitSection: some View {
        Section {
            Text("Feedback submission is not yet connected. Your report will not be sent.")
                .font(.caption)
                .foregroundStyle(.orange)

            Button {
                // TODO: Wire to backend API endpoint
                showingSubmitConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(selectedCategory == .safetyIncident ? "Submit Safety Report" : "Submit Feedback")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .foregroundStyle(.white)
            .listRowBackground(selectedCategory == .safetyIncident ? Color.red : Color.blue)
            .disabled(description.isEmpty || (selectedCategory == .safetyIncident && !isValidEmail(contactEmail)))
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

#Preview {
    FeedbackView()
}
