import SwiftUI
import SwiftData

struct SidebarView: View {
    @Query(sort: \PortfolioGroup.createdAt) private var groups: [PortfolioGroup]
    @Query private var connections: [BrokerageConnection]
    @Binding var selectedGroupId: UUID?
    @State private var showAddGroup = false

    var body: some View {
        List(selection: $selectedGroupId) {
            Section("Portfolio Groups") {
                ForEach(groups) { group in
                    Label(group.name, systemImage: "chart.pie")
                        .tag(group.id)
                }
                Button {
                    showAddGroup = true
                } label: {
                    Label("New Group", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Section("Accounts") {
                NavigationLink {
                    AccountsView()
                } label: {
                    Label("Accounts", systemImage: "building.columns")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PassivMac")
        .toolbar {
            ToolbarItem {
                Button {
                    NotificationCenter.default.post(name: .syncRequested, object: nil)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Sync All Accounts")
            }
        }
        .sheet(isPresented: $showAddGroup) {
            CreateGroupView()
        }
    }
}

struct DashboardView: View {
    @Query(sort: \PortfolioGroup.createdAt) private var groups: [PortfolioGroup]
    @Binding var selectedGroupId: UUID?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320))], spacing: 16) {
                ForEach(groups) { group in
                    PortfolioGroupCardView(group: group)
                        .onTapGesture { selectedGroupId = group.id }
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No Portfolio Groups",
                    systemImage: "chart.pie",
                    description: Text("Connect a brokerage account to get started.")
                )
            }
        }
    }
}
