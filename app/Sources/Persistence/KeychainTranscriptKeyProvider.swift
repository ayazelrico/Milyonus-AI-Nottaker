import Foundation
import Security
import Shared

public struct KeychainTranscriptKeyProvider: TranscriptEncryptionKeyProvider, Sendable {
    private static let keyLength = 32

    private let service: String
    private let account: String

    public init(
        service: String = "com.milyonus.nottaker.transcript-encryption",
        account: String = "local-database-key-v1"
    ) {
        self.service = service
        self.account = account
    }

    public func keyData() async throws -> Data {
        if let existing = try read() {
            guard existing.count == Self.keyLength else {
                throw TranscriptPersistenceError.invalidEncryptionKey
            }
            return existing
        }

        var bytes = [UInt8](repeating: 0, count: Self.keyLength)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw TranscriptPersistenceError.invalidEncryptionKey
        }
        let generated = Data(bytes)
        let status = SecItemAdd(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                kSecValueData: generated,
            ] as CFDictionary,
            nil
        )
        if status == errSecDuplicateItem, let existing = try read(), existing.count == Self.keyLength {
            return existing
        }
        guard status == errSecSuccess else {
            throw TranscriptPersistenceError.invalidEncryptionKey
        }
        return generated
    }

    private func read() throws -> Data? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
            ] as CFDictionary,
            &item
        )
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw TranscriptPersistenceError.invalidEncryptionKey
        }
        return data
    }
}
