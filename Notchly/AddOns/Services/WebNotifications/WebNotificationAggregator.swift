//
//  WebNotificationAggregator.swift
//  Notchly
//
//  Polls each enabled adapter periodically by evaluating its badge +
//  login JavaScript against a persistent, shared WKWebView owned by
//  `WebNotificationSessionManager`. Results land in
//  `WebNotificationState` which drives the collapsed badge and the
//  expanded icon strip.
//
//  Polling is sequential (one adapter at a time) so concurrent
//  WKWebView evaluations do not starve the main thread. The loop
//  snoozes between passes based on
//  `Defaults[.webNotificationsRefreshInterval]`.
//

import AppKit
import Combine
import Defaults
import Foundation
import WebKit

@MainActor
final class WebNotificationAggregator: ObservableObject {
    static let shared = WebNotificationAggregator()

    // MARK: Dependencies

    private let state: WebNotificationState
    private let sessionManager: WebNotificationSessionManager
    private let adapters: [WebNotificationAppID: WebNotificationAppAdapter]

    // MARK: Lifecycle

    private var pollTask: Task<Void, Never>?
    private var hasLoadedHomeForApp: Set<WebNotificationAppID> = []
    private var lastUnreadCounts: [WebNotificationAppID: Int] = [:]
    private var establishedBaseline: Set<WebNotificationAppID> = []
    private var lastSignedOutRefresh: [WebNotificationAppID: Date] = [:]
    private var isPolling = false
    private var didRestoreSignedInSessions = false

    private let liveSessionRefreshInterval: TimeInterval = 15
    private let signedOutRetryInterval: TimeInterval = 600
    private let restoredSessionLoadSpacing: TimeInterval = 2.5

    // MARK: Init

    private init() {
        self.state = .shared
        self.sessionManager = .shared
        self.adapters = Dictionary(uniqueKeysWithValues: WebNotificationAdapters.all.map { ($0.id, $0) })
    }

    // MARK: Public API

