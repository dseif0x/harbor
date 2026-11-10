import ActivityKit
import WidgetKit
import SwiftUI

/// Lock Screen banner + Dynamic Island presentation for an active session.
struct HarborLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HarborActivityAttributes.self) { context in
            // Lock Screen / banner
            HStack(spacing: 12) {
                statusDot(context.state.isConnected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.hostName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                badges(context.state)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.hostName, systemImage: "terminal")
                        .font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    badges(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.statusLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(context.state.isConnected ? .green : .yellow)
            } compactTrailing: {
                if context.state.transfersRunning > 0 {
                    Image(systemName: "arrow.down.circle")
                } else if context.state.activeForwards > 0 {
                    Text("\(context.state.activeForwards)")
                }
            } minimal: {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(context.state.isConnected ? .green : .yellow)
            }
        }
    }

    @ViewBuilder private func statusDot(_ connected: Bool) -> some View {
        Circle()
            .fill(connected ? Color.green : Color.yellow)
            .frame(width: 10, height: 10)
    }

    @ViewBuilder private func badges(_ state: HarborActivityAttributes.ContentState) -> some View {
        HStack(spacing: 10) {
            if state.activeForwards > 0 {
                Label("\(state.activeForwards)", systemImage: "arrow.left.arrow.right")
                    .font(.caption2)
            }
            if state.transfersRunning > 0 {
                Label("\(state.transfersRunning)", systemImage: "arrow.down")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.secondary)
    }
}
