//
//  URLSessionModihMailClient.swift
//  Notchly
//
//  Real HTTP implementation of `ModihMailClient`. Talks to the
//  Cloudflare Pages functions at `https://modih.in/api`.
//
//  Free-tier, no-login flow is the default:
//    POST /api/inbox          → create temporary inbox
//    GET  /api/messages       → poll for mail
//    DELETE /api/inbox        → manual regenerate
//
//  Persistence split:
//    - owner_token → Keychain (sensitive)
//    - email, inbox_id, expires_at, plan → Defaults (replayable UI state)
//    - X-Browser-Token → Defaults (stable per install)
//
//  API key from Keychain is sent as `X-API-Key` when present. A Firebase
//  bearer token is sent when present (kept for future paid-plan flows).
//

import Defaults
import Foundation

actor URLSessionModihMailClient: ModihMailClient {

    // MARK: Dependencies

    private let baseURL: URL
    private let session: URLSession
    private let keychain: KeychainStore
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    // MARK: Credentials

    private var cachedMailbox: ModihMailbox?

    // MARK: Init

    init(
        baseURL: URL,
        session: URLSession = .shared,
        keychain: KeychainStore = KeychainStore()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }
            if let seconds = try? container.decode(Int.self) {
                return Date(timeIntervalSince1970: TimeInterval(seconds))
            }
            let str = try container.decode(String.self)
            if let seconds = Double(str) {
                return Date(timeIntervalSince1970: seconds)
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(str)"
            )
        }
        self.jsonDecoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        self.jsonEncoder = encoder
    }

    // MARK: Connection status

    nonisolated var connection: ModihConnection {
        ModihConnection(
            hasStoredToken: keychain.string(for: KeychainAccounts.modihOwnerToken) != nil,
            hasAPIKey: keychain.string(for: KeychainAccounts.modihAPIKey) != nil
        )
    }

    // MARK: Public API

    func fetchCurrentMailbox() async throws -> ModihMailbox {
        if let cached = cachedMailbox {
            return cached
        }

        if let restored = MailboxPersistence.restore() {
            if keychain.string(for: KeychainAccounts.modihInboxId) == nil {
                keychain.setString(restored.id, for: KeychainAccounts.modihInboxId)
            }
            cachedMailbox = restored
            return restored
        }

        // No mailbox is currently restorable, so create one on demand.
        MailboxPersistence.clear()
        keychain.remove(for: KeychainAccounts.modihInboxId)
        keychain.remove(for: KeychainAccounts.modihOwnerToken)
        return try await createNewMailbox()
    }

    func regenerateMailbox() async throws -> ModihMailbox {
        // Best-effort: delete the existing inbox if we know about it.
        if let id = keychain.string(for: KeychainAccounts.modihInboxId),
           let token = keychain.string(for: KeychainAccounts.modihOwnerToken) {
            try? await deleteInbox(id: id, ownerToken: token)
        }
        keychain.remove(for: KeychainAccounts.modihInboxId)
        keychain.remove(for: KeychainAccounts.modihOwnerToken)
        MailboxPersistence.clear()
        cachedMailbox = nil
        return try await createNewMailbox()
    }

    func fetchInboxPreview(limit: Int) async throws -> [ModihMessage] {
        let restoredID = MailboxPersistence.restore()?.id
        guard let id = keychain.string(for: KeychainAccounts.modihInboxId) ?? restoredID,
              let token = keychain.string(for: KeychainAccounts.modihOwnerToken) else {
            throw ModihMailError.notConfigured
        }

        if keychain.string(for: KeychainAccounts.modihInboxId) == nil {
            keychain.setString(id, for: KeychainAccounts.modihInboxId)
        }

        var comps = URLComponents(
            url: endpointURL("messages"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "inbox_id", value: id)]
        guard let url = comps?.url else { throw ModihMailError.notConfigured }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(token, forHTTPHeaderField: "X-Owner-Token")
        request.setValue("Notchly macOS", forHTTPHeaderField: "X-Notchly-Desktop-Client")
        if let apiKey = keychain.string(for: KeychainAccounts.modihAPIKey) {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        let envelope: APIMessagesResponse = try await perform(request)
        // Keep persisted metadata in sync with whatever the server last returned.
        let refreshed = ModihMailbox(
            id: envelope.inbox.id,
            emailAddress: envelope.inbox.email,
            createdAt: envelope.inbox.created_at,
            expiresAt: envelope.inbox.expires_at,
            plan: cachedMailbox?.plan ?? ModihPlan(apiValue: Defaults[.modihMailboxPlan])
        )
        MailboxPersistence.save(refreshed)
        cachedMailbox = refreshed
        return Array(envelope.messages.prefix(limit)).map { $0.toDomain() }
    }

    nonisolated func openInboxSession() throws -> URL {
        // The web UI picks up an inbox id via localStorage, not via
        // query string, so for now we just hand back the landing page.
        return baseURL
    }

    // MARK: Helpers

    private func createNewMailbox() async throws -> ModihMailbox {
        let url = endpointURL("inbox")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(BrowserTokenStore.token(), forHTTPHeaderField: "X-Browser-Token")
        request.setValue("Notchly macOS", forHTTPHeaderField: "X-Notchly-Desktop-Client")
        if let apiKey = keychain.string(for: KeychainAccounts.modihAPIKey) {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        if let firebase = keychain.string(for: KeychainAccounts.modihFirebaseIDToken) {
            request.setValue("Bearer \(firebase)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try jsonEncoder.encode([String: String]())

        let envelope: APICreateInboxResponse = try await perform(request)
        let mailbox = envelope.toMailbox()

        keychain.setString(mailbox.id, for: KeychainAccounts.modihInboxId)
        if let token = envelope.owner_token {
            keychain.setString(token, for: KeychainAccounts.modihOwnerToken)
        }
        MailboxPersistence.save(mailbox)

        cachedMailbox = mailbox
        return mailbox
    }

    private func deleteInbox(id: String, ownerToken: String) async throws {
        var comps = URLComponents(
            url: endpointURL("inbox"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "id", value: id)]
        guard let url = comps?.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 10
        request.setValue(ownerToken, forHTTPHeaderField: "X-Owner-Token")

        _ = try await session.data(for: request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ModihMailError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ModihMailError.network("No HTTP response")
        }

        if !(200..<300).contains(http.statusCode) {
            let envelope = try? jsonDecoder.decode(APIErrorEnvelope.self, from: data)
            let code = envelope?.error?.code
            let message = envelope?.error?.message
            let failedAuthentication = (message ?? "").localizedCaseInsensitiveContains("failed authentication")

            switch (http.statusCode, code) {
            case (_, "CAPTCHA_REQUIRED"), (_, "CAPTCHA_FAILED"):
                throw ModihMailError.captchaRequired
            case (_, "RATE_LIMITED") where failedAuthentication:
                MailboxPersistence.clear()
                keychain.remove(for: KeychainAccounts.modihInboxId)
                keychain.remove(for: KeychainAccounts.modihOwnerToken)
                cachedMailbox = nil
                throw ModihMailError.unauthorized
            case (429, _) where failedAuthentication:
                MailboxPersistence.clear()
                keychain.remove(for: KeychainAccounts.modihInboxId)
                keychain.remove(for: KeychainAccounts.modihOwnerToken)
                cachedMailbox = nil
                throw ModihMailError.unauthorized
            case (_, "RATE_LIMITED"), (429, _):
                throw ModihMailError.rateLimited(message)
            case (_, "PLAN_LIMIT_EXCEEDED"):
                throw ModihMailError.planLimitExceeded(message)
            case (_, "INBOX_EXPIRED"), (_, "INBOX_NOT_FOUND"):
                throw ModihMailError.inboxExpired
            case (401, _), (403, _):
                throw ModihMailError.unauthorized
            default:
                throw ModihMailError.httpStatus(http.statusCode, message)
            }
        }

        do {
            let envelope = try jsonDecoder.decode(APIEnvelope<T>.self, from: data)
            guard let payload = envelope.data else {
                throw ModihMailError.decoding("Missing data field")
            }
            return payload
        } catch {
            throw ModihMailError.decoding(String(describing: error))
        }
    }

    private func endpointURL(_ path: String) -> URL {
        let trimmedPath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.hasSuffix("api") {
            return baseURL.appendingPathComponent(path)
        }
        return baseURL
            .appendingPathComponent("api")
            .appendingPathComponent(path)
    }
}

// MARK: - Wire format

private struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
}

private struct APIErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let code: String?
        let message: String?
    }
    let success: Bool
    let error: ErrorBody?
}

private struct APICreateInboxResponse: Decodable {
    let id: String
    let email: String
    let created_at: Date
    let expires_at: Date
    let owner_token: String?
    let plan: String?

    func toMailbox() -> ModihMailbox {
        ModihMailbox(
            id: id,
            emailAddress: email,
            createdAt: created_at,
            expiresAt: expires_at,
            plan: ModihPlan(apiValue: plan)
        )
    }
}

private struct APIMessagesResponse: Decodable {
    struct Envelope: Decodable {
        let id: String
        let email: String
        let created_at: Date
        let expires_at: Date
    }
    struct Row: Decodable {
        let id: String
        let from_address: String?
        let from_name: String?
        let subject: String?
        let body_text: String?
        let received_at: Date

        func toDomain() -> ModihMessage {
            let preview: String? = body_text.map {
                String($0.prefix(140)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ModihMessage(
                id: id,
                fromAddress: from_address ?? "",
                fromName: from_name,
                subject: subject,
                bodyPreview: preview,
                receivedAt: received_at,
                unread: true
            )
        }
    }

    let inbox: Envelope
    let messages: [Row]
    let count: Int?
}
