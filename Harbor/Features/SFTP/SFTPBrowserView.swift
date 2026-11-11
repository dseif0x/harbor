import SwiftUI
import UniformTypeIdentifiers

struct SFTPBrowserView: View {
    let session: SSHSession
    @Environment(\.dismiss) private var dismiss

    @State private var sftp: SFTPClient?
    @State private var path = "/"
    @State private var entries: [SFTPEntry] = []
    @State private var loading = true
    @State private var error: String?

    @State private var showTransfers = false
    @State private var showImporter = false
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var renameTarget: SFTPEntry?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            breadcrumb
            Divider()
            Group {
                if loading && entries.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    errorView(error)
                } else {
                    fileList
                }
            }
        }
        .harborBackground()
        .navigationTitle(folderName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showTransfers) { NavigationStack { TransferListView(session: session) } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { handleImport($0) }
        .alert("New folder", isPresented: $showNewFolder) {
            TextField("Name", text: $newFolderName)
            Button("Create") { createFolder() }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
        .alert("Rename", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") { performRename() }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .task { await connect() }
    }

    // MARK: Derived

    private var folderName: String {
        let n = (path as NSString).lastPathComponent
        return n.isEmpty || n == "/" ? "Files" : n
    }
    private var runningTransfers: Int { session.transfers.filter { $0.state == .running }.count }
    private var canGoUp: Bool { path != "/" && !path.isEmpty }

    /// Cumulative breadcrumb segments: [(name, fullPath)].
    private var crumbs: [(name: String, path: String)] {
        var result: [(String, String)] = [("/", "/")]
        var acc = ""
        for part in path.split(separator: "/") {
            acc += "/" + part
            result.append((String(part), acc))
        }
        return result
    }

    // MARK: Breadcrumb

    private var breadcrumb: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(crumbs.enumerated()), id: \.offset) { i, crumb in
                        if i > 0 { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
                        Button { Task { await load(crumb.path) } } label: {
                            HStack(spacing: 4) {
                                if i == 0 { Image(systemName: "externaldrive").font(.caption) }
                                Text(i == 0 ? "root" : crumb.name)
                                    .font(.subheadline.weight(i == crumbs.count - 1 ? .semibold : .regular))
                            }
                            .foregroundStyle(i == crumbs.count - 1 ? Color.primary : Color.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(i == crumbs.count - 1 ? AnyShapeStyle(Theme.accent.opacity(0.18)) : AnyShapeStyle(.clear),
                                        in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .onChange(of: path) { _, _ in withAnimation { proxy.scrollTo(crumbs.count - 1, anchor: .trailing) } }
        }
    }

    // MARK: File list

    private var fileList: some View {
        List {
            if canGoUp {
                Button { Task { await load(parent(of: path)) } } label: {
                    Label { Text("..").fontWeight(.medium) } icon: {
                        Image(systemName: "arrow.turn.left.up").foregroundStyle(Theme.accent)
                    }
                }
                .listRowBackground(Theme.surface)
            }
            ForEach(entries) { entry in
                entryRow(entry)
                    .listRowBackground(Theme.surface)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await load(path) }
        .overlay {
            if entries.isEmpty && !loading && error == nil {
                ContentUnavailableView("Empty folder", systemImage: "folder", description: Text("Nothing here yet."))
            }
        }
    }

    @ViewBuilder private func entryRow(_ entry: SFTPEntry) -> some View {
        Button {
            if entry.isDirectory { Task { await load(entry.path) } } else { download(entry) }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: entry.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(entry.isDirectory ? Theme.accent : .secondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).foregroundStyle(.primary).lineLimit(1)
                    Text(subtitle(entry)).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if entry.isDirectory {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "arrow.down.circle").foregroundStyle(Theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { remove(entry) } label: { Label("Delete", systemImage: "trash") }
            Button { renameTarget = entry; renameText = entry.name } label: { Label("Rename", systemImage: "pencil") }.tint(.indigo)
        }
        .swipeActions(edge: .leading) {
            if !entry.isDirectory {
                Button { download(entry) } label: { Label("Download", systemImage: "arrow.down") }.tint(.blue)
            }
        }
    }

    private func subtitle(_ e: SFTPEntry) -> String {
        if e.isDirectory { return e.modeString }
        var s = Format.bytes(e.size)
        if let m = e.modified { s += " · " + m.formatted(date: .abbreviated, time: .shortened) }
        return s
    }

    private func errorView(_ msg: String) -> some View {
        ContentUnavailableView {
            Label("Can't open folder", systemImage: "exclamationmark.triangle")
        } description: {
            Text(msg)
        } actions: {
            Button("Retry") { Task { await load(path) } }.buttonStyle(.borderedProminent)
            if canGoUp { Button("Go up") { Task { await load(parent(of: path)) } } }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
        ToolbarItem(placement: .topBarLeading) {
            Button { Task { await load(parent(of: path)) } } label: { Image(systemName: "arrow.up") }
                .disabled(!canGoUp)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showTransfers = true } label: {
                Image(systemName: runningTransfers > 0 ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                    .foregroundStyle(runningTransfers > 0 ? Color.green : Color.accentColor)
            }
            Menu {
                Button { showImporter = true } label: { Label("Upload file", systemImage: "arrow.up.doc") }
                Button { showNewFolder = true } label: { Label("New folder", systemImage: "folder.badge.plus") }
                Button { Task { await load(path) } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            } label: { Image(systemName: "plus") }
        }
    }

    // MARK: Data

    private func parent(of p: String) -> String {
        let trimmed = p.hasSuffix("/") && p != "/" ? String(p.dropLast()) : p
        let up = (trimmed as NSString).deletingLastPathComponent
        return up.isEmpty ? "/" : up
    }

    private func connect() async {
        do {
            let client = try await session.openSFTP()
            sftp = client
            let home = try await client.realpath(".")
            await load(home.isEmpty ? "/" : home)
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
            let listed = try await sftp.list(resolved)
            entries = listed
            path = resolved.isEmpty ? "/" : resolved
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    // MARK: Actions

    private func download(_ entry: SFTPEntry) {
        guard let sftp else { return }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        session.download(entry: entry, using: sftp, to: dir.appendingPathComponent(entry.name))
        showTransfers = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let sftp, case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tmp)
            try? FileManager.default.copyItem(at: url, to: tmp)
            session.upload(localURL: tmp, name: url.lastPathComponent, size: size, to: path, using: sftp)
        }
        showTransfers = true
    }

    private func createFolder() {
        guard let sftp, !newFolderName.isEmpty else { return }
        let target = (path as NSString).appendingPathComponent(newFolderName)
        let name = newFolderName; newFolderName = ""
        Task {
            do { try await sftp.makeDirectory(target); await load(path) }
            catch { self.error = "Couldn't create \(name): \(error.localizedDescription)" }
        }
    }

    private func performRename() {
        guard let sftp, let entry = renameTarget, !renameText.isEmpty else { return }
        let newPath = (path as NSString).appendingPathComponent(renameText)
        renameTarget = nil
        Task {
            do { try await sftp.rename(entry.path, to: newPath); await load(path) }
            catch { self.error = error.localizedDescription }
        }
    }

    private func remove(_ entry: SFTPEntry) {
        guard let sftp else { return }
        Task {
            do { try await sftp.remove(entry.path, isDirectory: entry.isDirectory); await load(path) }
            catch { self.error = error.localizedDescription }
        }
    }
}
