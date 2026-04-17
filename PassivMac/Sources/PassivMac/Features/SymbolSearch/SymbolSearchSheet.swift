import SwiftUI
import SwiftData

struct SymbolSearchSheet: View {
    let group: PortfolioGroup
    var onAdded: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [SymbolSearchResult] = []
    @State private var isSearching = false
    @State private var error: String?

    private var questrade: QuestradeProvider { QuestradeProvider() }

    private var connection: BrokerageConnection? {
        group.accounts.first?.connection
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search symbol (e.g. VFV, XAW)", text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await search() } }
                    if isSearching { ProgressView().controlSize(.small) }
                }
                .padding(10)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                .padding()

                Divider()

                if let error {
                    ContentUnavailableView("Search Failed", systemImage: "exclamationmark.triangle",
                                          description: Text(error))
                } else if results.isEmpty && !query.isEmpty && !isSearching {
                    ContentUnavailableView("No Results", systemImage: "magnifyingglass",
                                          description: Text("No securities found for \"\(query)\"."))
                } else {
                    List(results) { result in
                        Button { addAllocation(result) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(result.symbol).fontWeight(.semibold)
                                    Text(result.name).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(result.exchange).font(.caption).foregroundStyle(.secondary)
                                    Text(result.currency.rawValue).font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Security")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 360)
        .onChange(of: query) { _, new in
            guard new.count >= 2 else { results = []; return }
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)  // 350ms debounce
                await search()
            }
        }
    }

    private func search() async {
        guard !query.isEmpty, let connection else { return }
        isSearching = true
        error = nil
        do {
            results = try await questrade.searchSymbols(query: query, connectionId: connection.id)
        } catch {
            self.error = error.localizedDescription
        }
        isSearching = false
    }

    private func addAllocation(_ result: SymbolSearchResult) {
        // Don't add duplicates
        guard !group.targetAllocations.contains(where: { $0.symbol == result.symbol }) else {
            dismiss()
            return
        }

        let security = upsertSecurity(result)
        let allocation = TargetAllocation(
            portfolioGroup: group,
            security: security,
            symbol: result.symbol,
            targetPercent: 0
        )
        context.insert(allocation)
        group.targetAllocations.append(allocation)
        try? context.save()
        onAdded()
        dismiss()
    }

    private func upsertSecurity(_ result: SymbolSearchResult) -> Security {
        let symbol = result.symbol
        let existing = try? context.fetch(
            FetchDescriptor<Security>(predicate: #Predicate { $0.symbol == symbol })
        ).first
        if let existing { return existing }

        let security = Security(
            symbol: result.symbol,
            name: result.name,
            exchange: result.exchange,
            currency: result.currency,
            assetType: result.assetType
        )
        context.insert(security)
        return security
    }
}
