import CryptoKit
import Foundation
import Security

@MainActor
protocol ActivationCredentialStorage {
    func deviceID() throws -> String
    func load() throws -> ActivationCredentials?
    func save(_ credentials: ActivationCredentials) throws
}

@MainActor
final class ActivationKeychain: ActivationCredentialStorage {
    private let service = "com.catgo.app.activation"
    private let account: String

    init(baseURL: URL = ActivationConfiguration.baseURL) {
        // 不同服务端的令牌分别保存，避免切换环境时发送旧令牌。
        account = SHA256.hash(data: Data(baseURL.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func deviceID() throws -> String {
        if let data = try read(account: "device-identity"), let id = String(data: data, encoding: .utf8) { return id }
        let id = UUID().uuidString
        try write(Data(id.utf8), account: "device-identity")
        return id
    }

    func load() throws -> ActivationCredentials? {
        guard let data = try read(account: account) else { return nil }
        do { return try JSONDecoder().decode(ActivationCredentials.self, from: data) }
        catch { throw ActivationError.storage }
    }

    func save(_ credentials: ActivationCredentials) throws {
        try write(JSONEncoder().encode(credentials), account: account)
    }

    private func query(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    private func read(account: String) throws -> Data? {
        var query = query(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw ActivationError.storage }
        return data
    }

    private func write(_ data: Data, account: String) throws {
        let query = query(account: account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw ActivationError.storage }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw ActivationError.storage }
    }
}
