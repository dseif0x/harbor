import SwiftUI

/// The live terminal for one session, with a status header, a quick key bar,
/// snippets, and access to SFTP and port forwarding.
struct SessionView: View {
    let session: SSHSession
    @Environment(AppStore.self) private var store
    @Environment(SessionManager.self) private var sessions

    @State private var showSFTP = false
    @State private var showSnippets = false
    @State private var showLog = false
    @State private var fontSize: CGFloat = 13

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TerminalScreen(session: session, fontSize: fontSize)
                    .ignoresSafeArea(.container, edges: .bottom)
                if case .failed(let msg) = session.status {
                    failureOverlay(msg)
                }
            }
            keyBar
        }
        .navigationTitle(session.host.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showLog = true } label: { StatusPill(status: session.status) }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button { fontSize = min(22, fontSize + 1) } label: { Label("Larger text", systemImage: "textformat.size.larger") }
                    Button { fontSize = max(9, fontSize - 1) } label: { Label("Smaller text", systemImage: "textformat.size.smaller") }
                    Divider()
                    Button { showSnippets = true } label: { Label("Snippets", systemImage: "chevron.left.forwardslash.chevron.right") }
                    Button { showSFTP = true } label: { Label("Files (SFTP)", systemImage: "folder") }
                    Button { showLog = true } label: { Label("Connection log", systemImage: "doc.text.magnifyingglass") }
                    Divider()
                    Button(role: .destructive) { sessions.close(session) } label: { Label("Disconnect", systemImage: "xmark.circle") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showSFTP) {
            NavigationStack { SFTPBrowserView(session: session) }
        }
        .sheet(isPresented: $showSnippets) {
            SnippetPickerView { snippet in
                session.runSnippet(snippet)
                showSnippets = false
            }
        }
        .sheet(isPresented: $showLog) {
            ConnectionLogView(session: session)
        }
    }

    private func failureOverlay(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40)).foregroundStyle(.orange)
            Text("Couldn't connect").font(.headline)
            Text(msg)
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            HStack {
                Button { showLog = true } label: { Label("View log", systemImage: "doc.text.magnifyingglass") }
                    .buttonStyle(.bordered)
                Button { Task { await session.connect() } } label: { Label("Retry", systemImage: "arrow.clockwise") }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding()
    }

    // A row of keys a software keyboard lacks but a terminal needs.
    private var keyBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                key("esc") { send("\u{1b}") }
                key("tab") { send("\t") }
                key("ctrl", toggle: $ctrlActive)
                key("/") { send("/") }
                key("-") { send("-") }
                key("|") { send("|") }
                key("↑") { send("\u{1b}[A") }
                key("↓") { send("\u{1b}[B") }
                key("←") { send("\u{1b}[D") }
                key("→") { send("\u{1b}[C") }
                key("^C") { send("\u{03}") }
                key("^D") { send("\u{04}") }
                key("^Z") { send("\u{1a}") }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
    }

    @State private var ctrlActive = false

    private func key(_ label: String, toggle: Binding<Bool>? = nil, _ action: (() -> Void)? = nil) -> some View {
        Button {
            if let toggle { toggle.wrappedValue.toggle() } else { action?() }
        } label: {
            Text(label)
                .font(.system(.footnote, design: .monospaced))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background((toggle?.wrappedValue ?? false) ? Theme.accent.opacity(0.4) : Color.primary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func send(_ s: String) {
        var text = s
        if ctrlActive, let scalar = s.unicodeScalars.first, scalar.value >= 0x60 {
            // Translate a following letter into its control code.
            text = String(UnicodeScalar(scalar.value & 0x1f) ?? scalar)
            ctrlActive = false
        }
        session.sendToShell(Data(text.utf8))
    }
}
