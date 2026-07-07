import Foundation
import Security

protocol TokenStore: AnyObject {
    func load() -> String?
    func save(_ token: String)
    func clear()
}

final class KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String

    init(service: String = "com.hutusi.mercury", account: String = "auth-token") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String) {
        let data = Data(token.utf8)
        let update = [kSecValueData as String: data]

        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

final class InMemoryTokenStore: TokenStore {
    var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func load() -> String? { token }
    func save(_ token: String) { self.token = token }
    func clear() { token = nil }
}
