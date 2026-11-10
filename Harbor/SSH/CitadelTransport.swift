import Foundation
import Citadel
import NIOCore
import NIOSSH
import NIOConcurrencyHelpers
import Crypto

/// `SSHTransport` backed by Citadel (pure-Swift SSH over SwiftNIO SSH).
///
/// This is the one place that touches Citadel's API. The rest of Harbor speaks
/// only `SSHTransport`/`SFTPClient`, so replacing this with a libssh2 or Mosh
/// backend is a local change.
actor CitadelTransport: SSHTransport {
    private var client: SSHClient?
    private var shellChannels: [CitadelShellChannel] = []

    nonisolated var isConnected: Bool { _connected.withLockedValue { $0 } }
    private let _connected = NIOLockedValueBox(false)

    func connect(
        _ creds: SSHCredentials,
        verify: @escaping @Sendable (_ keyType: String, _ fingerprintSHA256: String) async -> Bool
    ) async throws {
        let auth = try Self.authentication(for: creds)

        // Trust-on-first-use: Citadel calls our delegate with the server's host
        // key, which we fingerprint and hand to `verify` to pin or reject.
        let validator = SSHHostKeyValidator.custom(HostKeyDelegate(verify: verify))

        let client = try await SSHClient.connect(
            host: creds.hostname,
            port: creds.port,
            authenticationMethod: auth,
            hostKeyValidator: validator,
            reconnect: .never
        )
        self.client = client
        _connected.withLockedValue { $0 = true }
    }

    private static func authentication(for creds: SSHCredentials) throws -> SSHAuthenticationMethod {
        if let key = creds.privateKey, !key.isEmpty {
            if let parsed = try? SSHKeyParser.privateKey(from: key, passphrase: creds.passphrase) {
                return parsed.authentication(username: creds.username)
            }
            if creds.password == nil { throw SSHError.authFailed }
        }
        if let pw = creds.password {
            return .passwordBased(username: creds.username, password: pw)
        }
        throw SSHError.authFailed
    }

    func openShell(cols: Int, rows: Int) async throws -> SSHShellChannel {
        guard let client else { throw SSHError.notConnected }
        let channel = CitadelShellChannel(client: client, cols: cols, rows: rows)
        shellChannels.append(channel)
        return channel
    }

    func run(_ command: String) async throws -> String {
        guard let client else { throw SSHError.notConnected }
        let buffer = try await client.executeCommand(command)
        return String(buffer: buffer)
    }

    func openSFTP() async throws -> SFTPClient {
        guard let client else { throw SSHError.notConnected }
        let sftp = try await client.openSFTP()
        return CitadelSFTP(sftp: sftp)
    }

    func resize(cols: Int, rows: Int) async {
        for ch in shellChannels { await ch.resize(cols: cols, rows: rows) }
    }

    func disconnect() async {
        for ch in shellChannels { await ch.close() }
        shellChannels.removeAll()
        try? await client?.close()
        client = nil
        _connected.withLockedValue { $0 = false }
    }
}

/// Bridges Citadel's host-key callback to our async `verify` closure.
private final class HostKeyDelegate: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    let verify: @Sendable (String, String) async -> Bool
    init(verify: @escaping @Sendable (String, String) async -> Bool) { self.verify = verify }

    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        let (type, fingerprint) = SSHKeyParser.fingerprint(of: hostKey)
        Task {
            if await verify(type, fingerprint) {
                validationCompletePromise.succeed(())
            } else {
                validationCompletePromise.fail(SSHError.hostKeyRejected)
            }
        }
    }
}
