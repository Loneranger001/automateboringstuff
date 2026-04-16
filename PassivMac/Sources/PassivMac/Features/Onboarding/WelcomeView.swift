import SwiftUI

struct WelcomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showConnect = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "chart.pie.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Welcome to PassivMac")
                    .font(.largeTitle.bold())
                Text("Passive portfolio management for self-directed investors.\nConnect your Questrade account to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                featureRow("Connect your brokerage account", icon: "link")
                featureRow("Set target allocations for your ETFs", icon: "target")
                featureRow("One-click rebalancing trades", icon: "arrow.2.circlepath")
                featureRow("Track performance over time", icon: "chart.xyaxis.line")
            }
            .padding(.horizontal, 40)

            Spacer()

            Button("Connect Brokerage Account") {
                showConnect = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip for now") {
                hasCompletedOnboarding = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(40)
        .frame(minWidth: 520, minHeight: 560)
        .sheet(isPresented: $showConnect) {
            ConnectBrokerageView {
                hasCompletedOnboarding = true
            }
        }
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
