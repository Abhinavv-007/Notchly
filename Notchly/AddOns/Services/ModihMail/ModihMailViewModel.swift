//
//  ModihMailViewModel.swift
//  Notchly
//
//  Drives the MODIH Mail inline panel. Owns the active `ModihMailState`
//  and routes user intents (copy, regenerate, open inbox, refresh) to
//  the configured `ModihMailClient`.
//
//  Phase A binds to a `StubModihMailClient` by default, so the panel
//  renders realistic loading/loaded/empty states without talking to the
//  network. Callers can rebuild the view model with a real client once
//  the settings pane wires credentials.
//

import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI

@MainActor
final class ModihMailViewModel: ObservableObject {

    // MARK: Published State

    @Published private(set) var state: ModihMailState = .idle
    @Published private(set) var lastCopiedAt: Date?
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var selectedMessage: ModihMessage?

    // MARK: Dependencies

    private var client: ModihMailClient
    private var refreshTask: Task<Void, Never>?
    private var liveRefreshTask: Task<Void, Never>?
    private var backgroundRefreshTask: Task<Void, Never>?
    private var hasStartedInitialLoad = false
    private var isRefreshing = false
    private let liveRefreshInterval: Duration = .seconds(8)
    private let backgroundRefreshInterval: Duration = .seconds(18)
    private var hasEstablishedPreviewBaseline = false
    private var lastPreviewedMessageID: String?

    // MARK: Init

    init(client: ModihMailClient? = nil) {
        self.client = client ?? URLSessionModihMailClient.liveFromDefaults()
        if let restored = MailboxPersistence.restore() {
            state = .empty(restored)
            hasStartedInitialLoad = true
        }
        startBackgroundRefresh()
    }

    deinit {
        refreshTask?.cancel()
        liveRefreshTask?.cancel()
        backgroundRefreshTask?.cancel()
    }

    // MARK: Client Injection

    /// Swap the HTTP client at runtime. The UI is re-populated afterwards.
    func updateClient(_ newClient: ModihMailClient) {
        self.client = newClient
        self.hasStartedInitialLoad = false
        self.hasEstablishedPreviewBaseline = false
        self.lastPreviewedMessageID = nil
        self.selectedMessage = nil
        self.state = .idle
    }

    // MARK: Public API

    /// Convenience used by `NotchAddonState` when the side indicator is
    /// clicked. Triggers a first load if nothing has been fetched yet.
    func requestLoadIfNeeded() {
        guard Defaults[.modihMailEnabled] else { return }
        if !hasStartedInitialLoad {
            hasStartedInitialLoad = true
            refresh()
        } else {
            refresh(showLoading: state.mailbox == nil || state.errorText != nil)
        }
    }

    /// Force a refresh of mailbox metadata and inbox preview.
    func refresh(showLoading: Bool = true) {
        guard Defaults[.modihMailEnabled] else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        if showLoading || state.mailbox == nil {
            state = .loading
        }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isRefreshing = false
                self.refreshTask = nil
            }
            await self.loadInternal()
        }
    }

    func regenerate() {
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
        isBusy = true
        state = .loading

        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer { Task { @MainActor in self.isBusy = false } }

            do {
                _ = try await self.client.regenerateMailbox()
                await self.loadInternal()
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    func startLiveRefresh() {
        requestLoadIfNeeded()
        guard liveRefreshTask == nil else { return }

        liveRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: self.liveRefreshInterval)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard Defaults[.modihMailEnabled], !self.isBusy else { return }
                    self.refresh(showLoading: false)
                }
            }
        }
    }

    func stopLiveRefresh() {
        liveRefreshTask?.cancel()
        liveRefreshTask = nil
    }

    func copyEmailToPasteboard() {
        guard let address = (state.mailbox ?? MailboxPersistence.restore())?.emailAddress, !address.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(address, forType: .string)
        lastCopiedAt = Date()
    }

    func openInboxInBrowser() {
        do {
            let url = try client.openInboxSession()
            NSWorkspace.shared.open(url)
        } catch {
            // Soft-fail: ignore. A future iteration can surface this.
        }
    }

    func openMessage(_ message: ModihMessage) {
        selectedMessage = message
    }

    func closeMessage() {
        selectedMessage = nil
    }

    func copyMessageCode(_ message: ModihMessage) {
        guard let code = message.oneTimeCodeCandidate else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
        lastCopiedAt = Date()
    }

    // MARK: Internals

    private func loadInternal() async {
        do {
            let mailbox = try await client.fetchCurrentMailbox()
            do {
                let messages = try await client.fetchInboxPreview(limit: 5)
                applyLoadedState(mailbox: mailbox, messages: messages)
            } catch {
                applyMailboxOnlyState(mailbox: mailbox)
            }
        } catch {
            if let mailError = error as? ModihMailError,
               case .inboxExpired = mailError,
               let mailbox = state.mailbox ?? MailboxPersistence.restore()
            {
                selectedMessage = nil
                if state.messages.isEmpty {
                    state = .empty(mailbox)
                } else {
                    state = .loaded(mailbox, state.messages)
                }
                return
            }
            state = .error(error.localizedDescription)
        }
    }

    private func applyMailboxOnlyState(mailbox: ModihMailbox) {
        selectedMessage = nil
        if state.messages.isEmpty {
            state = .empty(mailbox)
        } else {
            state = .loaded(mailbox, state.messages)
        }
    }

    private func applyLoadedState(mailbox: ModihMailbox, messages: [ModihMessage]) {
        let sortedMessages = messages.sorted { lhs, rhs in
            lhs.receivedAt > rhs.receivedAt
        }

        syncSelection(with: sortedMessages)

        if sortedMessages.isEmpty {
            state = .empty(mailbox)
        } else {
            state = .loaded(mailbox, sortedMessages)
        }

        maybeShowPreview(for: sortedMessages)
    }

    private func syncSelection(with messages: [ModihMessage]) {
        guard let selectedMessage else { return }
        self.selectedMessage = messages.first(where: { $0.id == selectedMessage.id })
    }

    private func maybeShowPreview(for messages: [ModihMessage]) {
        guard Defaults[.addOnsEnabled], Defaults[.modihMailEnabled] else { return }

        let newestMessageID = messages.first?.id
        defer {
            if !hasEstablishedPreviewBaseline {
                hasEstablishedPreviewBaseline = true
            }
            if let newestMessageID {
                lastPreviewedMessageID = newestMessageID
            }
        }

        guard hasEstablishedPreviewBaseline,
              let newestMessage = messages.first,
              newestMessage.id != lastPreviewedMessageID
        else {
            return
        }

        NotchlyViewCoordinator.shared.showTempMailPreview(
            message: newestMessage,
            badgeCount: max(1, messages.count)
        )
    }

    private func startBackgroundRefresh() {
        guard backgroundRefreshTask == nil else { return }

        backgroundRefreshTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(6))

            while !Task.isCancelled {
                try? await Task.sleep(for: self.backgroundRefreshInterval)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard Defaults[.addOnsEnabled], Defaults[.modihMailEnabled] else { return }
                    guard !self.isBusy, self.liveRefreshTask == nil else { return }
                    guard MailboxPersistence.restore() != nil || self.state.mailbox != nil else { return }
                    self.refresh(showLoading: false)
                }
            }
        }
    }
}
