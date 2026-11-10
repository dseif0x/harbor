import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("terminalFontSize") private var fontSize: Double = 13
    @AppStorage("keepaliveEnabled") private var keepalive = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Terminal") {
                    HStack {
                        Text("Font size")
                        Slider(value: $fontSize, in: 9...22, step: 1)
                        Text("\(Int(fontSize))").monospacedDigit().foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Keepalive & auto-reconnect", isOn: $keepalive)
                } header: {
                    Text("Connections")
                } footer: {
                    Text("Harbor sends keepalive probes and automatically reconnects dropped sessions. A Live Activity keeps a session visible while the app is in the background — iOS still limits how long a connection can run when the app is closed.")
                }

                Section("Known hosts") {
                    NavigationLink {
                        KnownHostsView()
                    } label: {
                        Label("\(store.knownHosts.count) trusted hosts", systemImage: "checkmark.shield")
                    }
                }

                Section {
                    LabeledContent("Hosts", value: "\(store.hosts.count)")
                    LabeledContent("Keys", value: "\(store.keys.count)")
                    LabeledContent("Snippets", value: "\(store.snippets.count)")
                } header: { Text("Library") }

                Section {
                    Link(destination: URL(string: "https://github.com/dseif0x/harbor")!) {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } footer: {
                    Text("Harbor \(appVersion) · open source, no accounts, no telemetry.")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }
}

struct KnownHostsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            ForEach(store.knownHosts) { host in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(host.hostname):\(host.port)").fontWeight(.medium)
                    Text(host.fingerprintSHA256).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            .onDelete { idx in
                idx.map { store.knownHosts[$0] }.forEach { h in
                    store.knownHosts.removeAll { $0.id == h.id }
                }
                store.save()
            }
        }
        .overlay { if store.knownHosts.isEmpty {
            EmptyState(icon: "checkmark.shield", title: "No trusted hosts", message: "Host keys you trust on first connect appear here.")
        } }
        .navigationTitle("Known Hosts")
    }
}
