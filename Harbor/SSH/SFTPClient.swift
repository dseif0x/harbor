import Foundation

/// A remote directory entry.
struct SFTPEntry: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var isDirectory: Bool
    var isSymlink: Bool
    var size: Int64
    var modified: Date?
    var permissions: UInt32

    var icon: String {
        if isDirectory { return "folder.fill" }
        if isSymlink { return "arrow.triangle.turn.up.right.circle" }
        switch (name as NSString).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "heic", "webp": return "photo"
        case "zip", "gz", "tar", "xz", "7z": return "doc.zipper"
        case "pdf": return "doc.richtext"
        case "mp4", "mov", "mkv": return "film"
        case "mp3", "wav", "flac", "m4a": return "music.note"
        case "sh", "py", "js", "ts", "go", "rs", "swift", "c", "h", "rb": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }

    /// Octal `rwx` string, e.g. "rwxr-xr-x".
    var modeString: String {
        let bits = ["r", "w", "x"]
        var out = isDirectory ? "d" : (isSymlink ? "l" : "-")
        for shift in stride(from: 6, through: 0, by: -3) {
            let p = (permissions >> UInt32(shift)) & 0b111
            for (i, c) in bits.enumerated() {
                out += (p >> (2 - UInt32(i))) & 1 == 1 ? c : "-"
            }
        }
        return out
    }
}

/// Progress for a single transfer, observable from SwiftUI.
@MainActor
@Observable
final class Transfer: Identifiable {
    let id = UUID()
    let name: String
    let direction: Direction
    let total: Int64
    var transferred: Int64 = 0
    var state: State = .running
    var startedAt = Date()

    enum Direction { case download, upload }
    enum State: Equatable { case running, done, failed(String), cancelled }

    init(name: String, direction: Direction, total: Int64) {
        self.name = name
        self.direction = direction
        self.total = total
    }

    var fraction: Double {
        guard total > 0 else { return state == .done ? 1 : 0 }
        return min(1, Double(transferred) / Double(total))
    }

    /// Bytes per second since the transfer started.
    var rate: Double {
        let elapsed = Date().timeIntervalSince(startedAt)
        return elapsed > 0 ? Double(transferred) / elapsed : 0
    }

    var etaSeconds: Double? {
        let r = rate
        guard r > 0, total > transferred else { return nil }
        return Double(total - transferred) / r
    }
}

/// SFTP operations. Downloads and uploads report progress incrementally so the
/// UI can show a live bar, rate and ETA — the headline feature over Termius,
/// which only shows a spinner.
protocol SFTPClient: AnyObject {
    func list(_ path: String) async throws -> [SFTPEntry]
    func realpath(_ path: String) async throws -> String

    /// Streams `remotePath` to `localURL`, calling `onProgress` with the running
    /// byte count. Honors `Task` cancellation between chunks.
    func download(
        remotePath: String,
        to localURL: URL,
        onProgress: @escaping (Int64) -> Void
    ) async throws

    func upload(
        localURL: URL,
        to remotePath: String,
        onProgress: @escaping (Int64) -> Void
    ) async throws

    func makeDirectory(_ path: String) async throws
    func remove(_ path: String, isDirectory: Bool) async throws
    func rename(_ path: String, to newPath: String) async throws
    func close() async
}
