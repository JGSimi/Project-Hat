import Foundation
import Security

struct KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.hat.apikey"
    private let account = "userAPIKey"

    private init() {}

    // MARK: - Per-provider methods

    func saveKey(_ key: String, for provider: CloudProvider) {
        save(key, account: provider.keychainAccount)
    }

    func loadKey(for provider: CloudProvider) -> String? {
        load(account: provider.keychainAccount)
    }

    func deleteKey(for provider: CloudProvider) {
        delete(account: provider.keychainAccount)
    }

    // MARK: - Legacy single-key methods (used for migration)

    func saveKey(_ key: String) {
        save(key, account: account)
    }

    func loadKey() -> String? {
        load(account: account)
    }

    func deleteKey() {
        delete(account: account)
    }

    // MARK: - Migration

    static func migrateIfNeeded() {
        let migrated = UserDefaults.standard.bool(forKey: "keychainMigratedPerProvider")
        guard !migrated else { return }

        if let legacyKey = KeychainManager.shared.loadKey(), !legacyKey.isEmpty {
            let currentProvider = SettingsManager.selectedProvider
            KeychainManager.shared.saveKey(legacyKey, for: currentProvider)
            KeychainManager.shared.deleteKey()
        }

        UserDefaults.standard.set(true, forKey: "keychainMigratedPerProvider")
    }

    // MARK: - Private helpers

    private func save(_ key: String, account: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            delete(account: account)
            return
        }

        guard let data = trimmedKey.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("Failed to save API key in Keychain. Status: \(addStatus)")
            }
            return
        }

        if updateStatus != errSecSuccess {
            print("Failed to update API key in Keychain. Status: \(updateStatus)")
        }
    }

    private func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Failed to delete API key from Keychain. Status: \(status)")
        }
    }
}
