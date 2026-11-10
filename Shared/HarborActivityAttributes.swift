import Foundation
import ActivityKit

/// Shared between the app and the widget extension. Describes the Live Activity
/// that shows an active SSH session on the Lock Screen and in the Dynamic Island.
struct HarborActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusLabel: String
        var isConnected: Bool
        var activeForwards: Int
        var transfersRunning: Int
    }

    var hostName: String
}
