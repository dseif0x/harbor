import Foundation

/// A port-forwarding rule attached to a host.
struct PortForward: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: Kind = .local
    var bindHost: String = "127.0.0.1"
    var bindPort: Int = 8080
    var destHost: String = "localhost"
    var destPort: Int = 80
    var autoStart: Bool = false

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case local = "Local"     // -L : listen locally, forward to remote
        case remote = "Remote"   // -R : listen on server, forward to us
        case dynamic = "Dynamic" // -D : SOCKS proxy
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .local: return "arrow.right"
            case .remote: return "arrow.left"
            case .dynamic: return "shuffle"
            }
        }
    }

    var summary: String {
        switch kind {
        case .dynamic: return "SOCKS \(bindHost):\(bindPort)"
        case .local: return "\(bindHost):\(bindPort) → \(destHost):\(destPort)"
        case .remote: return "\(destHost):\(destPort) ← \(bindHost):\(bindPort)"
        }
    }
}
