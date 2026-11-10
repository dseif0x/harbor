import SwiftUI

/// The Terminal tab: a chip bar across open sessions (like Termius), the active
/// session's terminal below, and per-session actions in the nav bar.
struct TerminalTab: View {
    @Environment(SessionManager.self) private var sessions
    @Environment(AppStore.self) private var store

    @State private var showPicker = false
    @State private var showSFTP = false
    @State private var showSnippets = false
    @State private var showLog = false
    @AppStorage("terminalFontSize") private var fontSize: Double = 13

    private var active: SSHSession? {
        guard let a = sessions.active, sessions.sessions.contains(where: { $0.id == a.id }) else {
            return sessions.sessions.last
        }
        return a
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if sessions.sessions.isEmpty {
                    EmptyState(icon: "terminal", title: "No open sessions",
                               message: "Connect to a host to open a terminal. Your open sessions appear as tabs up top.")
                    VStack { Spacer()
                        PrimaryButton(title: "Open a host", systemImage: "bolt.horizontal") { showPicker = true }
                            .frame(maxWidth: 260).padding(.bottom, 40)
                    }
                } else {
                    ForEach(sessions.sessions) { s in
                        SessionPane(session: s, active: s.id == active?.id, fontSize: CGFloat(fontSize))
                            .opacity(s.id == active?.id ? 1 : 0)
                            .allowsHitTesting(s.id == active?.id)
                    }
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                // Only show the switcher when there's more than one session, so a
                // single session doesn't stack two bars.
                if sessions.sessions.count > 1 { sessionBar }
            }
            .navigationTitle(active?.host.displayName ?? "Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showPicker) {
                HostPickerView { host in sessions.open(host); showPicker = false }
            }
            .sheet(isPresented: $showSFTP) {
                if let active { NavigationStack { SFTPBrowserView(session: active) } }
            }
            .sheet(isPresented: $showSnippets) {
                SnippetPickerView { snippet in active?.runSnippet(snippet); showSnippets = false }
            }
            .sheet(isPresented: $showLog) {
                if let active { ConnectionLogView(session: active) }
            }
        }
    }

    // MARK: Session chip bar

    private var sessionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(sessions.sessions) { s in
                        sessionChip(s)
                    }
                    Button { showPicker = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 38, height: 38)
                            .harborGlass(RoundedRectangle(cornerRadius: 12, style: .continuous), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// Disambiguates duplicate sessions to the same host (e.g. "brute 2").
    private func chipLabel(_ s: SSHSession) -> String {
        let same = sessions.sessions.filter { $0.host.id == s.host.id }
        guard same.count > 1, let idx = same.firstIndex(where: { $0.id == s.id }) else {
            return s.host.displayName
        }
        return "\(s.host.displayName) \(idx + 1)"
    }

    private func sessionChip(_ s: SSHSession) -> some View {
        let isActive = s.id == active?.id
        return HStack(spacing: 8) {
            Circle().fill(s.status.tint).frame(width: 7, height: 7)
            Text(chipLabel(s)).font(.subheadline.weight(.medium)).lineLimit(1)
            Button { sessions.close(s) } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 9)
        .harborGlass(RoundedRectangle(cornerRadius: 12, style: .continuous),
                     tint: isActive ? s.host.color.color : nil, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isActive ? s.host.color.color.opacity(0.6) : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { sessions.active = s }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        if let active {
            ToolbarItem(placement: .topBarLeading) {
                Button { showLog = true } label: { StatusPill(status: active.status) }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button { fontSize = min(22, fontSize + 1) } label: { Label("Larger text", systemImage: "textformat.size.larger") }
                    Button { fontSize = max(9, fontSize - 1) } label: { Label("Smaller text", systemImage: "textformat.size.smaller") }
                    Divider()
                    Button { showPicker = true } label: { Label("New session", systemImage: "plus") }
                    if let active { Button { sessions.open(active.host) } label: { Label("Duplicate session", systemImage: "plus.square.on.square") } }
                    Divider()
                    Button { showSnippets = true } label: { Label("Snippets", systemImage: "chevron.left.forwardslash.chevron.right") }
                    Button { showSFTP = true } label: { Label("Files (SFTP)", systemImage: "folder") }
                    Button { showLog = true } label: { Label("Connection log", systemImage: "doc.text.magnifyingglass") }
                    Divider()
                    Button(role: .destructive) { sessions.close(active) } label: { Label("Disconnect", systemImage: "xmark.circle") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }
}

/// A compact host list for opening a new session from the Terminal tab.
struct HostPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onPick: (Host) -> Void

    var body: some View {
        NavigationStack {
            List(store.hosts) { host in
                Button { onPick(host) } label: {
                    HStack(spacing: 12) {
                        HostAvatar(host: host, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.displayName).fontWeight(.medium).foregroundStyle(.primary)
                            Text(host.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay { if store.hosts.isEmpty {
                EmptyState(icon: "server.rack", title: "No hosts", message: "Add a host in the Hosts tab first.")
            } }
            .navigationTitle("Open host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
