//
//  ModihMailClient.swift
//  Notchly
//
//  Protocol that hides the MODIH Mail HTTP contract from the UI layer.
//  The runtime binding is `URLSessionModihMailClient`, which speaks to
//  the Cloudflare Pages functions under `modih.in/api`. The stub
//  implementation is retained only for SwiftUI previews and unit tests.
//

import Defaults
import Foundation

public protocol ModihMailClient: Sendable {
    /// Fetch or create the user's current ephemeral mailbox. For free
    /// tier this maps to `POST /api/inbox` on first call, then reuses
    /// the persisted `inbox_id` + `owner_token` for subsequent calls.
    func fetchCurrentMailbox() async throws -> ModihMailbox

    /// Delete the current mailbox and create a new one.
    func regenerateMailbox() async throws -> ModihMailbox

    /// Read messages for the current mailbox. Empty array for a fresh
    /// inbox. Throws on network/auth failure.
    func fetchInboxPreview(limit: Int) async throws -> [ModihMessage]

    /// Returns a browser URL pointing at the user's inbox on modih.in.
    func openInboxSession() throws -> URL

    /// Reports whether the client currently has enough credentials to
    /// talk to the API. Used by the UI to show a "connect" vs
    /// "connected" dot.
    var connection: ModihConnection { get }
}

// MARK: - Factory

extension ModihMailClient where Self == URLSessionModihMailClient {
    /// Builds the production HTTP client configured from Defaults. Use
    /// this everywhere at runtime; the stub is test-only.
    static func liveFromDefaults() -> URLSessionModihMailClient {
        let base = URL(string: Defaults[.modihMailBaseURL])
            ?? URL(string: "https://modih.in")!
        return URLSessionModihMailClient(baseURL: base)
    }
}

// MARK: - Errors

public enum ModihMailError: LocalizedError, Sendable {
    case notConfigured
    case network(String)
    case decoding(String)
    case httpStatus(Int, String?)
    case inboxExpired
    case unauthorized
    case rateLimited(String?)
    case captchaRequired
    case planLimitExceeded(String?)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Modih Mail is not configured."
        case .network(let detail):
            return "Network error: \(detail)"
        case .decoding(let detail):
            return "Could not parse response: \(detail)"
        case .httpStatus(let code, let message):
            if let message = message, !message.isEmpty {
                return "Server error (\(code)): \(message)"
            }
            return "Server error (\(code))."
        case .inboxExpired:
            return "This inbox expired. Regenerate to continue."
        case .unauthorized:
            return "Owner token was rejected. Regenerate to reset."
        case .rateLimited(let detail):
            return detail ?? "Rate limit reached. Try again in a minute."
        case .captchaRequired:
            return "Captcha required. Open in browser to continue."
        case .planLimitExceeded(let detail):
            return detail ?? "Plan limit reached. Upgrade or wait for reset."
        }
    }
}
