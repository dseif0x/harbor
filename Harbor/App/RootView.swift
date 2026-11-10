import SwiftUI

struct RootView: View {
    @Environment(SessionManager.self) private var sessions
    @Environment(Navigator.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.tab) {
            HostsListView()
                .tabItem { Label("Hosts", systemImage: "server.rack") }
                .tag(Navigator.Tab.hosts)

            TerminalTab()
                .tabItem { Label("Terminal", systemImage: "terminal") }
                .badge(sessions.activeCount)
                .tag(Navigator.Tab.terminal)

            KeysView()
                .tabItem { Label("Keys", systemImage: "key.fill") }
                .tag(Navigator.Tab.keys)

            SnippetsView()
                .tabItem { Label("Snippets", systemImage: "chevron.left.forwardslash.chevron.right") }
                .tag(Navigator.Tab.snippets)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Navigator.Tab.settings)
        }
    }
}
