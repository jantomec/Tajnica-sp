import Foundation
import Security

enum KeychainKey: String {
    case geminiAPIKey
    case claudeAPIKey
    case openAIAPIKey
    case togglAPIToken
    case clockifyAPIToken
    case harvestAccessToken
}

protocol KeychainStoring {
    func string(for key: KeychainKey) -> String?
    func set(_ value: String, for key: KeychainKey)
    func removeValue(for key: KeychainKey)
}

final class KeychainStore: KeychainStoring {
    private enum Scope {
        case synchronizable
        case local

        var secValue: CFBoolean {
            switch self {
            case .synchronizable:
                kCFBooleanTrue
            case .local:
                kCFBooleanFalse
            }
        }
    }

    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "Planner") {
        self.service = service
    }

    func string(for key: KeychainKey) -> String? {
        if let value = loadString(for: key, scope: .synchronizable) {
            return value
        }

        guard let legacyValue = loadString(for: key, scope: .local) else {
            return nil
        }

        if upsert(legacyValue, for: key, scope: .synchronizable) == errSecSuccess {
            _ = deleteValue(for: key, scope: .local)
        }

        return legacyValue
    }

    func set(_ value: String, for key: KeychainKey) {
        if upsert(value, for: key, scope: .synchronizable) == errSecSuccess {
            _ = deleteValue(for: key, scope: .local)
            return
        }

        _ = upsert(value, for: key, scope: .local)
    }

    func removeValue(for key: KeychainKey) {
        _ = deleteValue(for: key, scope: .synchronizable)
        _ = deleteValue(for: key, scope: .local)
    }

    private func loadString(for key: KeychainKey, scope: Scope) -> String? {
        var query = query(for: key, scope: scope)
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

    @discardableResult
    private func upsert(_ value: String, for key: KeychainKey, scope: Scope) -> OSStatus {
        let data = Data(value.utf8)
        let query = query(for: key, scope: scope)
        let attributes = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            return SecItemAdd(item as CFDictionary, nil)
        }

        return status
    }

    @discardableResult
    private func deleteValue(for key: KeychainKey, scope: Scope) -> OSStatus {
        SecItemDelete(query(for: key, scope: scope) as CFDictionary)
    }

    private func query(for key: KeychainKey, scope: Scope) -> [String: Any] {
        var query = baseQuery(for: key)
        query[kSecAttrSynchronizable as String] = scope.secValue
        return query
    }

    private func baseQuery(for key: KeychainKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }
}
