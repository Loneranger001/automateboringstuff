import SwiftUI
import SwiftData

struct AccountsView: View {
    @Query private var connections: [BrokerageConnection]
    @Environment(\.modelContext) private var context
    @State private var showConnect = false
    @State private var connectionToDelete: BrokerageConnection?

    var body: some View {
        List {
            ForEach(connections) { connection in
                Section {
                    ForEach(connection.accounts) { account in
                        AccountRowView(account: account)
                    }
                } header: {
                    HStack {
                        Image(systemName: "building.columns.fill")
                        Text(connection.displayName)
                        Spacer()
                        if let synced = connection.lastSyncedAt {
                            Text("Synced " + FormatUtils.relativeDate(synced))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button(role: .destructive) {
                            connectionToDelete = connection
                        } label: {
                            Image(systemName: "trash").font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showConnect = true
                } label: {
                    Label("Connect Brokerage", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showConnect) {
            ConnectBrokerageView()
        }
        .confirmationDialog(
            "Disconnect \(connectionToDelete?.displayName ?? "")?",
            isPresented: Binding(
                get: { connectionToDelete != nil },
                set: { if !$0 { connectionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                if let c = connectionToDelete {
                    deleteConnection(c)
                }
            }
        } message: {
            Text("Your Questrade API access will be revoked and all synced data will be removed from this app.")
        }
        .overlay {
            if connections.isEmpty {
                ContentUnavailableView(
                    "No Accounts",
                    systemImage: "building.columns",
                    description: Text("Connect a brokerage account to get started.")
                )
            }
        }
    }

    private func deleteConnection(_ connection: BrokerageConnection) {
        KeychainService.shared.deleteAll(for: connection.id)
        context.delete(connection)
        try? context.save()
        connectionToDelete = nil
    }
}

struct AccountRowView: View {
    @Bindable var account: Account

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Account Name", text: $account.displayName)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(account.brokerageAccountId)
                    Text("·")
                    Text(account.currency.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Type", selection: $account.accountTypeRaw) {
                ForEach(AccountType.allCases) { type in
                    Text(type.displayName).tag(type.rawValue)
                }
            }
            .frame(width: 160)

            VStack(alignment: .trailing) {
                Text(FormatUtils.currency(account.totalMarketValue, currency: account.currency))
                    .fontWeight(.medium)
                    .monospacedDigit()
                Text("Cash: \(FormatUtils.currency(account.cashBalance, currency: account.currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}
