import SwiftUI

/// Lifecycle of a live SSH session, surfaced in the UI and the Live Activity.
enum ConnectionStatus: Equatable {
    case idle
    case connecting
    case authenticating
    case connected
    case reconnecting(attempt: Int)
    case disconnected(reason: String?)
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .connecting: return "Connecting…"
        case .authenticating: return "Authenticating…"
        case .connected: return "Connected"
        case .reconnecting(let n): return "Reconnecting (\(n))…"
        case .disconnected(let r): return r.map { "Disconnected: \($0)" } ?? "Disconnected"
        case .failed(let m): return "Failed: \(m)"
        }
    }

    var isActive: Bool {
        switch self {
        case .connecting, .authenticating, .connected, .reconnecting: return true
        default: return false
        }
    }

    var tint: Color {
        switch self {
        case .connected: return .green
        case .connecting, .authenticating, .reconnecting: return .yellow
        case .failed, .disconnected: return .red
        case .idle: return .secondary
        }
    }
}
