import Foundation
import Security

struct StoredBiometricAccount: Codable, Equatable {
    let userId: String
    let email: String
    let refreshToken: String
}

final class KeychainService {
    static let shared = KeychainService()

    private let service = "UNAP.ROOM-UNAP.biometric-login"
    private let account = "saved-biometric-account"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    func saveBiometricAccount(_ account: StoredBiometricAccount) throws {
        let data = try encoder.encode(account)
        let query = baseQuery()

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    func loadBiometricAccount() throws -> StoredBiometricAccount? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return try decoder.decode(StoredBiometricAccount.self, from: data)
    }

    func savedBiometricEmail() -> String? {
        try? loadBiometricAccount()?.email
    }

    func deleteBiometricAccount() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainError: LocalizedError {
    case invalidData
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "La cuenta guardada en el dispositivo no se pudo leer."
        case .unhandledStatus(let status):
            return "Keychain devolvio un estado inesperado: \(status)."
        }
    }
}
