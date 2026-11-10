import SwiftUI

struct RootView: View {
    @Environment(SessionManager.self) private var sessions

    var body: some View {
        TabView {
            HostsListView()
                .tabItem { Label("Hosts", systemImage: "server.rack") }

            SessionsTab()
                .tabItem { Label("Terminal", systemImage: "terminal") }
                .badge(sessions.sessions.count)

            KeysView()
                .tabItem { Label("Keys", systemImage: "key.fill") }

            SnippetsView()
                .tabItem { Label("Snippets", systemImage: "chevron.left.forwardslash.chevron.right") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

/// The Terminal tab: a switcher across open sessions, or an empty state.
struct SessionsTab: View {
    @Environment(SessionManager.self) private var sessions

    var body: some View {
        NavigationStack {
            Group {
                if sessions.sessions.isEmpty {
                    EmptyState(
                        icon: "terminal",
                        title: "No open sessions",
                        message: "Connect to a host to start a terminal. Open sessions stay here so you can switch between them."
                    )
                } else {
                    List {
                        ForEach(sessions.sessions) { session in
                            NavigationLink {
                                SessionView(session: session)
                            } label: {
                                sessionRow(session)
                            }
                        }
                        .onDelete { idx in
                            idx.map { sessions.sessions[$0] }.forEach(sessions.close)
                        }
                    }
                }
            }
            .navigationTitle("Terminal")
        }
    }

    private func sessionRow(_ session: SSHSession) -> some View {
        HStack(spacing: 12) {
            HostAvatar(host: session.host, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.host.displayName).fontWeight(.medium)
                Text(session.host.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Circle().fill(session.status.tint).frame(width: 9, height: 9)
        }
    }
}
