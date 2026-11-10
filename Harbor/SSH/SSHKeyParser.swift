import Foundation
import Citadel
import NIOCore
import NIOSSH
import Crypto

/// Parses OpenSSH private keys into Citadel authentication methods and computes
/// the SHA-256 host-key fingerprint OpenSSH prints (`SHA256:…`).
///
/// Key parsing is backend-specific: this targets Citadel's `OpenSSH` key types.
/// Ed25519 and RSA are the common cases; add ECDSA as needed. This is a prime
/// candidate to verify on the first macOS build.
enum SSHKeyParser {

    struct ParsedKey {
        private let make: (String) -> SSHAuthenticationMethod
        init(_ make: @escaping (String) -> SSHAuthenticationMethod) { self.make = make }
        func authentication(username: String) -> SSHAuthenticationMethod { make(username) }
    }

    /// Derives the OpenSSH public-key line (`ssh-ed25519 AAAA… comment`) from an
    /// imported Ed25519 private key, so the user can copy it to a server.
    static func publicKeyLine(fromPrivate text: String, passphrase: String?, comment: String = "harbor") -> String? {
        let pem = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let dk = passphrase.flatMap { $0.isEmpty ? nil : Data($0.utf8) }
        if let key = try? Curve25519.Signing.PrivateKey(sshEd25519: pem, decryptionKey: dk) {
            return key.makeSSHRepresentation(comment: comment)
        }
        return nil
    }

    static func privateKey(from text: String, passphrase: String?) throws -> ParsedKey {
        let pem = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ed25519
        if let key = try? Curve25519.Signing.PrivateKey(sshEd25519: pem, decryptionKey: passphrase.map { Data($0.utf8) }) {
            return ParsedKey { .ed25519(username: $0, privateKey: key) }
        }
        // RSA (Citadel's Insecure.RSA for broad server compatibility)
        if let key = try? Insecure.RSA.PrivateKey(sshRsa: pem, decryptionKey: passphrase.map { Data($0.utf8) }) {
            return ParsedKey { .rsa(username: $0, privateKey: key) }
        }
        throw SSHError.channelFailed("Unsupported or malformed private key.")
    }

    /// Returns (keyType, "SHA256:<base64 no padding>") for a server host key.
    static func fingerprint(of key: NIOSSHPublicKey) -> (String, String) {
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        // NIOSSH serializes the public key in SSH wire format; we hash those
        // bytes exactly as OpenSSH does for its SHA256 fingerprint.
        let written = key.write(to: &buffer)
        let bytes = buffer.getBytes(at: 0, length: written) ?? []
        let digest = SHA256.hash(data: Data(bytes))
        let b64 = Data(digest).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let type = "\(key)".contains("25519") ? "ssh-ed25519" : "ssh-key"
        return (type, "SHA256:\(b64)")
    }
}
