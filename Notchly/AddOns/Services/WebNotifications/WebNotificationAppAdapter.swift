//
//  WebNotificationAppAdapter.swift
//  Notchly
//
//  Per-app description used by the aggregator to:
//  - find the correct WKWebView URL
//  - detect whether the user is logged in
//  - scrape a badge count out of the DOM
//
//  Phase A ships the protocol plus concrete adapters. The real
//  WKWebView host is added in Phase C.
//

import Foundation

public struct WebNotificationPreviewCandidate: Decodable, Equatable, Sendable {
    public let title: String
    public let subtitle: String?
}

public protocol WebNotificationAppAdapter: Sendable {
    /// Stable identifier used for Defaults, routing, and logging.
    var id: WebNotificationAppID { get }

    /// Human readable name.
    var displayName: String { get }

    /// Fallback SF Symbol, shown until asset icons are added.
    var fallbackSymbol: String { get }

    /// Home URL the WKWebView should load. Must be https.
    var webURL: URL { get }

    /// JavaScript snippet that returns a non-negative integer representing
    /// the current unread badge count. It must evaluate to `0` when the
    /// user is logged in but has no unread items. Returning `null` means
    /// the adapter could not determine a count.
    var badgeDetectionScript: String { get }

    /// JavaScript snippet that returns `true` when the DOM indicates a
    /// signed-in session and `false` otherwise.
    var loginDetectionScript: String { get }

    /// Optional JavaScript snippet that returns a JSON string
    /// representing a `WebNotificationPreviewCandidate`. Used for the
    /// transient Dynamic Island-style preview when unread counts
    /// increase. Returning `null` falls back to a generic preview.
    var previewDetectionScript: String? { get }

    /// Whether the adapter should be enabled on first launch.
    var defaultEnabled: Bool { get }
}

public extension WebNotificationAppAdapter {
    var displayName: String { id.displayName }
    var fallbackSymbol: String { id.fallbackSymbol }
    var defaultEnabled: Bool { id.defaultEnabled }
    var previewDetectionScript: String? { nil }
}
