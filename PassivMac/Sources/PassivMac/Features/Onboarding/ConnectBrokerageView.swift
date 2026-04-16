import SwiftUI
import SwiftData

struct ConnectBrokerageView: View {
    var onConnected: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var clientId = ""
    @State private var isConnecting = false
    @State private var error: String?
    @State private var showImport = false
    @State private var newConnectionId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        VStack(alignment: .leading) {
                            Text("Questrade").font(.headline)
                            Text("Full read + trade access").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Supported").font(.caption).foregroundStyle(.green)
                    }
                } header: {
                    Text("Available Brokerages")
                }

                Section {
                    TextField("Client ID", text: $clientId)
                        .textContentType(.none)
                    Text("Register a personal app at questrade.com/api/home to get your Client ID. Use redirect URI: passivapp://oauth/questrade")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Questrade API Credentials")
                } footer: {
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "building.columns")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)
                        VStack(alignment: .leading) {
                            Text("Interactive Brokers").font(.headline)
                            Text("Coming in Phase 3").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Soon").font(.caption).foregroundStyle(.orange)
                    }
                    .opacity(0.5)
                }
            }
            .navigationTitle("Connect Brokerage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        Task { await connectQuestrade() }
                    }
                    .disabled(clientId.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                }
            }
            .overlay {
                if isConnecting {
                    ProgressView("Connecting…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .sheet(isPresented: $showImport) {
            if let id = newConnectionId {
                AccountImportReviewView(connectionId: id) {
                    dismiss()
                    onConnected?()
                }
            }
        }
    }

    private func connectQuestrade() async {
        isConnecting = true
        error = nil
        let id = UUID()

        do {
            let coordinator = await QuestradeOAuthCoordinator()
            let code = try await coordinator.authorize(clientId: clientId.trimmingCharacters(in: .whitespaces))

            let http = HTTPClient()
            let tokenResponse = try await coordinator.exchangeCode(code, httpClient: http)

            try await KeychainService.shared.store(tokenResponse.accessToken, for: .accessToken(connectionId: id))
            try await KeychainService.shared.store(tokenResponse.refreshToken, for: .refreshToken(connectionId: id))

            let connection = BrokerageConnection(brokerageType: .questrade, displayName: "Questrade")
            connection.id = id
            connection.apiServer = tokenResponse.apiServer
            connection.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

            // Cache the apiServer for QuestradeProvider
            UserDefaults.standard.set(tokenResponse.apiServer, forKey: "qs_apiServer_\(id.uuidString)")

            context.insert(connection)
            try context.save()

            newConnectionId = id
            showImport = true
        } catch {
            self.error = error.localizedDescription
        }
        isConnecting = false
    }
}
