import SwiftUI

/// One session's terminal + key bar, embedded in the Terminal tab. Several of
/// these are kept alive at once (one per open session) and only the active one
/// is shown, so switching sessions preserves scrollback.
struct SessionPane: View {
    let session: SSHSession
    let active: Bool
    var fontSize: CGFloat = 13

    @State private var terminal = TerminalController()
    @State private var showLog = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TerminalScreen(session: session, controller: terminal, fontSize: fontSize)
                    .ignoresSafeArea(.container, edges: .bottom)
                if case .failed(let msg) = session.status {
                    FailureOverlay(message: msg,
                                   onRetry: { Task { await session.connect() } },
                                   onLog: { showLog = true })
                }
            }
            KeyBar(session: session, terminal: terminal)
        }
        .sheet(isPresented: $showLog) { ConnectionLogView(session: session) }
    }
}

/// The accessory key row with a pinned keyboard-dismiss button.
struct KeyBar: View {
    let session: SSHSession
    let terminal: TerminalController
    @State private var ctrlActive = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    key("esc") { send("\u{1b}") }
                    key("tab") { send("\t") }
                    key("ctrl", toggle: $ctrlActive)
                    group {
                        key("~") { send("~") }
                        key("/") { send("/") }
                        key("-") { send("-") }
                        key("|") { send("|") }
                    }
                    group {
                        key(systemImage: "arrow.up") { send("\u{1b}[A") }
                        key(systemImage: "arrow.down") { send("\u{1b}[B") }
                        key(systemImage: "arrow.left") { send("\u{1b}[D") }
                        key(systemImage: "arrow.right") { send("\u{1b}[C") }
                    }
                    key("^C") { send("\u{03}") }
                    key("^D") { send("\u{04}") }
                    key("^Z") { send("\u{1a}") }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            Divider().frame(height: 24)
            Button { terminal.dismissKeyboard() } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 46, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 7) { content() }
    }

    private func key(_ label: String, toggle: Binding<Bool>? = nil, _ action: (() -> Void)? = nil) -> some View {
        Button {
            if let toggle { toggle.wrappedValue.toggle() } else { action?() }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .frame(minWidth: 34, minHeight: 32)
                .background((toggle?.wrappedValue ?? false) ? AnyShapeStyle(Theme.accent.opacity(0.45)) : AnyShapeStyle(Color(.tertiarySystemFill)),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func key(systemImage: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 34, minHeight: 32)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func send(_ s: String) {
        var text = s
        if ctrlActive, let scalar = s.unicodeScalars.first, scalar.value >= 0x60 {
            text = String(UnicodeScalar(scalar.value & 0x1f) ?? scalar)
            ctrlActive = false
        }
        session.sendToShell(Data(text.utf8))
    }
}

/// Shown over the terminal when a connection fails.
struct FailureOverlay: View {
    let message: String
    let onRetry: () -> Void
    let onLog: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38)).foregroundStyle(.orange)
            Text("Couldn't connect").font(.headline)
            Text(message)
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).textSelection(.enabled)
            HStack(spacing: 10) {
                Button(action: onLog) { Label("View log", systemImage: "doc.text.magnifyingglass") }
                    .buttonStyle(.bordered)
                Button(action: onRetry) { Label("Retry", systemImage: "arrow.clockwise") }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding()
    }
}
