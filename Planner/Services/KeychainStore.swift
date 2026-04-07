import Foundation
import Security

enum KeychainKey: String {
    case geminiAPIKey
    case claudeAPIKey
    case openAIAPIKey
    case togglAPIToken
}

protocol KeychainStoring {
    func string(for key: KeychainKey) -> String?
    func set(_ value: String, for key: KeychainKey)
    func removeValue(for key: KeychainKey)
}

final class KeychainStore: KeychainStoring {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "Planner") {
        self.service = service
    }

    func string(for key: KeychainKey) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    func set(_ value: String, for key: KeychainKey) {
        let data = Data(value.utf8)
        let query = baseQuery(for: key)
        let attributes = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func removeValue(for key: KeychainKey) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: KeychainKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }
}
