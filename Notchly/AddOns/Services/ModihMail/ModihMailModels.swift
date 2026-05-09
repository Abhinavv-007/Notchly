//
//  ModihMailModels.swift
//  Notchly
//
//  Value types used by the MODIH Mail add-on. These mirror the JSON
//  contract documented in `modih-mail/functions/api/inbox.js` and
//  `messages.js`.
//

import Foundation

// MARK: - Plan

public enum ModihPlan: String, Codable, Equatable, Sendable {
    case free
    case pro
    case developer
    case unknown

    init(apiValue: String?) {
        switch apiValue?.lowercased() {
        case "free": self = .free
        case "pro": self = .pro
        case "developer": self = .developer
        default: self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .developer: return "Developer"
        case .unknown: return "—"
        }
    }
}

// MARK: - Mailbox

public struct ModihMailbox: Equatable, Codable, Sendable {
    public let id: String
    public let emailAddress: String
    public let createdAt: Date
    public let expiresAt: Date
    public let plan: ModihPlan

    public var remainingTTL: TimeInterval {
        if expiresAt.timeIntervalSince1970 <= 0 { return .infinity }
        return max(0, expiresAt.timeIntervalSinceNow)
    }

    public var isExpired: Bool {
        if expiresAt.timeIntervalSince1970 <= 0 { return false }
        return expiresAt <= Date()
    }
}

// MARK: - Message

public struct ModihMessage: Equatable, Codable, Identifiable, Sendable {
    public let id: String
    public let fromAddress: String
    public let fromName: String?
    public let subject: String?
    public let bodyPreview: String?
    public let receivedAt: Date
    public var unread: Bool

    public var senderDisplay: String {
        if let name = fromName, !name.isEmpty {
            return name
        }
        return fromAddress
    }

    public var bestPreviewLine: String {
        let subject = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !subject.isEmpty {
            return subject
        }

        let preview = bodyPreview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !preview.isEmpty {
            return preview
        }

        return "New message"
    }

    public var oneTimeCodeCandidate: String? {
        let haystacks = [subject, bodyPreview, fromName, fromAddress]
        let patterns = [
            #"(?<!\d)\d{4,8}(?!\d)"#,
            #"\b[A-Z0-9]{4,10}\b"#
        ]

        for text in haystacks {
            guard let text, !text.isEmpty else { continue }
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                guard let match = regex.firstMatch(in: text, options: [], range: range),
                      let swiftRange = Range(match.range, in: text)
                else {
                    continue
                }

                let candidate = String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate.count >= 4 {
                    return candidate
                }
            }
        }

        return nil
    }
}

// MARK: - Connection

public struct ModihConnection: Equatable, Sendable {
    public let hasStoredToken: Bool
    public let hasAPIKey: Bool

    public static let empty = ModihConnection(hasStoredToken: false, hasAPIKey: false)
}

// MARK: - View State

public enum ModihMailState: Equatable {
    case idle
    case loading
    case loaded(ModihMailbox, [ModihMessage])
    case empty(ModihMailbox)
    case error(String)

    public var mailbox: ModihMailbox? {
        switch self {
        case .loaded(let box, _): return box
        case .empty(let box): return box
        default: return nil
        }
    }

    public var messages: [ModihMessage] {
        switch self {
        case .loaded(_, let items): return items
        default: return []
        }
    }

    public var unreadCount: Int {
        messages.filter { $0.unread }.count
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var errorText: String? {
        if case .error(let text) = self { return text }
        return nil
    }
}
