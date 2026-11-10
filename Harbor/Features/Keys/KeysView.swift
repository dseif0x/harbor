import SwiftUI

struct KeysView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: SSHKey?
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if store.keys.isEmpty {
                    EmptyState(icon: "key.fill", title: "No keys",
                               message: "Import an SSH private key to authenticate without a password.")
                } else {
                    List {
                        ForEach(store.keys) { key in
                            Button { editing = key } label: { row(key) }
                                .swipeActions {
                                    Button(role: .destructive) { store.delete(key) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Keys")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) { KeyEditView(key: SSHKey()) }
            .sheet(item: $editing) { KeyEditView(key: $0) }
        }
    }

    private func row(_ key: SSHKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .foregroundStyle(Theme.accentGradient)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(key.name.isEmpty ? "Unnamed key" : key.name).fontWeight(.medium).foregroundStyle(.primary)
                Text("\(key.type.rawValue)\(key.hasPassphrase ? " · passphrase" : "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }
}

struct KeyEditView: View {
    @State var key: SSHKey
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var privateKeyText = ""
    @State private var passphrase = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Personal laptop", text: $key.name)
                }
                Section {
                    Picker("Type", selection: $key.type) {
                        ForEach(SSHKey.KeyType.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                } header: {
                    Text("Type")
                } footer: {
                    if key.type == .rsa {
                        Label("RSA keys are signed with SHA-1 and are rejected by OpenSSH 8.8+ (most modern servers). Prefer Ed25519.",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section {
                    TextEditor(text: $privateKeyText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 140)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Private key")
                } footer: {
                    Text("Paste an OpenSSH private key (begins with -----BEGIN OPENSSH PRIVATE KEY-----). Stored only in the device Keychain.")
                }
                Section("Passphrase (optional)") {
                    SecureField("Key passphrase", text: $passphrase)
                }
                if !key.publicKey.isEmpty {
                    Section("Public key") {
                        Text(key.publicKey).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle(key.name.isEmpty ? "New Key" : key.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(privateKeyText.isEmpty && Keychain.string(for: key.keychainTag) == nil)
                }
            }
            .onAppear {
                privateKeyText = Keychain.string(for: key.keychainTag) ?? ""
                passphrase = Keychain.string(for: key.keychainTag + ".passphrase") ?? ""
            }
        }
    }

    private func save() {
        if !privateKeyText.isEmpty {
            try? Keychain.set(privateKeyText, for: key.keychainTag)
            if key.type == .ed25519,
               let pub = SSHKeyParser.publicKeyLine(fromPrivate: privateKeyText, passphrase: passphrase) {
                key.publicKey = pub
            }
        }
        key.hasPassphrase = !passphrase.isEmpty
        if passphrase.isEmpty { Keychain.remove(key.keychainTag + ".passphrase") }
        else { try? Keychain.set(passphrase, for: key.keychainTag + ".passphrase") }
        store.upsert(key)
        dismiss()
    }
}
