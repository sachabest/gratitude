import Foundation
import CryptoKit
import Security

/// Stores the app's backup encryption key in the Keychain, synced across the
/// user's own devices via iCloud Keychain. The key itself never touches
/// CloudKit — only ciphertext encrypted with it does.
enum EncryptionKeyStore {
    private static let account = "gratitude.backup.key"
    private static let service = "com.sachabest.gratitude.encryption"

    static func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKey() {
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        try save(key: newKey)
        return newKey
    }

    static func hasKey() -> Bool {
        (try? loadKey()).flatMap { $0 } != nil
    }

    private static func loadKey() throws -> SymmetricKey? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status)
        }
    }

    private static func save(key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        var query = baseQuery()
        query[kSecValueData as String] = keyData
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecAttrSynchronizable as String] = true

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery = baseQuery()
            let attributes: [String: Any] = [kSecValueData as String: keyData]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandled(updateStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    static func deleteKey() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]
    }

    enum KeychainError: LocalizedError {
        case unhandled(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unhandled(let status):
                "Keychain error (\(status))"
            }
        }
    }
}
