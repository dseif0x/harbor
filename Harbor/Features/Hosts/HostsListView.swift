import SwiftUI

struct HostsListView: View {
    @Environment(AppStore.self) private var store
    @Environment(SessionManager.self) private var sessions

    @State private var search = ""
    @State private var editing: Host?
    @State private var showingNew = false
    @State private var navigateTo: SSHSession?

    var body: some View {
        NavigationStack {
            Group {
                if store.hosts.isEmpty {
                    EmptyState(
                        icon: "server.rack",
                        title: "No hosts yet",
                        message: "Add your first server to connect over SSH and browse files over SFTP."
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Harbor")
            .searchable(text: $search, prompt: "Search hosts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) {
                HostEditView(host: Host()) { store.upsert($0) }
            }
            .sheet(item: $editing) { host in
                HostEditView(host: host) { store.upsert($0) }
            }
            .navigationDestination(item: $navigateTo) { SessionView(session: $0) }
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

    private var list: some View {
        List {
            if !store.recentHosts.isEmpty && search.isEmpty {
                Section("Recent") {
                    ForEach(store.recentHosts.prefix(3)) { host in row(host) }
                }
            }
            ForEach(grouped, id: \.0) { group, hosts in
                Section(group) {
                    ForEach(hosts) { host in row(host) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var grouped: [(String, [Host])] {
        let base = search.isEmpty ? store.hosts : filtered
        let groups = Dictionary(grouping: base) { $0.group.isEmpty ? "Hosts" : $0.group }
        return groups.map { ($0.key, $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.0 < $1.0 }
    }

    private func row(_ host: Host) -> some View {
        Button {
            navigateTo = sessions.open(host)
        } label: {
            HStack(spacing: 12) {
                HostAvatar(host: host)
                VStack(alignment: .leading, spacing: 3) {
                    Text(host.displayName).fontWeight(.medium).foregroundStyle(.primary)
                    Text(host.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if sessions.sessions.contains(where: { $0.host.id == host.id }) {
                    Image(systemName: "bolt.horizontal.circle.fill").foregroundStyle(.green)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.delete(host) } label: { Label("Delete", systemImage: "trash") }
            Button { editing = host } label: { Label("Edit", systemImage: "pencil") }.tint(.indigo)
        }
    }
}
