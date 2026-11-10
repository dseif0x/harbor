import Foundation

/// A saved server the user can connect to.
struct Host: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String = ""
    var hostname: String = ""
    var port: Int = 22
    var username: String = ""

    /// How we authenticate. Passwords and passphrases live in the Keychain,
    /// never in this struct, so a plain export never leaks a secret.
    var auth: AuthMethod = .agentThenPassword
    var keyID: UUID?

    /// Optional free-form grouping, e.g. "Home", "Work".
    var group: String = ""
    var color: HostColor = .teal
    var notes: String = ""

    /// Commands run right after the shell opens (e.g. `tmux attach`).
    var onConnectSnippetID: UUID?

    /// Port-forwarding rules started with the session.
    var forwards: [PortForward] = []

    var lastConnected: Date?
    var createdAt: Date = Date()

    enum AuthMethod: String, Codable, CaseIterable, Identifiable {
        case password
        case key
        case agentThenPassword

        var id: String { rawValue }
        var title: String {
            switch self {
            case .password: return "Password"
            case .key: return "SSH Key"
            case .agentThenPassword: return "Key, then password"
            }
        }
    }

    var displayName: String {
        if !label.isEmpty { return label }
        if username.isEmpty { return hostname }
        return "\(username)@\(hostname)"
    }

    var subtitle: String {
        var s = hostname
        if port != 22 { s += ":\(port)" }
        return s
    }

    var isValid: Bool {
        !hostname.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && (1...65535).contains(port)
    }
}

enum HostColor: String, Codable, CaseIterable, Identifiable {
    case teal, blue, purple, pink, orange, green, red, gray
    var id: String { rawValue }
}
