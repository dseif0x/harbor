import Foundation

/// A remembered server host key, our equivalent of `~/.ssh/known_hosts`.
/// Trust-on-first-use: we pin the key the first time and warn if it changes.
struct KnownHost: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var hostname: String
    var port: Int
    var keyType: String          // e.g. "ssh-ed25519"
    var fingerprintSHA256: String
    var addedAt: Date = Date()

    func matches(hostname: String, port: Int) -> Bool {
        self.hostname.caseInsensitiveCompare(hostname) == .orderedSame && self.port == port
    }
}
