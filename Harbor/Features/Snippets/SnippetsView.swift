import SwiftUI

struct SnippetsView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: Snippet?
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if store.snippets.isEmpty {
                    EmptyState(icon: "chevron.left.forwardslash.chevron.right", title: "No snippets",
                               message: "Save commands you run often and fire them into any session with a tap.")
                } else {
                    List {
                        ForEach(store.snippets) { snippet in
                            Button { editing = snippet } label: { row(snippet) }
                                .swipeActions {
                                    Button(role: .destructive) { store.delete(snippet) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Snippets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) { SnippetEditView(snippet: Snippet()) }
            .sheet(item: $editing) { SnippetEditView(snippet: $0) }
        }
    }

    private func row(_ snippet: Snippet) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snippet.name).fontWeight(.medium)
            Text(snippet.preview).font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

struct SnippetEditView: View {
    @State var snippet: Snippet
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("e.g. Tail logs", text: $snippet.name) }
                Section("Command") {
                    TextEditor(text: $snippet.command)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(snippet.name.isEmpty ? "New Snippet" : snippet.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.upsert(snippet); dismiss() }
                        .fontWeight(.semibold)
                        .disabled(snippet.name.isEmpty || snippet.command.isEmpty)
                }
            }
        }
    }
}

/// A compact picker shown inside a session to run a snippet.
struct SnippetPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onPick: (Snippet) -> Void

    var body: some View {
        NavigationStack {
            List(store.snippets) { snippet in
                Button { onPick(snippet) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(snippet.name).fontWeight(.medium).foregroundStyle(.primary)
                        Text(snippet.preview).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .overlay { if store.snippets.isEmpty {
                EmptyState(icon: "chevron.left.forwardslash.chevron.right", title: "No snippets", message: "Create snippets in the Snippets tab.")
            } }
            .navigationTitle("Run snippet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
