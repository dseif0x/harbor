import Foundation

/// An SSH identity. The private key material is stored in the Keychain under
/// `keychainTag`; only metadata lives here so lists and exports stay safe.
struct SSHKey: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var type: KeyType = .ed25519
    /// Set when the private key is protected by a passphrase (kept in Keychain).
    var hasPassphrase: Bool = false
    /// The public key line, safe to display and copy.
    var publicKey: String = ""
    var fingerprint: String = ""
    var createdAt: Date = Date()

    var keychainTag: String { "id.seifert.harbor.key.\(id.uuidString)" }

    enum KeyType: String, Codable, CaseIterable, Identifiable {
        case ed25519 = "Ed25519"
        case ecdsa = "ECDSA"
        case rsa = "RSA"
        var id: String { rawValue }
    }
}
