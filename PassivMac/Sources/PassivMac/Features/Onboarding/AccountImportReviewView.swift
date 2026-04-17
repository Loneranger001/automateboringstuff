import SwiftUI
import SwiftData

/// Shown after OAuth completes — lets the user review imported accounts,
/// rename them, assign account types, and put them into a portfolio group.
struct AccountImportReviewView: View {
    let connectionId: UUID
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var isLoading = true
    @State private var error: String?
    @State private var groupName = "My Portfolio"
    @State private var accounts: [Account] = []

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    Section { ProgressView("Importing accounts…") }
                } else if let error {
                    Section { Text(error).foregroundStyle(.red) }
                } else {
                    Section("Portfolio Group") {
                        TextField("Group Name", text: $groupName)
                    }

                    Section("Imported Accounts") {
                        ForEach(accounts) { account in
                            AccountImportRowView(account: account)
                        }
                    }
                }
            }
            .navigationTitle("Review Accounts")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { createGroupAndFinish() }
                        .disabled(isLoading || groupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .task { await loadAccounts() }
    }

    private func loadAccounts() async {
        let descriptor = FetchDescriptor<BrokerageConnection>(
            predicate: #Predicate { $0.id == connectionId }
        )
        guard let connection = try? context.fetch(descriptor).first else {
            error = "Connection not found."
            isLoading = false
            return
        }

        do {
            await SyncService.shared.sync(connection: connection, context: context)
            accounts = connection.accounts
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func createGroupAndFinish() {
        let group = PortfolioGroup(
            name: groupName.trimmingCharacters(in: .whitespaces),
            baseCurrency: .cad
        )
        context.insert(group)
        for account in accounts {
            account.portfolioGroup = group
            group.accounts.append(account)
        }
        try? context.save()
        onDone()
    }
}

private struct AccountImportRowView: View {
    @Bindable var account: Account

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                TextField("Account Name", text: $account.displayName)
                    .font(.body)
                Text(account.brokerageAccountId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $account.accountTypeRaw) {
                ForEach(AccountType.allCases) { type in
                    Text(type.displayName).tag(type.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 160)
        }
    }
}
