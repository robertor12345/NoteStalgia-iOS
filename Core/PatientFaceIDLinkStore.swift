import Foundation
import Security

/// Persists which care profile is tied to device Face ID / Touch ID on this iPad.
enum PatientFaceIDLinkStore {
    private static let service = "com.notestalgia.ios.faceid.patient"
    private static let account = "linkedPatientId"

    static func linkedPatientId() -> UUID? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let raw = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: raw)
        else {
            return nil
        }
        return uuid
    }

    static func setLinkedPatientId(_ id: UUID?) {
        deleteLinkedPatientId()
        guard let id else { return }

        let data = Data(id.uuidString.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func deleteLinkedPatientId() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
