import SwiftUI

struct HostEditView: View {
    @State var host: Host
    let onSave: (Host) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Label (optional)", text: $host.label)
                    TextField("Hostname or IP", text: $host.hostname)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL)
                    HStack {
                        TextField("Username", text: $host.username)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Divider()
                        TextField("Port", value: $host.port, format: .number)
                            .keyboardType(.numberPad).frame(width: 64)
                    }
                }

                Section("Authentication") {
                    Picker("Method", selection: $host.auth) {
                        ForEach(Host.AuthMethod.allCases) { Text($0.title).tag($0) }
                    }
                    if host.auth != .key {
                        SecureField("Password", text: $password)
                    }
                    if host.auth != .password {
                        Picker("Key", selection: $host.keyID) {
                            Text("None").tag(UUID?.none)
                            ForEach(store.keys) { key in
                                Text(key.name.isEmpty ? key.type.rawValue : key.name).tag(UUID?.some(key.id))
                            }
                        }
                    }
                }

                Section("Appearance") {
                    TextField("Group", text: $host.group)
                    colorPicker
                }

                Section("Port forwarding") {
                    NavigationLink {
                        PortForwardEditView(forwards: $host.forwards)
                    } label: {
                        LabeledContent("Forwards", value: host.forwards.isEmpty ? "None" : "\(host.forwards.count)")
                    }
                }

                Section("On connect") {
                    Picker("Run snippet", selection: $host.onConnectSnippetID) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.snippets) { s in
                            Text(s.name).tag(UUID?.some(s.id))
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $host.notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle(host.label.isEmpty ? "New Host" : host.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!host.isValid).fontWeight(.semibold)
                }
            }
            .onAppear {
                password = Keychain.string(for: "host.password.\(host.id.uuidString)") ?? ""
            }
        }
    }

    private var colorPicker: some View {
        HStack {
            Text("Color")
            Spacer()
            ForEach(HostColor.allCases) { c in
                Circle()
                    .fill(c.color)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(.white, lineWidth: host.color == c ? 2 : 0))
                    .onTapGesture { host.color = c }
            }
        }
    }

    private func save() {
        if host.auth != .key {
            if password.isEmpty { Keychain.remove("host.password.\(host.id.uuidString)") }
            else { try? Keychain.set(password, for: "host.password.\(host.id.uuidString)") }
        }
        onSave(host)
        dismiss()
    }
}
