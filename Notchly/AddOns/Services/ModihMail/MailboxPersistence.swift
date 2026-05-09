//
//  MailboxPersistence.swift
//  Notchly
//
//  Lightweight `Defaults`-backed store for temporary-mail metadata.
//  Holds the last-known mailbox email, id, plan, and expiry. Owner
//  tokens stay in the Keychain — this store deliberately never sees
//  them.
//
//  The view model restores from here on launch so the inline panel can
//  display the right address instantly and only hit the network to
//  refresh messages.
//

import Defaults
import Foundation

enum MailboxPersistence {
    /// Persist the given mailbox. Safe to call after every successful
    /// API interaction.
    static func save(_ mailbox: ModihMailbox) {
        guard !mailbox.id.isEmpty else { return }
        Defaults[.modihMailboxID] = mailbox.id
        Defaults[.modihMailboxEmail] = mailbox.emailAddress
        Defaults[.modihMailboxCreatedAt] = mailbox.createdAt.timeIntervalSince1970
        Defaults[.modihMailboxExpiresAt] = mailbox.expiresAt.timeIntervalSince1970
        Defaults[.modihMailboxPlan] = mailbox.plan.rawValue
    }

    /// Rehydrate a previously-saved mailbox. Returns `nil` when the
    /// store is empty.
    static func restore() -> ModihMailbox? {
        let id = Defaults[.modihMailboxID]
        let email = Defaults[.modihMailboxEmail]
        guard !id.isEmpty, !email.isEmpty else { return nil }

        let createdAt = Date(timeIntervalSince1970: Defaults[.modihMailboxCreatedAt])
        let expiresAt = Date(timeIntervalSince1970: Defaults[.modihMailboxExpiresAt])
        let plan = ModihPlan(apiValue: Defaults[.modihMailboxPlan])

        return ModihMailbox(
            id: id,
            emailAddress: email,
            createdAt: createdAt,
            expiresAt: expiresAt,
            plan: plan
        )
    }

    static func clear() {
        Defaults[.modihMailboxID] = ""
        Defaults[.modihMailboxEmail] = ""
        Defaults[.modihMailboxCreatedAt] = 0
        Defaults[.modihMailboxExpiresAt] = 0
        Defaults[.modihMailboxPlan] = "free"
    }
}

// MARK: - Browser token

/// The MODIH API uses an opaque `X-Browser-Token` to cluster creations
/// from a single client for rate limiting. It does not identify the
/// user. A random value is generated on first launch and reused for
/// the lifetime of the install.
enum BrowserTokenStore {
    static func token() -> String {
        let existing = Defaults[.modihBrowserToken]
        if !existing.isEmpty { return existing }
        let fresh = "notchly-mac-\(UUID().uuidString.lowercased())"
        Defaults[.modihBrowserToken] = fresh
        return fresh
    }
}
