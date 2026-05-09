//
//  KeychainStore.swift
//  Notchly
//
//  Tiny, dependency-free wrapper around the macOS keychain. Used by the
//  Notchly add-on layer to persist MODIH Mail owner tokens and API keys
//  without dragging a third-party dependency into the project.
//
//  The store is intentionally minimal: all values are `Data`, callers
//  encode/decode themselves. Returns `nil` on any failure path rather
//  than throwing — callers treat a missing secret as an unconnected
//  state, which is the dominant case on first launch.
//

import Foundation
import Security

struct KeychainStore {
    let service: String

    init(service: String = "in.modih.notchly.addons") {
        self.service = service
    }

    // MARK: Data API

    @discardableResult
    func set(_ data: Data, for account: String) -> Bool {
        var query = baseQuery(for: account)
        query[kSecValueData as String] = data

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func data(for account: String) -> Data? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    @discardableResult
    func remove(for account: String) -> Bool {
        let query = baseQuery(for: account)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: String sugar

    @discardableResult
    func setString(_ value: String, for account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return set(data, for: account)
    }

    func string(for account: String) -> String? {
        guard let data = data(for: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Internals

    private func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
    }
}

enum KeychainAccounts {
    static let modihOwnerToken = "modih.ownerToken"
    static let modihInboxId = "modih.inboxId"
    static let modihAPIKey = "modih.apiKey"
    static let modihFirebaseIDToken = "modih.firebaseIDToken"
}
