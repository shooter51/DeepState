import SwiftUI

struct OnboardingView: View {

    @State private var hasAccepted = false
    var onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Welcome to DeepState")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Text("DeepState is designed for use with Apple Watch Ultra within its rated depth of 40 meters / 130 feet.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    safetyPoint("Always dive with a certified primary dive computer")
                    safetyPoint("DeepState operates within the 40m Apple Watch Ultra depth rating")
                    safetyPoint("This app is not a substitute for proper dive training")
                }
                .padding(.vertical, 4)

                Toggle(isOn: $hasAccepted) {
                    Text("I understand and accept these conditions")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)
                .padding(.vertical, 4)

                Button(action: {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    onComplete()
                }) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(hasAccepted ? .green : .gray, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!hasAccepted)
            }
            .padding(.horizontal, 8)
        }
        .background(.black)
    }

    private func safetyPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

#Preview {
    OnboardingView {}
}
