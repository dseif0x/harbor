import SwiftUI
import UniformTypeIdentifiers

struct SFTPBrowserView: View {
    let session: SSHSession
    @Environment(\.dismiss) private var dismiss

    @State private var sftp: SFTPClient?
    @State private var path = "."
    @State private var entries: [SFTPEntry] = []
    @State private var loading = true
    @State private var error: String?
    @State private var showTransfers = false
    @State private var showImporter = false
    @State private var newFolderName = ""
    @State private var showNewFolder = false

    var body: some View {
        List {
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).font(.caption)
            }
            ForEach(entries) { entry in
                entryRow(entry)
            }
        }
        .overlay { if loading { ProgressView() } }
        .overlay { if !loading && entries.isEmpty && error == nil {
            EmptyState(icon: "folder", title: "Empty folder", message: "Nothing here yet.")
        } }
        .navigationTitle(pathTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showTransfers = true } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(runningTransfers > 0 ? Color.green : Color.primary, .primary)
                }
                .overlay(alignment: .topTrailing) {
                    if runningTransfers > 0 {
                        Text("\(runningTransfers)").font(.system(size: 10, weight: .bold))
                            .padding(4).background(.green, in: Circle()).foregroundStyle(.white)
                            .offset(x: 6, y: -6)
                    }
                }
                Menu {
                    Button { showImporter = true } label: { Label("Upload file", systemImage: "arrow.up.doc") }
                    Button { showNewFolder = true } label: { Label("New folder", systemImage: "folder.badge.plus") }
                    Button { Task { await load(path) } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showTransfers) {
            NavigationStack { TransferListView(session: session) }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            handleImport(result)
        }
        .alert("New folder", isPresented: $showNewFolder) {
            TextField("Name", text: $newFolderName)
            Button("Create") { createFolder() }
            Button("Cancel", role: .cancel) {}
        }
        .task { await connect() }
    }

    private var pathTitle: String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty || name == "." ? "Home" : name
    }
    private var runningTransfers: Int { session.transfers.filter { $0.state == .running }.count }

    private func connect() async {
        do {
            let client = try await session.openSFTP()
            sftp = client
            let home = try await client.realpath(".")
            await load(home)
        } catch {
            self.error = error.localizedDescription
            loading = false
        }
    }

    private func load(_ newPath: String) async {
        guard let sftp else { return }
        loading = true; error = nil
        do {
            let resolved = try await sftp.realpath(newPath)
            entries = try await sftp.list(resolved)
            path = resolved
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    @ViewBuilder private func entryRow(_ entry: SFTPEntry) -> some View {
        if entry.isDirectory {
            Button { Task { await load(entry.path) } } label: { rowContent(entry) }
        } else {
            Button { download(entry) } label: { rowContent(entry) }
                .swipeActions {
                    Button(role: .destructive) { remove(entry) } label: { Label("Delete", systemImage: "trash") }
                    Button { download(entry) } label: { Label("Download", systemImage: "arrow.down") }.tint(.blue)
                }
        }
    }

    private func rowContent(_ entry: SFTPEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.icon)
                .foregroundStyle(entry.isDirectory ? Theme.accent : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).foregroundStyle(.primary).lineLimit(1)
                Text(entry.isDirectory ? entry.modeString : "\(Format.bytes(entry.size)) · \(entry.modeString)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if entry.isDirectory { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
            else { Image(systemName: "arrow.down.circle").foregroundStyle(.blue) }
        }
    }

    // MARK: Actions

    private func download(_ entry: SFTPEntry) {
        guard let sftp else { return }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let local = dir.appendingPathComponent(entry.name)
        session.download(entry: entry, using: sftp, to: local)
        showTransfers = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let sftp, case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
            // Copy into a temp location we control for the duration of the upload.
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tmp)
            try? FileManager.default.copyItem(at: url, to: tmp)
            session.upload(localURL: tmp, name: url.lastPathComponent, size: size, to: path, using: sftp)
        }
        showTransfers = true
    }

    private func createFolder() {
        guard let sftp, !newFolderName.isEmpty else { return }
        let target = path.hasSuffix("/") ? path + newFolderName : path + "/" + newFolderName
        Task {
            try? await sftp.makeDirectory(target)
            newFolderName = ""
            await load(path)
        }
    }

    private func remove(_ entry: SFTPEntry) {
        guard let sftp else { return }
        Task {
            try? await sftp.remove(entry.path, isDirectory: entry.isDirectory)
            await load(path)
        }
    }
}
