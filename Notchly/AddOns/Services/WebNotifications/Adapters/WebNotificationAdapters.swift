//
//  WebNotificationAdapters.swift
//  Notchly
//
//  Central registry. Provides a canonical ordering and a by-id lookup
//  for the aggregator.
//

import Foundation

enum WebNotificationAdapters {
    /// Canonical ordering used by the icon strip and settings list.
    /// Matches `WebNotificationAppID.allCases` declaration order.
    static let all: [WebNotificationAppAdapter] = [
        DiscordAdapter(),
        TelegramAdapter(),
        InstagramAdapter(),
        WhatsAppAdapter(),
        GmailAdapter(),
        RedditAdapter(),
    ]

    static func adapter(for id: WebNotificationAppID) -> WebNotificationAppAdapter? {
        all.first { $0.id == id }
    }
}
