import Foundation
import Citadel
import NIOCore
import NIOSSH

/// An interactive PTY shell over Citadel. Server output is delivered on
/// `onData`; keystrokes go out via `send`.
///
/// Citadel exposes interactive terminals through the closure-based `withPTY`.
/// We run it in a long-lived task: the closure stays suspended on the inbound
/// stream (keeping the channel open) and we capture the stdin writer so `send`
/// and `resize` can reach it from outside.
actor CitadelShellChannel: SSHShellChannel {
    nonisolated(unsafe) var onData: ((Data) -> Void)?
    nonisolated(unsafe) var onClose: (() -> Void)?

    private var writer: TTYStdinWriter?
    private var task: Task<Void, Never>?

    init(client: SSHClient, cols: Int, rows: Int) {
        let request = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )
        task = Task { [weak self] in
            do {
                try await client.withPTY(request) { inbound, outbound in
                    await self?.setWriter(outbound)
                    for try await chunk in inbound {
                        let buffer: ByteBuffer
                        switch chunk {
                        case .stdout(let b): buffer = b
                        case .stderr(let b): buffer = b
                        }
                        let data = Data(buffer.readableBytesView)
                        if let cb = self?.onData {
                            await MainActor.run { cb(data) }
                        }
                    }
                }
            } catch {
                // Stream ended or errored — fall through to the close callback.
            }
            if let cb = self?.onClose {
                await MainActor.run { cb() }
            }
        }
    }

    private func setWriter(_ w: TTYStdinWriter) { writer = w }

    func send(_ data: Data) async {
        guard let writer else { return }
        var buf = ByteBufferAllocator().buffer(capacity: data.count)
        buf.writeBytes(data)
        try? await writer.write(buf)
    }

    func resize(cols: Int, rows: Int) async {
        try? await writer?.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0)
    }

    func close() async {
        task?.cancel()
        task = nil
    }
}
