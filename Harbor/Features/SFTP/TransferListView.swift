import SwiftUI

/// The live transfers panel: a progress bar, rate and ETA per transfer — the
/// detail Termius's SFTP omits.
struct TransferListView: View {
    let session: SSHSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if session.transfers.isEmpty {
                EmptyState(icon: "arrow.up.arrow.down", title: "No transfers", message: "Downloads and uploads show their live progress here.")
                    .listRowBackground(Color.clear)
            }
            ForEach(session.transfers) { transfer in
                TransferRow(transfer: transfer)
            }
        }
        .navigationTitle("Transfers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") { session.clearFinishedTransfers() }
                    .disabled(!session.transfers.contains { $0.state != .running })
            }
        }
    }
}

struct TransferRow: View {
    let transfer: Transfer
    // Re-render ~2×/s so the rate and ETA tick while running.
    @State private var tick = Date()
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: transfer.direction == .download ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(transfer.direction == .download ? .blue : .green)
                Text(transfer.name).lineLimit(1).fontWeight(.medium)
                Spacer()
                stateBadge
            }

            ProgressView(value: transfer.fraction)
                .tint(transfer.direction == .download ? .blue : .green)

            HStack {
                Text("\(Format.bytes(transfer.transferred)) / \(Format.bytes(transfer.total))")
                Spacer()
                if transfer.state == .running {
                    Text(Format.rate(transfer.rate))
                    if let eta = transfer.etaSeconds {
                        Text("· \(Format.eta(eta)) left")
                    }
                }
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .onReceive(timer) { tick = $0 }
        .id(tick.timeIntervalSince1970.rounded()) // nudge view while running
    }

    @ViewBuilder private var stateBadge: some View {
        switch transfer.state {
        case .running:
            Text("\(Int(transfer.fraction * 100))%").font(.caption).monospacedDigit().foregroundStyle(.secondary)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .cancelled:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.orange)
        case .failed(let msg):
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                .help(msg)
        }
    }
}
