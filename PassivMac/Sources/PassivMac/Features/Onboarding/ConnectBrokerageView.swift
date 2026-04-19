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

    // Embedded webview OAuth state
    @State private var showWebAuth = false
    @State private var pendingCoordinator: QuestradeOAuthCoordinator?
    @State private var pendingAuthURL: URL?

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
                    Text("Register a personal app at questrade.com/api/home to get your Client ID. Set Callback URL to: https://www.example.com/oauth/questrade")
                        .textSelection(.enabled)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                        beginQuestradeConnect()
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
        .frame(minWidth: 560, idealWidth: 620, minHeight: 480, idealHeight: 540)
        .sheet(isPresented: $showImport) {
            if let id = newConnectionId {
                AccountImportReviewView(connectionId: id) {
                    dismiss()
                    onConnected?()
                }
            }
        }
        .sheet(isPresented: $showWebAuth) {
            if let coordinator = pendingCoordinator, let authURL = pendingAuthURL {
                QuestradeWebAuthSheet(
                    authURL: authURL,
                    redirectPrefix: QuestradeOAuthCoordinator.redirectURI,
                    expectedState: coordinator.state,
                    onCancel: {
                        showWebAuth = false
                        pendingCoordinator = nil
                        pendingAuthURL = nil
                    },
                    onCode: { code in
                        showWebAuth = false
                        Task { await completeQuestrade(code: code, coordinator: coordinator) }
                    },
                    onError: { err in
                        showWebAuth = false
                        self.error = err.localizedDescription
                        pendingCoordinator = nil
                        pendingAuthURL = nil
                    }
                )
            }
        }
    }

    /// Step 1: build the auth URL and present it in an embedded webview.
    private func beginQuestradeConnect() {
        error = nil
        let coordinator = QuestradeOAuthCoordinator()
        do {
            let url = try coordinator.authorizeURL(clientId: clientId.trimmingCharacters(in: .whitespaces))
            pendingCoordinator = coordinator
            pendingAuthURL = url
            showWebAuth = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Step 2: webview intercepted the redirect and handed us the code.
    private func completeQuestrade(code: String, coordinator: QuestradeOAuthCoordinator) async {
        isConnecting = true
        error = nil
        let id = UUID()
        defer {
            isConnecting = false
            pendingCoordinator = nil
            pendingAuthURL = nil
        }

        do {
            let http = HTTPClient()
            let tokenResponse = try await coordinator.exchangeCode(code, httpClient: http)

            try await KeychainService.shared.store(tokenResponse.accessToken, for: .accessToken(connectionId: id))
            try await KeychainService.shared.store(tokenResponse.refreshToken, for: .refreshToken(connectionId: id))

            let connection = BrokerageConnection(brokerageType: .questrade, displayName: "Questrade")
            connection.id = id
            connection.apiServer = tokenResponse.apiServer
            connection.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

            UserDefaults.standard.set(tokenResponse.apiServer, forKey: "qs_apiServer_\(id.uuidString)")

            context.insert(connection)
            try context.save()

            newConnectionId = id
            showImport = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Web auth sheet

private struct QuestradeWebAuthSheet: View {
    let authURL: URL
    let redirectPrefix: String
    let expectedState: String
    var onCancel: () -> Void
    var onCode: (String) -> Void
    var onError: (Error) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sign in to Questrade")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            QuestradeWebAuthView(
                authURL: authURL,
                redirectPrefix: redirectPrefix,
                expectedState: expectedState
            ) { result in
                switch result {
                case .success(let code): onCode(code)
                case .failure(let err):  onError(err)
                }
            }
        }
        .frame(minWidth: 720, idealWidth: 820, minHeight: 640, idealHeight: 720)
    }
}
