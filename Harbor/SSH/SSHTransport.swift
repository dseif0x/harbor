import Foundation

/// The credentials needed to open a connection, assembled from a `Host` plus
/// secrets pulled from the Keychain at connect time (never stored on `Host`).
struct SSHCredentials {
    var hostname: String
    var port: Int
    var username: String
    var password: String?
    var privateKey: String?       // PEM / OpenSSH private key text
    var passphrase: String?
}

/// Result of verifying a server's host key against our known-hosts store.
enum HostKeyDecision {
    case trusted
    case unknown(KnownHost)   // first time we've seen this host
    case changed(KnownHost)   // key differs from what we pinned — possible MITM
}

/// A backend-agnostic SSH transport. Harbor ships a Citadel implementation,
/// but the terminal, SFTP and forwarding code only depend on this protocol so
/// the backend (libssh2, Mosh, …) can be swapped without touching the UI.
protocol SSHTransport: AnyObject {
    var isConnected: Bool { get }

    /// Opens the transport. `verify` is called with the server's fingerprint so
    /// the caller can apply trust-on-first-use before the session is used.
    func connect(
        _ credentials: SSHCredentials,
        verify: @Sendable (_ keyType: String, _ fingerprintSHA256: String) async -> Bool
    ) async throws

    /// Opens an interactive shell with a PTY of the given size.
    func openShell(cols: Int, rows: Int) async throws -> SSHShellChannel

    /// Runs a single command and returns its combined output.
    func run(_ command: String) async throws -> String

    /// Opens an SFTP channel over the same connection.
    func openSFTP() async throws -> SFTPClient

    func resize(cols: Int, rows: Int) async

    func disconnect() async
}

/// A live interactive shell. Bytes from the server arrive on `onData`; send
/// user keystrokes with `send`.
protocol SSHShellChannel: AnyObject {
    var onData: ((Data) -> Void)? { get set }
    var onClose: (() -> Void)? { get set }
    func send(_ data: Data) async
    func resize(cols: Int, rows: Int) async
    func close() async
}

enum SSHError: LocalizedError {
    case notConnected
    case authFailed
    case hostKeyRejected
    case channelFailed(String)
    case transfer(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected."
        case .authFailed: return "Authentication failed. Check your credentials."
        case .hostKeyRejected: return "The server's host key was rejected."
        case .channelFailed(let m): return m
        case .transfer(let m): return m
        }
    }
}
