//
//  WebNotificationAppID.swift
//  Notchly
//
//  Canonical identifier for each supported web notification source.
//  Apple Messages / iMessage is intentionally excluded.
//

import Foundation
import SwiftUI

public enum WebNotificationAppID: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    // Declaration order is the canonical ordering used by the expanded
    // icon strip and the settings pane. Apple Messages / iMessage is
    // intentionally excluded.
    case discord
    case telegram
    case instagram
    case whatsapp
    case gmail
    case slack
    case reddit

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gmail: return "Gmail"
        case .discord: return "Discord"
        case .telegram: return "Telegram"
        case .instagram: return "Instagram"
        case .whatsapp: return "WhatsApp"
        case .slack: return "Slack"
        case .reddit: return "Reddit"
        }
    }

    /// SF Symbol fallback used until asset catalog icons are shipped.
    public var fallbackSymbol: String {
        switch self {
        case .gmail: return "envelope.fill"
        case .discord: return "gamecontroller.fill"
        case .telegram: return "paperplane.fill"
        case .instagram: return "camera.fill"
        case .whatsapp: return "message.fill"
        case .slack: return "number.square.fill"
        case .reddit: return "bubble.left.and.bubble.right.fill"
        }
    }

    /// Brand accent used for badges and chips. Tweak later with real assets.
    public var accentColor: Color {
        switch self {
        case .gmail: return Color(red: 0.91, green: 0.26, blue: 0.21)
        case .discord: return Color(red: 0.35, green: 0.40, blue: 0.95)
        case .telegram: return Color(red: 0.15, green: 0.58, blue: 0.89)
        case .instagram: return Color(red: 0.89, green: 0.28, blue: 0.52)
        case .whatsapp: return Color(red: 0.14, green: 0.70, blue: 0.31)
        case .slack: return Color(red: 0.56, green: 0.22, blue: 0.55)
        case .reddit: return Color(red: 0.98, green: 0.27, blue: 0.12)
        }
    }

    public var officialIconURL: URL? {
        switch self {
        case .discord:
            return URL(string: "https://discord.com/assets/favicon.ico")
        case .telegram:
            return URL(string: "https://telegram.org/img/apple-touch-icon.png")
        case .instagram:
            return URL(string: "https://www.instagram.com/static/images/ico/favicon-192.png/68d99ba29cc8.png")
        case .whatsapp:
            return URL(string: "https://www.whatsapp.com/apple-touch-icon.png")
        case .gmail:
            return URL(string: "https://ssl.gstatic.com/ui/v1/icons/mail/rfr/gmail.ico")
        case .slack:
            return nil
        case .reddit:
            return URL(string: "https://www.redditstatic.com/shreddit/assets/favicon/192x192.png")
        }
    }

    /// Default toggle state used when the user has never expressed a
    /// preference. All seven supported apps are enabled by default so
    /// the expanded notification strip reflects the full set on first
    /// run.
    public var defaultEnabled: Bool {
        self != .slack
    }

    public var isVisibleInCurrentBuild: Bool {
        self != .slack
    }
}
