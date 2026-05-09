//
//  StubModihMailClient.swift
//  Notchly
//
//  Deterministic in-memory client used during Phase A development and
//  as the development fallback when the real MODIH endpoint is
//  unreachable. Generates a fake mailbox that behaves like a real
//  free-tier one: 3h TTL, reset by `regenerateMailbox()`, zero inbox by
//  default so the UI defaults to the empty state.
//

import Foundation

actor StubModihMailClient: ModihMailClient {
    private var cached: ModihMailbox?
    private let ttl: TimeInterval = 3 * 60 * 60
    private let baseURL: URL

    nonisolated let connection = ModihConnection(hasStoredToken: true, hasAPIKey: false)

    init(baseURL: URL = URL(string: "https://modih.in")!) {
        self.baseURL = baseURL
    }

    func fetchCurrentMailbox() async throws -> ModihMailbox {
        if let cached, !cached.isExpired {
            return cached
        }
        return try await regenerateMailbox()
    }

    func regenerateMailbox() async throws -> ModihMailbox {
        let now = Date()
        let fresh = ModihMailbox(
            id: randomId(length: 12),
            emailAddress: "\(randomPrefix())@modih.in",
            createdAt: now,
            expiresAt: now.addingTimeInterval(ttl),
            plan: .free
        )
        cached = fresh
        return fresh
    }

    func fetchInboxPreview(limit: Int) async throws -> [ModihMessage] {
        // Phase A: empty inbox, matching the "just created" free-tier reality.
        return []
    }

    nonisolated func openInboxSession() throws -> URL {
        baseURL
    }

    // MARK: Helpers

    private func randomPrefix() -> String {
        let adjectives = ["swift", "cool", "bright", "lucky", "calm", "bold", "keen", "pure"]
        let nouns = ["fox", "owl", "ray", "star", "wave", "leaf", "wind", "moon"]
        let adj = adjectives.randomElement() ?? "swift"
        let noun = nouns.randomElement() ?? "fox"
        let num = Int.random(in: 10...999)
        return "\(adj)\(noun)\(num)"
    }

    private func randomId(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
