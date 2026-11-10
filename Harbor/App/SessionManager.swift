import Foundation
import Observation

/// Tracks the live sessions so the user can keep several open and switch between
/// them. Terminal state lives in each `SSHSession`.
@MainActor
@Observable
final class SessionManager {
    private(set) var sessions: [SSHSession] = []
    var active: SSHSession?

    private let store: AppStore
    init(store: AppStore) { self.store = store }

    /// Always opens a new session, so you can hold several connections to the
    /// same host at once. Use `focusOrOpen` to reuse an existing one.
    @discardableResult
    func open(_ host: Host) -> SSHSession {
        let session = SSHSession(host: host, store: store)
        sessions.append(session)
        active = session
        Task { await session.connect() }
        return session
    }

    /// Number of live sessions for a host, for the Hosts badge.
    func sessionCount(for host: Host) -> Int {
        sessions.filter { $0.host.id == host.id && $0.status.isActive }.count
    }

    func close(_ session: SSHSession) {
        Task { await session.disconnect() }
        sessions.removeAll { $0.id == session.id }
        if active?.id == session.id { active = sessions.last }
    }

    var hasActiveConnections: Bool {
        sessions.contains { $0.status.isActive }
    }

    var activeCount: Int {
        sessions.filter { $0.status.isActive }.count
    }

    /// Removes sessions that have ended (disconnected or failed), so the
    /// Terminal list only shows live connections — like Termius.
    func pruneDead() {
        let dead = sessions.filter { !$0.status.isActive }
        for s in dead { Task { await s.disconnect() } }
        sessions.removeAll { !$0.status.isActive }
        if let a = active, !a.status.isActive { active = sessions.last }
    }
}
