import Foundation
import Observation

/// App-wide navigation state, so one screen can switch tabs (e.g. connecting
/// from Hosts jumps to the Terminal).
@MainActor
@Observable
final class Navigator {
    enum Tab: Hashable { case hosts, terminal, keys, snippets, settings }
    var tab: Tab = .hosts
}
