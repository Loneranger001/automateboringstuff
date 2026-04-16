import SwiftUI
import SwiftData

@main
struct PassivMacApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                WelcomeView()
            }
        }
        .modelContainer(PersistenceController.shared.container)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Sync All Accounts") {
                    NotificationCenter.default.post(name: .syncRequested, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .modelContainer(PersistenceController.shared.container)
        }
    }
}

extension Notification.Name {
    static let syncRequested = Notification.Name("PassivMac.syncRequested")
}

/// Root navigation container shown after onboarding.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedGroupId: UUID?
    @State private var isSyncing = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedGroupId: $selectedGroupId)
        } detail: {
            if let id = selectedGroupId {
                PortfolioGroupDetailView(groupId: id)
            } else {
                DashboardView(selectedGroupId: $selectedGroupId)
            }
        }
        .task {
            await NotificationService.shared.requestPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncRequested)) { _ in
            Task {
                isSyncing = true
                await SyncService.shared.syncAll(context: context)
                isSyncing = false
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isSyncing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Syncing…").font(.caption)
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding()
            }
        }
    }
}
