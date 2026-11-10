import Foundation
import Citadel
import NIOCore

/// `SFTPClient` backed by Citadel's SFTP channel. Downloads and uploads are
/// chunked so progress is reported continuously — the UX win over clients that
/// only show a spinner.
actor CitadelSFTP: SFTPClient {
    private let sftp: SFTPClient_Citadel
    /// Alias so the Citadel type name doesn't collide with our protocol.
    typealias SFTPClient_Citadel = Citadel.SFTPClient

    private let chunkSize = 32 * 1024   // 32 KiB per read/write round-trip

    init(sftp: SFTPClient_Citadel) { self.sftp = sftp }

    func list(_ path: String) async throws -> [SFTPEntry] {
        let items = try await sftp.listDirectory(atPath: path)
        return items.flatMap { dir in
            dir.components.compactMap { comp -> SFTPEntry? in
                let name = comp.filename
                if name == "." || name == ".." { return nil }
                let attrs = comp.attributes
                let full = path.hasSuffix("/") ? path + name : path + "/" + name
                let perms = attrs.permissions ?? 0
                let isDir = (perms & 0o040000) != 0
                let isLink = (perms & 0o120000) == 0o120000
                return SFTPEntry(
                    name: name,
                    path: full,
                    isDirectory: isDir,
                    isSymlink: isLink,
                    size: Int64(attrs.size ?? 0),
                    modified: attrs.accessModificationTime?.modificationTime,
                    permissions: perms & 0o777
                )
            }
        }
        .sorted { ($0.isDirectory ? 0 : 1, $0.name.lowercased()) < ($1.isDirectory ? 0 : 1, $1.name.lowercased()) }
    }

    func realpath(_ path: String) async throws -> String {
        (try? await sftp.getRealPath(atPath: path)) ?? path
    }

    func download(remotePath: String, to localURL: URL, onProgress: @escaping (Int64) -> Void) async throws {
        let file = try await sftp.openFile(filePath: remotePath, flags: .read)
        defer { Task { try? await file.close() } }

        let attrs = try await file.readAttributes()
        let total = Int64(attrs.size ?? 0)

        FileManager.default.createFile(atPath: localURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: localURL)
        defer { try? handle.close() }

        var offset: UInt64 = 0
        var transferred: Int64 = 0
        while true {
            try Task.checkCancellation()
            let buffer = try await file.read(from: offset, length: UInt32(chunkSize))
            let bytes = buffer.getBytes(at: 0, length: buffer.readableBytes) ?? []
            if bytes.isEmpty { break }
            try handle.write(contentsOf: Data(bytes))
            offset += UInt64(bytes.count)
            transferred += Int64(bytes.count)
            onProgress(transferred)
            if total > 0 && transferred >= total { break }
            if bytes.count < chunkSize { break }
        }
    }

    func upload(localURL: URL, to remotePath: String, onProgress: @escaping (Int64) -> Void) async throws {
        let handle = try FileHandle(forReadingFrom: localURL)
        defer { try? handle.close() }

        let file = try await sftp.openFile(
            filePath: remotePath,
            flags: [.write, .create, .truncate]
        )
        defer { Task { try? await file.close() } }

        var offset: UInt64 = 0
        var transferred: Int64 = 0
        while true {
            try Task.checkCancellation()
            let data = try handle.read(upToCount: chunkSize) ?? Data()
            if data.isEmpty { break }
            var buf = ByteBufferAllocator().buffer(capacity: data.count)
            buf.writeBytes(data)
            try await file.write(buf, at: offset)
            offset += UInt64(data.count)
            transferred += Int64(data.count)
            onProgress(transferred)
        }
    }

    func makeDirectory(_ path: String) async throws { try await sftp.createDirectory(atPath: path) }

    func remove(_ path: String, isDirectory: Bool) async throws {
        if isDirectory { try await sftp.rmdir(at: path) }
        else { try await sftp.remove(at: path) }
    }

    func rename(_ path: String, to newPath: String) async throws {
        try await sftp.rename(at: path, to: newPath)
    }

    func close() async { try? await sftp.close() }
}
