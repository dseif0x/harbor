import SwiftUI

@main
struct HarborApp: App {
    @State private var store: AppStore
    @State private var sessions: SessionManager

    init() {
        let store = AppStore()
        _store = State(initialValue: store)
        _sessions = State(initialValue: SessionManager(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(sessions)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