    /// Start the polling loop. Safe to call more than once.
    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            // Give the app time to settle before hitting the network.
            try? await Task.sleep(for: .seconds(2))
            await self?.restoreKnownSignedInSessionsIfNeeded()
            while !Task.isCancelled {
                await self?.pollOnce()
                let interval = await self?.nextPollInterval() ?? 120
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Force a single refresh pass now. Safe to call from UI buttons.
    func refreshNow(forceLoadMissing: Bool = false) {
        Task { await pollOnce(forceLoadMissing: forceLoadMissing) }
    }

    func refreshApp(_ appID: WebNotificationAppID, forceLoadIfNeeded: Bool = false) {
        Task {
            guard let adapter = adapters[appID] else { return }
            await poll(adapter: adapter, forceLoadIfNeeded: forceLoadIfNeeded)
        }
    }

    /// Clear the "home page already loaded" memo so the next poll
    /// performs a full reload. Useful after sign-out.
    func invalidate(app: WebNotificationAppID) {
        hasLoadedHomeForApp.remove(app)
        lastUnreadCounts.removeValue(forKey: app)
        establishedBaseline.remove(app)
        lastSignedOutRefresh.removeValue(forKey: app)
    }

    // MARK: Internals

    private func pollOnce(forceLoadMissing: Bool = false) async {
        guard Defaults[.addOnsEnabled], Defaults[.webNotificationsEnabled] else { return }
        guard !isPolling else { return }

        isPolling = true
        defer { isPolling = false }

        if !Defaults[.webNotificationsBackgroundPollingEnabled] && !forceLoadMissing {
            sessionManager.tearDownBackgroundViews()
            hasLoadedHomeForApp.removeAll()
        }

        for snap in state.orderedSnapshots where snap.isEnabled {
            guard let adapter = adapters[snap.id] else { continue }
            await poll(adapter: adapter, forceLoadIfNeeded: forceLoadMissing)
        }
    }

    private func poll(adapter: WebNotificationAppAdapter, forceLoadIfNeeded: Bool) async {
        let webView: WKWebView
        let canUseLiveBrowserSession = Defaults[.webNotificationsLiveSyncEnabled]
        let canCreateBackgroundSession = forceLoadIfNeeded || Defaults[.webNotificationsBackgroundPollingEnabled]

        if canUseLiveBrowserSession,
           let browserWebView = sessionManager.existingBrowserWebView(for: adapter),
           shouldUseBrowserWebView(browserWebView, for: adapter) {
            webView = browserWebView
            if browserWebView.url == nil {
                sessionManager.loadHomeInBrowser(for: adapter)
                await waitForLoad(browserWebView)
            } else if browserWebView.isLoading {
                await waitForLoad(browserWebView)
            }
        } else {
            guard canCreateBackgroundSession else { return }
            guard shouldRetryBackgroundSession(for: adapter.id) else { return }

            webView = sessionManager.webView(for: adapter)

            // First visit: load the home URL so cookies/session storage get
            // populated. Subsequent polls re-evaluate JS against whatever is
            // already in the web view — no extra network hit.
            if !hasLoadedHomeForApp.contains(adapter.id) || webView.url == nil {
                sessionManager.loadHome(for: adapter)
                await waitForLoad(webView)
                hasLoadedHomeForApp.insert(adapter.id)
            }
        }

        let login = await evaluateLogin(webView: webView, script: adapter.loginDetectionScript)
        let unread = max(
            await evaluateBadge(webView: webView, script: adapter.badgeDetectionScript) ?? 0,
            await evaluateTitleBadge(webView: webView) ?? 0
        )
        let previousUnread = lastUnreadCounts[adapter.id] ?? 0
        let shouldPreview = establishedBaseline.contains(adapter.id) && login == .signedIn && unread > previousUnread

        if shouldPreview {
            let preview = await evaluatePreview(webView: webView, script: adapter.previewDetectionScript)
                ?? fallbackPreview(for: adapter, unreadCount: unread)

            NotchlyViewCoordinator.shared.showWebNotificationPreview(
                appID: adapter.id,
                title: preview.title,
                subtitle: preview.subtitle,
                badgeCount: unread
            )
        }

        state.apply(unreadCount: unread, login: login, for: adapter.id)
        lastUnreadCounts[adapter.id] = unread
        establishedBaseline.insert(adapter.id)

        if login == .signedOut {
            lastSignedOutRefresh[adapter.id] = Date()
        } else if login == .signedIn {
            lastSignedOutRefresh.removeValue(forKey: adapter.id)
        }
    }

    private func nextPollInterval() async -> TimeInterval {
        if Defaults[.webNotificationsLiveSyncEnabled], !sessionManager.liveAppIDs.isEmpty {
            return liveSessionRefreshInterval
        }

        if Defaults[.webNotificationsBackgroundPollingEnabled] {
            return max(60, Defaults[.webNotificationsRefreshInterval])
        }

        return 300
    }

    private func shouldRetryBackgroundSession(for appID: WebNotificationAppID) -> Bool {
        guard let last = lastSignedOutRefresh[appID] else { return true }
        return Date().timeIntervalSince(last) >= signedOutRetryInterval
    }

    private func restoreKnownSignedInSessionsIfNeeded() async {
        guard !didRestoreSignedInSessions else { return }
        didRestoreSignedInSessions = true

        guard Defaults[.addOnsEnabled],
              Defaults[.webNotificationsEnabled],
              Defaults[.webNotificationsLiveSyncEnabled],
              Defaults[.webNotificationsRestoreSignedInApps] else {
            return
        }

        let enabled = Defaults[.webNotificationsEnabledApps]
        let known = Set(Defaults[.webNotificationsKnownSignedInApps])
        let restoreIDs = WebNotificationAppID.allCases.filter { appID in
            appID.isVisibleInCurrentBuild
                && (enabled[appID.rawValue] ?? appID.defaultEnabled)
                && known.contains(appID.rawValue)
        }

        for appID in restoreIDs {
            guard let adapter = adapters[appID] else { continue }
            sessionManager.loadHomeInBrowser(for: adapter)
            await poll(adapter: adapter, forceLoadIfNeeded: false)
            try? await Task.sleep(for: .seconds(restoredSessionLoadSpacing))
        }
    }

    private func shouldUseBrowserWebView(
        _ webView: WKWebView,
        for adapter: WebNotificationAppAdapter
    ) -> Bool {
        guard let url = webView.url else { return true }
        return matchesAdapterHost(url, adapter: adapter)
    }

    private func matchesAdapterHost(_ url: URL, adapter: WebNotificationAppAdapter) -> Bool {
        guard
            let currentHost = url.host?.lowercased(),
            let targetHost = adapter.webURL.host?.lowercased()
        else {
            return false
        }

        return currentHost == targetHost
            || currentHost.hasSuffix(".\(targetHost)")
            || targetHost.hasSuffix(".\(currentHost)")
    }

    // MARK: - Script evaluation helpers

    private func waitForLoad(_ webView: WKWebView, timeout: TimeInterval = 15) async {
        let deadline = Date().addingTimeInterval(timeout)
        while webView.isLoading, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(250))
        }
        // Small settle delay so SPA frameworks have a chance to mount.
        try? await Task.sleep(for: .milliseconds(600))
    }

    private func evaluateBadge(webView: WKWebView, script: String) async -> Int? {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { value, _ in
                if let intValue = value as? Int {
                    continuation.resume(returning: max(0, intValue))
                } else if let doubleValue = value as? Double {
                    continuation.resume(returning: max(0, Int(doubleValue)))
                } else if let str = value as? String, let parsed = Int(str) {
                    continuation.resume(returning: max(0, parsed))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func evaluateTitleBadge(webView: WKWebView) async -> Int? {
        let title: String? = await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("document.title || ''") { value, _ in
                continuation.resume(returning: value as? String)
            }
        }

        guard let title else { return nil }
        return parseUnreadCount(fromTitle: title)
    }

    private func evaluateLogin(
        webView: WKWebView,
        script: String
    ) async -> WebNotificationState.AppSnapshot.Login {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { value, _ in
                if let bool = value as? Bool {
                    continuation.resume(returning: bool ? .signedIn : .signedOut)
                } else {
                    continuation.resume(returning: .unknown)
                }
            }
        }
    }

    private func evaluatePreview(
        webView: WKWebView,
        script: String?
    ) async -> WebNotificationPreviewCandidate? {
        guard let script else { return nil }

        let jsonString: String? = await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { value, _ in
                continuation.resume(returning: value as? String)
            }
        }

        guard
            let jsonString,
            let data = jsonString.data(using: .utf8),
            let preview = try? JSONDecoder().decode(WebNotificationPreviewCandidate.self, from: data)
        else {
            return nil
        }

        let title = preview.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = preview.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !(subtitle ?? "").isEmpty else { return nil }

        return WebNotificationPreviewCandidate(
            title: title.isEmpty ? "New notification" : title,
            subtitle: subtitle
        )
    }

    private func fallbackPreview(
        for adapter: WebNotificationAppAdapter,
        unreadCount: Int
    ) -> WebNotificationPreviewCandidate {
        let subtitle: String
        if unreadCount <= 1 {
            subtitle = "New notification"
        } else {
            subtitle = "\(unreadCount) new notifications"
        }

        return WebNotificationPreviewCandidate(
            title: adapter.displayName,
            subtitle: subtitle
        )
    }

    private func parseUnreadCount(fromTitle title: String) -> Int? {
        let patterns = [
            #"\(\s*(\d{1,4})\s*\)"#,
            #"\[\s*(\d{1,4})\s*\]"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(title.startIndex..<title.endIndex, in: title)
            guard let match = regex.firstMatch(in: title, range: range),
                  let countRange = Range(match.range(at: 1), in: title),
                  let count = Int(title[countRange]) else {
                continue
            }
            return max(0, count)
        }

        return nil
    }
}
