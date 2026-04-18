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

    // Manual paste OAuth state
    @State private var showPasteSheet = false
    @State private var pastedURL = ""
    @State private var expectedState: String?
    @State private var coordinator: QuestradeOAuthCoordinator?

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
                    Text("Register a personal app at questrade.com/api/home to get your Client ID. Set Callback URL to: https://localhost/oauth/questrade")
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
        .sheet(isPresented: $showPasteSheet) {
            PasteRedirectURLSheet(
                pastedURL: $pastedURL,
                onCancel: {
                    showPasteSheet = false
                    coordinator = nil
                    expectedState = nil
                },
                onSubmit: {
                    Task { await completeQuestradeWithPastedURL() }
                }
            )
        }
    }

    /// Step 1: open Questrade auth page in the browser, then show the paste sheet.
    private func beginQuestradeConnect() {
        error = nil
        let c = QuestradeOAuthCoordinator()
        do {
            let state = try c.beginAuthorization(clientId: clientId.trimmingCharacters(in: .whitespaces))
            coordinator = c
            expectedState = state
            pastedURL = ""
            showPasteSheet = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Step 2: user pasted the redirected URL. Extract the code and finish the flow.
    private func completeQuestradeWithPastedURL() async {
        guard let coordinator, let expectedState else { return }
        isConnecting = true
        showPasteSheet = false
        error = nil
        let id = UUID()

        do {
            let code = try coordinator.extractCode(
                fromPastedURL: pastedURL,
                expectedState: expectedState
            )
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
            // Re-open paste sheet so user can correct the URL without restarting the whole flow.
            showPasteSheet = true
        }
        isConnecting = false
        self.coordinator = nil
        self.expectedState = nil
    }
}

// MARK: - Paste Redirect URL Sheet

private struct PasteRedirectURLSheet: View {
    @Binding var pastedURL: String
    var onCancel: () -> Void
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paste the redirect URL")
                .font(.title3.bold())

            Text("""
            1. Sign in at the Questrade page that opened in your browser and approve the app.
            2. Your browser will show a blank page or "Can't reach this site" at `localhost` — that's expected.
            3. Copy the **entire URL** from the browser's address bar (it starts with `https://localhost/oauth/questrade?code=…`) and paste it below.
            """)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $pastedURL)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Continue", action: onSubmit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(pastedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 520, idealWidth: 580, minHeight: 320)
    }
}
