//
//  AddOnsDefaults.swift
//  Notchly
//
//  Defaults.Keys scoped to the Notchly Add-On layer (MODIH Mail + Web
//  Notifications). Kept in its own namespace to avoid crowding the main
//  `Constants.swift` file.
//

import Defaults
import Foundation

extension Defaults.Keys {
    // MARK: Master Toggles

    /// Shows the two circular indicators flanking the collapsed notch.
    static let addOnsEnabled = Key<Bool>(
        "addOnsEnabled",
        default: true
    )

    // MARK: MODIH Mail

    static let modihMailEnabled = Key<Bool>(
        "modihMailEnabled",
        default: true
    )

    /// Base URL for the MODIH Mail API. Defaults to the production host.
    static let modihMailBaseURL = Key<String>(
        "modihMailBaseURL",
        default: "https://modih.in"
    )

    /// When true, the app talks to MODIH via the JSON API first and falls
    /// back to a WKWebView inbox only if the contract is missing.
    static let modihMailPreferAPI = Key<Bool>(
        "modihMailPreferAPI",
        default: true
    )

    // MARK: Web Notifications

    static let webNotificationsEnabled = Key<Bool>(
        "webNotificationsEnabled",
        default: true
    )

    /// Minimum interval between background badge polls, in seconds.
    static let webNotificationsRefreshInterval = Key<Double>(
        "webNotificationsRefreshInterval",
        default: 120
    )

    /// Keeps already-opened web app sessions warm and listens for
    /// Notification API, app badge, and document-title changes.
    static let webNotificationsLiveSyncEnabled = Key<Bool>(
        "webNotificationsLiveSyncEnabled",
        default: true
    )

    /// Restores web apps that were previously confirmed signed in so
    /// their page-level notification hooks are active after relaunch.
    static let webNotificationsRestoreSignedInApps = Key<Bool>(
        "webNotificationsRestoreSignedInApps",
        default: true
    )

    /// When enabled, Notchly may create hidden WKWebViews for every
    /// enabled app to poll badges. This is useful, but costs battery.
    static let webNotificationsBackgroundPollingEnabled = Key<Bool>(
        "webNotificationsBackgroundPollingEnabled",
        default: false
    )

    /// Apps that have been observed as signed in at least once. Used to
    /// restore only useful live sessions instead of warming every app.
    static let webNotificationsKnownSignedInApps = Key<[String]>(
        "webNotificationsKnownSignedInApps",
        default: []
    )

    /// Per-app enable/disable flags, keyed by `WebNotificationAppID.rawValue`.
    static let webNotificationsEnabledApps = Key<[String: Bool]>(
        "webNotificationsEnabledApps",
        default: Dictionary(
            uniqueKeysWithValues: WebNotificationAppID.allCases.map {
                ($0.rawValue, $0.defaultEnabled)
            }
        )
    )

    /// One-shot migration counter for the enabled-apps map. Bump whenever
    /// the defaults shipping order or coverage changes so existing users
    /// pick up the new defaults on next launch.
    static let webNotificationsDefaultsVersion = Key<Int>(
        "webNotificationsDefaultsVersion",
        default: 0
    )

    // MARK: MODIH Mail (TEMP Mail)

    /// Stable browser token used as the `X-Browser-Token` header when
    /// talking to modih.in. Generated on first launch.
    static let modihBrowserToken = Key<String>(
        "modihBrowserToken",
        default: ""
    )

    /// Persisted mailbox metadata so the current inbox survives
    /// relaunches without being recreated.
    static let modihMailboxEmail = Key<String>("modihMailboxEmail", default: "")
    static let modihMailboxID = Key<String>("modihMailboxID", default: "")
    static let modihMailboxCreatedAt = Key<Double>("modihMailboxCreatedAt", default: 0)
    static let modihMailboxExpiresAt = Key<Double>("modihMailboxExpiresAt", default: 0)
    static let modihMailboxPlan = Key<String>("modihMailboxPlan", default: "free")
}
