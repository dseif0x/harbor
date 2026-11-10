import SwiftUI

struct HostsListView: View {
    @Environment(AppStore.self) private var store
    @Environment(SessionManager.self) private var sessions
    @Environment(Navigator.self) private var nav

    @State private var search = ""
    @State private var editing: Host?
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if store.hosts.isEmpty {
                    EmptyState(icon: "server.rack", title: "No hosts yet",
                               message: "Add your first server to connect over SSH and browse files over SFTP.")
                } else {
                    content
                }
            }
            .navigationTitle("Harbor")
            .searchable(text: $search, prompt: "Search hosts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) { HostEditView(host: Host()) { store.upsert($0) } }
            .sheet(item: $editing) { host in HostEditView(host: host) { store.upsert($0) } }
        }
    }

    private var filtered: [Host] {
        guard !search.isEmpty else { return store.hosts }
        return store.hosts.filter {
            $0.displayName.localizedCaseInsensitiveContains(search)
            || $0.hostname.localizedCaseInsensitiveContains(search)
            || $0.group.localizedCaseInsensitiveContains(search)
        }
    }

    private var grouped: [(String, [Host])] {
        let groups = Dictionary(grouping: filtered) { $0.group.isEmpty ? "Hosts" : $0.group }
        return groups.map { ($0.key, $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.0 < $1.0 }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !store.recentHosts.isEmpty && search.isEmpty {
                    section("Recent") {
                        ForEach(store.recentHosts.prefix(3)) { card($0) }
                    }
                }
                ForEach(grouped, id: \.0) { group, hosts in
                    section(group) { ForEach(hosts) { card($0) } }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            content()
        }
    }

    private func isConnected(_ host: Host) -> Bool {
        sessions.sessions.contains { $0.host.id == host.id && $0.status.isActive }
    }

    private func card(_ host: Host) -> some View {
        Button {
            sessions.open(host)
            nav.tab = .terminal
        } label: {
            HStack(spacing: 14) {
                HostAvatar(host: host, size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(host.displayName).font(.body.weight(.semibold)).foregroundStyle(.primary)
                        if isConnected(host) {
                            Circle().fill(.green).frame(width: 7, height: 7)
                        }
                    }
                    Text(host.subtitle).font(.subheadline).foregroundStyle(.secondary)
                    if let last = host.lastConnected {
                        Label(last.formatted(.relative(presentation: .named)), systemImage: "clock")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Menu {
                    Button { sessions.open(host); nav.tab = .terminal } label: { Label("Connect", systemImage: "bolt.horizontal") }
                    Button { editing = host } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { store.delete(host) } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
            }
            .padding(14)
            .card()
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { editing = host } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { store.delete(host) } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
