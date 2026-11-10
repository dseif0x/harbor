import Foundation
import SwiftUI
import Observation

/// Owns one live connection to a host: the transport, the interactive shell,
/// SFTP, transfers, keepalive and automatic reconnection. The UI observes this.
///
/// Resilience strategy (within what iOS allows):
///   • SSH keepalive probes catch half-open connections quickly.
///   • On an unexpected drop we reconnect with exponential backoff and reopen
///     the shell, so brief network changes and device sleep recover on their own.
///   • A Live Activity mirrors the status and buys extra background runtime.
@MainActor
@Observable
final class SSHSession: Identifiable {
    let id = UUID()
    let host: Host
    private let store: AppStore

    private(set) var status: ConnectionStatus = .idle
    private(set) var shell: SSHShellChannel?
    private(set) var transfers: [Transfer] = []

    /// Terminal bytes received from the server; the terminal view consumes this.
    var onShellData: ((Data) -> Void)?

    private var transport: SSHTransport?
    private var keepaliveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var intentionalDisconnect = false
    private var termCols = 80
    private var termRows = 24

    private let keepaliveInterval: UInt64 = 25_000_000_000 // 25s
    private let maxReconnectAttempts = 8

    init(host: Host, store: AppStore) {
        self.host = host
        self.store = store
    }

    // MARK: Connect

    func connect() async {
        intentionalDisconnect = false
        status = .connecting
        let transport = CitadelTransport()
        self.transport = transport

        guard let creds = makeCredentials() else {
            status = .failed("Missing credentials for this host.")
            return
        }

        do {
            try await transport.connect(creds, verify: { [weak self] type, fp in
                await self?.verifyHostKey(type: type, fingerprint: fp) ?? false
            })
            status = .authenticating
            let shell = try await transport.openShell(cols: termCols, rows: termRows)
            shell.onData = { [weak self] data in self?.onShellData?(data) }
            shell.onClose = { [weak self] in self?.handleDrop(reason: "Shell closed") }
            self.shell = shell
            status = .connected
            store.markConnected(host)
            LiveActivityController.shared.start(host: host.displayName, status: status)
            startKeepalive()
            await runOnConnectSnippet()
        } catch let e as SSHError {
            status = .failed(e.errorDescription ?? "Connection failed.")
            LiveActivityController.shared.end()
        } catch is CancellationError {
            status = .disconnected(reason: nil)
        } catch {
            status = .failed(error.localizedDescription)
            LiveActivityController.shared.end()
        }
    }

    private func makeCredentials() -> SSHCredentials? {
        var creds = SSHCredentials(hostname: host.hostname, port: host.port, username: host.username)
        switch host.auth {
        case .password:
            creds.password = Keychain.string(for: "host.password.\(host.id.uuidString)")
        case .key, .agentThenPassword:
            if let key = store.key(host.keyID) {
                creds.privateKey = Keychain.string(for: key.keychainTag)
                creds.passphrase = Keychain.string(for: key.keychainTag + ".passphrase")
            }
            if host.auth == .agentThenPassword {
                creds.password = Keychain.string(for: "host.password.\(host.id.uuidString)")
            }
        }
        return creds
    }

    // MARK: Host-key trust (TOFU)

    private func verifyHostKey(type: String, fingerprint: String) async -> Bool {
        if let known = store.knownHost(for: host.hostname, port: host.port) {
            return known.fingerprintSHA256 == fingerprint   // reject silently on change; UI can surface later
        }
        store.trust(KnownHost(hostname: host.hostname, port: host.port,
                              keyType: type, fingerprintSHA256: fingerprint))
        return true
    }

    // MARK: Keepalive & reconnect

    private func startKeepalive() {
        keepaliveTask?.cancel()
        keepaliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.keepaliveInterval ?? 25_000_000_000)
                guard let self, let transport = self.transport else { return }
                if !transport.isConnected {
                    self.handleDrop(reason: "Connection lost")
                    return
                }
            }
        }
    }

    private func handleDrop(reason: String) {
        guard !intentionalDisconnect, status.isActive || status == .connected else { return }
        keepaliveTask?.cancel()
        shell = nil
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in await self?.reconnectLoop(reason: reason) }
    }

    private func reconnectLoop(reason: String) async {
        for attempt in 1...maxReconnectAttempts {
            if intentionalDisconnect { return }
            status = .reconnecting(attempt: attempt)
            LiveActivityController.shared.update(status: status)
            let backoff = min(30, pow(2, Double(attempt - 1)))
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            await transport?.disconnect()
            await connect()
            if case .connected = status { return }
        }
        status = .disconnected(reason: reason)
        LiveActivityController.shared.end()
    }

    // MARK: Shell I/O

    func sendToShell(_ data: Data) {
        Task { await shell?.send(data) }
    }

    func resizeTerminal(cols: Int, rows: Int) {
        termCols = cols; termRows = rows
        Task { await transport?.resize(cols: cols, rows: rows) }
    }

    func runSnippet(_ snippet: Snippet) {
        let bytes = Data((snippet.command + "\n").utf8)
        sendToShell(bytes)
    }

    private func runOnConnectSnippet() async {
        guard let id = host.onConnectSnippetID,
              let snippet = store.snippets.first(where: { $0.id == id }) else { return }
        try? await Task.sleep(nanoseconds: 400_000_000)
        runSnippet(snippet)
    }

    // MARK: SFTP / transfers

    func openSFTP() async throws -> SFTPClient {
        guard let transport else { throw SSHError.notConnected }
        return try await transport.openSFTP()
    }

    /// Starts a download, tracking progress in `transfers`.
    func download(entry: SFTPEntry, using sftp: SFTPClient, to localURL: URL) {
        let transfer = Transfer(name: entry.name, direction: .download, total: entry.size)
        transfers.insert(transfer, at: 0)
        Task {
            do {
                try await sftp.download(remotePath: entry.path, to: localURL) { bytes in
                    Task { @MainActor in transfer.transferred = bytes }
                }
                transfer.state = .done
                transfer.transferred = transfer.total
            } catch is CancellationError {
                transfer.state = .cancelled
            } catch {
                transfer.state = .failed(error.localizedDescription)
            }
        }
    }

    func upload(localURL: URL, name: String, size: Int64, to remoteDir: String, using sftp: SFTPClient) {
        let remote = remoteDir.hasSuffix("/") ? remoteDir + name : remoteDir + "/" + name
        let transfer = Transfer(name: name, direction: .upload, total: size)
        transfers.insert(transfer, at: 0)
        Task {
            do {
                try await sftp.upload(localURL: localURL, to: remote) { bytes in
                    Task { @MainActor in transfer.transferred = bytes }
                }
                transfer.state = .done
                transfer.transferred = transfer.total
            } catch {
                transfer.state = .failed(error.localizedDescription)
            }
        }
    }

    func clearFinishedTransfers() {
        transfers.removeAll { $0.state != .running }
    }

    // MARK: Disconnect

    func disconnect() async {
        intentionalDisconnect = true
        keepaliveTask?.cancel()
        reconnectTask?.cancel()
        await transport?.disconnect()
        transport = nil
        shell = nil
        status = .disconnected(reason: nil)
        LiveActivityController.shared.end()
    }
}
