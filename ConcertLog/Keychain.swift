import Foundation
import Security

/// Сессия Supabase, которую храним в Keychain.
nonisolated struct AuthSession: Codable, Sendable, Equatable {
    var accessToken: String
    var refreshToken: String
    /// Момент истечения access-токена.
    var expiresAt: Date
    var userID: String
    var nick: String
}

/// Минимальная обёртка над Keychain (generic password).
nonisolated enum Keychain {
    private static let service = "app.beentoshow.session"
    private static let account = "supabase-session"

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// Сохраняет сессию. Возвращает false, если Keychain не принял запись.
    @discardableResult
    static func saveSession(_ session: AuthSession) -> Bool {
        guard let data = try? JSONEncoder().encode(session) else { return false }
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            // Заодно переводит старые записи (AfterFirstUnlock) на ThisDeviceOnly.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemUpdate(baseQuery() as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var query = baseQuery()
            for (k, v) in attrs { query[k] = v }
            status = SecItemAdd(query as CFDictionary, nil)
        }
        return status == errSecSuccess
    }

    static func loadSession() -> AuthSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    static func deleteSession() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
