import Foundation
import Security

/// Идентификатор ученика: UUID генерируется один раз и живёт в Keychain.
/// user-key сервера: [A-Za-z0-9_-], 1..64 — "ios-" + uuid (40 символов) укладывается.
struct UserKeyManager: Sendable {
    let service: String
    private let account = "user-key"

    static let `default` = UserKeyManager(service: "expert.softsys.asm-protocol")

    func loadOrCreate() -> String {
        if let existing = read() {
            return existing
        }
        let key = "ios-" + UUID().uuidString.lowercased()
        save(key)
        return key
    }

    private func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(_ key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
