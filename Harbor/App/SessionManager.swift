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

    func open(_ host: Host) -> SSHSession {
        if let existing = sessions.first(where: { $0.host.id == host.id }) {
            active = existing
            return existing
        }
        let session = SSHSession(host: host, store: store)
        sessions.append(session)
        active = session
        Task { await session.connect() }
        return session
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
