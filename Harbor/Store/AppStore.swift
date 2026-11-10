import Foundation
import Observation

/// The single source of truth for saved hosts, keys, snippets and known hosts.
/// Metadata persists as JSON in Application Support; secrets go to the Keychain.
@MainActor
@Observable
final class AppStore {
    var hosts: [Host] = []
    var keys: [SSHKey] = []
    var snippets: [Snippet] = []
    var knownHosts: [KnownHost] = []

    private let fileURL: URL

    init(filename: String = "harbor.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(filename)
        load()
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var hosts: [Host] = []
        var keys: [SSHKey] = []
        var snippets: [Snippet] = []
        var knownHosts: [KnownHost] = []
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        hosts = snap.hosts
        keys = snap.keys
        snippets = snap.snippets
        knownHosts = snap.knownHosts
    }

    func save() {
        let snap = Snapshot(hosts: hosts, keys: keys, snippets: snippets, knownHosts: knownHosts)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Hosts

    func upsert(_ host: Host) {
        if let i = hosts.firstIndex(where: { $0.id == host.id }) { hosts[i] = host }
        else { hosts.append(host) }
        save()
    }

    func delete(_ host: Host) {
        hosts.removeAll { $0.id == host.id }
        Keychain.remove("host.password.\(host.id.uuidString)")
        save()
    }

    func markConnected(_ host: Host) {
        guard let i = hosts.firstIndex(where: { $0.id == host.id }) else { return }
        hosts[i].lastConnected = Date()
        save()
    }

    var recentHosts: [Host] {
        hosts.filter { $0.lastConnected != nil }
            .sorted { ($0.lastConnected ?? .distantPast) > ($1.lastConnected ?? .distantPast) }
    }

    var groupedHosts: [(group: String, hosts: [Host])] {
        let groups = Dictionary(grouping: hosts) { $0.group.isEmpty ? "Ungrouped" : $0.group }
        return groups.map { ($0.key, $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.group < $1.group }
    }

    // MARK: Keys

    func upsert(_ key: SSHKey) {
        if let i = keys.firstIndex(where: { $0.id == key.id }) { keys[i] = key }
        else { keys.append(key) }
        save()
    }

    func delete(_ key: SSHKey) {
        keys.removeAll { $0.id == key.id }
        Keychain.remove(key.keychainTag)
        Keychain.remove(key.keychainTag + ".passphrase")
        save()
    }

    func key(_ id: UUID?) -> SSHKey? {
        guard let id else { return nil }
        return keys.first { $0.id == id }
    }

    // MARK: Snippets

    func upsert(_ snippet: Snippet) {
        if let i = snippets.firstIndex(where: { $0.id == snippet.id }) { snippets[i] = snippet }
        else { snippets.append(snippet) }
        save()
    }

    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        save()
    }

    // MARK: Known hosts (trust-on-first-use)

    func knownHost(for hostname: String, port: Int) -> KnownHost? {
        knownHosts.first { $0.matches(hostname: hostname, port: port) }
    }

    func trust(_ host: KnownHost) {
        knownHosts.removeAll { $0.matches(hostname: host.hostname, port: host.port) }
        knownHosts.append(host)
        save()
    }
}
