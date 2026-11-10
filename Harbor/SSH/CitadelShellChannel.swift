import Foundation
import Citadel
import NIOCore
import NIOSSH

/// An interactive PTY shell over Citadel. Server output is delivered on
/// `onData`; keystrokes go out via `send`.
///
/// Citadel exposes an interactive TTY via `SSHClient`. The exact entry point has
/// moved between releases (`withPTY` / `openTTY` / `executeCommandPair`), so this
/// wrapper isolates it: if the pinned Citadel version names it differently, this
/// is the only file to touch.
actor CitadelShellChannel: SSHShellChannel {
    nonisolated(unsafe) var onData: ((Data) -> Void)?
    nonisolated(unsafe) var onClose: (() -> Void)?

    private let tty: TTYStdinWriter
    private var readerTask: Task<Void, Never>?

    init(client: SSHClient, cols: Int, rows: Int) async throws {
        // Request a PTY and an interactive login shell.
        let settings = SSHChannelType.PTY.PTYSettings(
            term: "xterm-256color",
            columns: cols,
            rows: rows
        )
        let (stdinWriter, output) = try await client.openPTY(settings: settings)
        self.tty = stdinWriter

        // Pump server → UI.
        readerTask = Task { [weak self] in
            do {
                for try await chunk in output {
                    guard let self else { return }
                    let data: Data
                    switch chunk {
                    case .stdout(let buf), .stderr(let buf):
                        data = Data(buffer: buf)
                    }
                    await MainActor.run { self.onData?(data) }
                }
            } catch {
                // Stream ended or errored — treat as a close.
            }
            if let self { await MainActor.run { self.onClose?() } }
        }
    }

    func send(_ data: Data) async {
        var buf = ByteBufferAllocator().buffer(capacity: data.count)
        buf.writeBytes(data)
        try? await tty.write(buf)
    }

    func resize(cols: Int, rows: Int) async {
        try? await tty.changeSize(cols: cols, rows: rows)
    }

    func close() async {
        readerTask?.cancel()
        try? await tty.close()
        await MainActor.run { onClose?() }
    }
}
