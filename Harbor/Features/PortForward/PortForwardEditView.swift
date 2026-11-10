import SwiftUI

/// Editor for a host's port-forwarding rules. (Starting/stopping tunnels at
/// runtime is wired through `SSHTransport`; this manages the saved rules.)
struct PortForwardEditView: View {
    @Binding var forwards: [PortForward]
    @State private var draft = PortForward()
    @State private var showDraft = false

    var body: some View {
        List {
            if forwards.isEmpty {
                Text("No forwards yet.").foregroundStyle(.secondary)
            }
            ForEach(forwards) { f in
                HStack {
                    Image(systemName: f.kind.symbol).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading) {
                        Text(f.kind.rawValue).fontWeight(.medium)
                        Text(f.summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { forwards.remove(atOffsets: $0) }
        }
        .navigationTitle("Port Forwarding")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { draft = PortForward(); showDraft = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showDraft) {
            draftEditor
        }
    }

    private var draftEditor: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $draft.kind) {
                    ForEach(PortForward.Kind.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)

                Section("Listen") {
                    TextField("Bind host", text: $draft.bindHost).autocorrectionDisabled()
                    TextField("Bind port", value: $draft.bindPort, format: .number).keyboardType(.numberPad)
                }
                if draft.kind != .dynamic {
                    Section("Destination") {
                        TextField("Host", text: $draft.destHost).autocorrectionDisabled()
                        TextField("Port", value: $draft.destPort, format: .number).keyboardType(.numberPad)
                    }
                }
                Toggle("Start with session", isOn: $draft.autoStart)
            }
            .navigationTitle("New Forward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { forwards.append(draft); showDraft = false }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
