//
//  WebNotificationState.swift
//  Notchly
//
//  Aggregated state for every web notification adapter. Owned by
//  `NotchAddonState.shared`. This is the object the UI observes when
//  rendering the right-side badge and the expanded strip of icons.
//

import Combine
import Defaults
import Foundation

@MainActor
final class WebNotificationState: ObservableObject {
    static let shared = WebNotificationState()

    // MARK: - Per-App Snapshot

    public struct AppSnapshot: Equatable {
        public enum Login: Equatable {
            case unknown
            case signedIn
            case signedOut
        }

        public let id: WebNotificationAppID
        public var isEnabled: Bool
        public var login: Login
        public var unreadCount: Int
        public var lastRefresh: Date?
        public var errorText: String?

        public static func initial(for id: WebNotificationAppID, enabled: Bool) -> AppSnapshot {
            AppSnapshot(
                id: id,
                isEnabled: enabled,
                login: .unknown,
                unreadCount: 0,
                lastRefresh: nil,
                errorText: nil
            )
        }
    }

    // MARK: - Published

    @Published public private(set) var snapshots: [WebNotificationAppID: AppSnapshot] = [:]

    /// Total unread count across every enabled adapter. Drives the
    /// collapsed notch right indicator badge.
    @Published public private(set) var totalUnreadCount: Int = 0

    /// True when at least one adapter is enabled and at least one
    /// snapshot has `unreadCount > 0`.
    public var hasAnyUnread: Bool { totalUnreadCount > 0 }

    // MARK: - Init

    private init() {
        reloadFromDefaults()
    }

    // MARK: - Public API

    /// Rebuild snapshots from the Defaults-backed per-app toggle map.
    /// Called at init and whenever Settings changes an enabled flag.
    public func reloadFromDefaults() {
        let toggles = Defaults[.webNotificationsEnabledApps]
        var next: [WebNotificationAppID: AppSnapshot] = [:]
        for app in WebNotificationAppID.allCases {
            let enabled = toggles[app.rawValue] ?? app.defaultEnabled
            if let existing = snapshots[app] {
                next[app] = AppSnapshot(
                    id: app,
                    isEnabled: enabled,
                    login: existing.login,
                    unreadCount: enabled ? existing.unreadCount : 0,
                    lastRefresh: existing.lastRefresh,
                    errorText: existing.errorText
                )
            } else {
                next[app] = .initial(for: app, enabled: enabled)
            }
        }
        snapshots = next
        recomputeTotal()
    }

    /// Called by the aggregator after a successful badge poll.
    public func apply(
        unreadCount: Int,
        login: AppSnapshot.Login,
        for app: WebNotificationAppID
    ) {
        guard var snap = snapshots[app] else { return }
        snap.unreadCount = max(0, unreadCount)
        snap.login = login
        snap.lastRefresh = Date()
        snap.errorText = nil
        snapshots[app] = snap
        updateKnownSignedInApps(login: login, app: app)
        recomputeTotal()
    }

    /// Called when a polling attempt fails.
    public func apply(error: String, for app: WebNotificationAppID) {
        guard var snap = snapshots[app] else { return }
        snap.errorText = error
        snap.lastRefresh = Date()
        snapshots[app] = snap
    }

    /// Toggle a single app at runtime. Persists and refreshes the
    /// derived aggregate.
    public func setEnabled(_ enabled: Bool, for app: WebNotificationAppID) {
        var toggles = Defaults[.webNotificationsEnabledApps]
        toggles[app.rawValue] = enabled
        Defaults[.webNotificationsEnabledApps] = toggles
        reloadFromDefaults()
    }

    /// Ordered array used by the expanded icon strip and settings UI.
    public var orderedSnapshots: [AppSnapshot] {
        WebNotificationAppID.allCases
            .filter(\.isVisibleInCurrentBuild)
            .compactMap { snapshots[$0] }
    }

    // MARK: - Helpers

    private func recomputeTotal() {
        totalUnreadCount = snapshots.values
            .filter { $0.isEnabled && $0.id.isVisibleInCurrentBuild }
            .map { $0.unreadCount }
            .reduce(0, +)
    }

    private func updateKnownSignedInApps(login: AppSnapshot.Login, app: WebNotificationAppID) {
        var known = Set(Defaults[.webNotificationsKnownSignedInApps])

        switch login {
        case .signedIn:
            known.insert(app.rawValue)
        case .signedOut:
            known.remove(app.rawValue)
        case .unknown:
            return
        }

        Defaults[.webNotificationsKnownSignedInApps] = WebNotificationAppID.allCases
            .map(\.rawValue)
            .filter { known.contains($0) }
    }
}
