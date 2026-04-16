import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("syncFrequencyMinutes") private var syncFrequencyMinutes = 60
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var selectedTab = "General"

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }.tag("General")
            notificationsTab.tabItem { Label("Notifications", systemImage: "bell") }.tag("Notifications")
            accountsTab.tabItem { Label("Accounts", systemImage: "building.columns") }.tag("Accounts")
            aboutTab.tabItem { Label("About", systemImage: "info.circle") }.tag("About")
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section("Sync") {
                Picker("Auto-sync frequency", selection: $syncFrequencyMinutes) {
                    Text("Every 30 min").tag(30)
                    Text("Every hour").tag(60)
                    Text("Every 4 hours").tag(240)
                    Text("Manual only").tag(0)
                }
            }

            Section("Onboarding") {
                Button("Reset Onboarding") {
                    hasCompletedOnboarding = false
                }
                .foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var notificationsTab: some View {
        Form {
            Section("Drift Alerts") {
                Toggle("Notify when portfolio drifts from targets", isOn: .constant(true))
                    .disabled(false)
                HStack {
                    Text("Alert threshold")
                    Spacer()
                    Text("5%").foregroundStyle(.secondary)
                }
            }

            Section("Cash Alerts") {
                Toggle("Notify when cash is available to invest", isOn: .constant(true))
                HStack {
                    Text("Minimum cash amount")
                    Spacer()
                    Text("$500").foregroundStyle(.secondary)
                }
            }

            Section("Orders") {
                Toggle("Notify when orders are filled", isOn: .constant(true))
            }

            Section {
                Text("Notification thresholds are configured per-portfolio-group in the group settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var accountsTab: some View {
        AccountsView()
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("PassivMac").font(.title.bold())
            Text("Version 1.0.0 (Phase 1)")
                .foregroundStyle(.secondary)
            Text("A personal Mac portfolio rebalancing app.\nBuilt with SwiftUI + SwiftData.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Divider()
            Text("Data source: Questrade REST API\nFX rates: Bank of Canada Valet API")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
