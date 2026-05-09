//
//  AddOnsSettingsView.swift
//  Notchly
//
//  Dedicated settings pane for the Notchly Add-On layer. Hooks into
//  existing `Defaults` keys defined in `AddOnsDefaults.swift` and
//  persists MODIH credentials via the Keychain.
//

import Defaults
import SwiftUI

struct AddOnsSettingsView: View {
    @Default(.addOnsEnabled) private var addOnsEnabled
    @Default(.modihMailEnabled) private var modihMailEnabled
    @Default(.modihMailBaseURL) private var modihMailBaseURL
    @Default(.modihMailPreferAPI) private var modihMailPreferAPI
    @Default(.webNotificationsEnabled) private var webNotificationsEnabled
    @Default(.webNotificationsRefreshInterval) private var webNotificationsRefreshInterval
    @Default(.webNotificationsLiveSyncEnabled) private var webNotificationsLiveSyncEnabled
    @Default(.webNotificationsRestoreSignedInApps) private var webNotificationsRestoreSignedInApps
    @Default(.webNotificationsBackgroundPollingEnabled) private var webNotificationsBackgroundPollingEnabled
    @Default(.webNotificationsEnabledApps) private var webNotificationsEnabledApps

    @ObservedObject private var webState: WebNotificationState = .shared

    // Keychain-backed fields rendered as transient @State so empty
    // fields read clearly as "not set".
    @State private var apiKeyField: String = ""
    @State private var apiKeyConnected: Bool = false
    @State private var savedConfirmation: String?

    private let keychain = KeychainStore()

    var body: some View {
        Form {
            Section {
                Toggle("Enable Add-ons", isOn: $addOnsEnabled)
                    .tint(.accentColor)
            } header: {
                Text("General")
            } footer: {
                Text("Shows the two circular indicators flanking the collapsed notch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            modihSection
            webNotificationsSection
        }
        .formStyle(.grouped)
        .onAppear { loadKeychain() }
    }

    // MARK: - MODIH Section

    private var modihSection: some View {
        Section {
            Toggle("Enable TEMP Mail", isOn: $modihMailEnabled)
                .tint(.accentColor)

            TextField("API Base URL", text: $modihMailBaseURL)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .autocorrectionDisabled(true)

            Toggle("Prefer API over WebView", isOn: $modihMailPreferAPI)
                .tint(.accentColor)

            HStack {
                SecureField("API Key (optional)", text: $apiKeyField)
                    .textFieldStyle(.roundedBorder)
                Button("Save") { saveAPIKey() }
                    .disabled(apiKeyField.isEmpty)
                Button("Reset") { resetAPIKey() }
                    .disabled(!apiKeyConnected && apiKeyField.isEmpty)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(apiKeyConnected ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(apiKeyConnected ? "API key stored in Keychain" : "No API key stored")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let savedConfirmation {
                    Spacer()
                    Text(savedConfirmation)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("TEMP Mail")
        } footer: {
            Text("Free-tier inboxes work without an API key. Paid plans store credentials securely in the macOS Keychain. Powered by modih.in.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Web Notifications Section

    private var webNotificationsSection: some View {
        Section {
            Toggle("Enable Web Notifications", isOn: $webNotificationsEnabled)
                .tint(.accentColor)

            Toggle("Live sync opened apps", isOn: $webNotificationsLiveSyncEnabled)
                .tint(.accentColor)

            Toggle("Restore signed-in apps on launch", isOn: $webNotificationsRestoreSignedInApps)
                .tint(.accentColor)
                .disabled(!webNotificationsLiveSyncEnabled)

            Toggle("Background polling for all apps", isOn: $webNotificationsBackgroundPollingEnabled)
                .tint(.accentColor)

            HStack {
                Text("Background refresh interval")
                Spacer()
                Picker(
                    "",
                    selection: Binding(
                        get: { webNotificationsRefreshInterval },
                        set: { webNotificationsRefreshInterval = $0 }
                    )
                ) {
                    Text("1m").tag(Double(60))
                    Text("2m").tag(Double(120))
                    Text("3m").tag(Double(180))
                    Text("5m").tag(Double(300))
                }
                .labelsHidden()
                .frame(width: 100)
            }
            .disabled(!webNotificationsBackgroundPollingEnabled)

            ForEach(WebNotificationAppID.allCases.filter(\.isVisibleInCurrentBuild)) { app in
                appToggleRow(app)
            }
        } header: {
            Text("Web Notifications")
        } footer: {
            Text("Live sync keeps known signed-in apps warm for faster notification previews. Background polling checks every enabled app, but costs more battery. Messages / iMessage is intentionally excluded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func appToggleRow(_ app: WebNotificationAppID) -> some View {
        HStack {
            WebNotificationBrandIcon(app: app, size: 18)
                .frame(width: 18, height: 18)
            Text(app.displayName)

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { webNotificationsEnabledApps[app.rawValue] ?? app.defaultEnabled },
                    set: { newValue in
                        webNotificationsEnabledApps[app.rawValue] = newValue
                        webState.reloadFromDefaults()
                    }
                )
            )
            .labelsHidden()
            .tint(.accentColor)
        }
    }

    // MARK: - Keychain Helpers

    private func loadKeychain() {
        if let stored = keychain.string(for: KeychainAccounts.modihAPIKey), !stored.isEmpty {
            apiKeyField = "modih-••••••••••••••••"
            apiKeyConnected = true
        } else {
            apiKeyField = ""
            apiKeyConnected = false
        }
    }

    private func saveAPIKey() {
        guard !apiKeyField.isEmpty, !apiKeyField.contains("•") else { return }
        let trimmed = apiKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
        if keychain.setString(trimmed, for: KeychainAccounts.modihAPIKey) {
            savedConfirmation = "Saved"
            apiKeyConnected = true
            apiKeyField = "modih-••••••••••••••••"
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { self.savedConfirmation = nil }
            }
        } else {
            savedConfirmation = "Save failed"
        }
    }

    private func resetAPIKey() {
        keychain.remove(for: KeychainAccounts.modihAPIKey)
        apiKeyField = ""
        apiKeyConnected = false
        savedConfirmation = "Removed"
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { self.savedConfirmation = nil }
        }
    }
}
