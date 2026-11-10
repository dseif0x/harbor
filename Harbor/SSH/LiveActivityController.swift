import Foundation
import ActivityKit

/// Starts, updates and ends the session Live Activity. Live Activities keep a
/// compact status visible while the app is backgrounded and extend the runtime
/// iOS grants the app — the closest iOS allows to Termius's "always-on" banner.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private init() {}

    private var activity: Activity<HarborActivityAttributes>?

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(host: String, status: ConnectionStatus, forwards: Int = 0) {
        guard areActivitiesEnabled else { return }
        end() // only one at a time
        let attrs = HarborActivityAttributes(hostName: host)
        let state = HarborActivityAttributes.ContentState(
            statusLabel: status.label,
            isConnected: status == .connected,
            activeForwards: forwards,
            transfersRunning: 0
        )
        activity = try? Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil)
        )
    }

    func update(status: ConnectionStatus, forwards: Int = 0, transfers: Int = 0) {
        guard let activity else { return }
        let state = HarborActivityAttributes.ContentState(
            statusLabel: status.label,
            isConnected: status == .connected,
            activeForwards: forwards,
            transfersRunning: transfers
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
    }
}
