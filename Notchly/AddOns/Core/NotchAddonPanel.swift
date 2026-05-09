//
//  NotchAddonPanel.swift
//  Notchly
//
//  Part of the Notchly Add-On layer. Defines the routing enum used by
//  `NotchAddonState` to decide which side panel owns focus inside the
//  inline expanded notch.
//

import Foundation

/// Describes which inline add-on panel is currently in focus.
///
/// `.none` keeps the existing notch behavior intact (collapsed or
/// showing home/notchly views). Any non-`.none` value causes
/// `NotchAddonInlinePanel` to appear inside `NotchHomeView`.
public enum NotchAddonPanel: Equatable {
    case none
    case modihMail
    case webNotifications
    case webApp(WebNotificationAppID)

    /// Human readable label used for debug and accessibility.
    var debugLabel: String {
        switch self {
        case .none: return "None"
        case .modihMail: return "TEMP Mail"
        case .webNotifications: return "Web Notifications"
        case .webApp(let id): return "Web App: \(id.displayName)"
        }
    }
}
