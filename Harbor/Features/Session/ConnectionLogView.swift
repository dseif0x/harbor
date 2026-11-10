import SwiftUI

/// Shows the session's connection log with copy/share, so failures are
/// diagnosable on-device.
struct ConnectionLogView: View {
    let session: SSHSession
    @Environment(\.dismiss) private var dismiss

    private var text: String {
        session.log.map { "\($0.time.formatted(date: .omitted, time: .standard))  \($0.text)" }
            .joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(session.log) { e in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(color(e.kind)).frame(width: 7, height: 7).padding(.top, 5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.text)
                                        .font(.system(.footnote, design: .monospaced))
                                        .textSelection(.enabled)
                                        .foregroundStyle(e.kind == .error ? Color.red : .primary)
                                    Text(e.time.formatted(date: .omitted, time: .standard))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .id(e.id)
                        }
                        if session.log.isEmpty {
                            Text("No log entries yet.").foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .onChange(of: session.log.count) {
                    if let last = session.log.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            .navigationTitle("Connection log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: text) { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
    }

    private func color(_ k: SSHSession.LogEntry.Kind) -> Color {
        switch k {
        case .info: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }
}
