import SwiftUI

/// A prominent, gradient-filled primary button.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: Theme.smallCorner, style: .continuous))
        }
    }
}

/// A small, colored status pill.
struct StatusPill: View {
    let status: ConnectionStatus
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(status.tint).frame(width: 8, height: 8)
            Text(status.label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(status.tint.opacity(0.12), in: Capsule())
    }
}

/// A rounded monogram avatar for a host, tinted by its color.
struct HostAvatar: View {
    let host: Host
    var size: CGFloat = 44
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(host.color.color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
    private var initials: String {
        let base = host.label.isEmpty ? host.hostname : host.label
        let parts = base.split(whereSeparator: { " .-_@".contains($0) })
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

/// An empty-state placeholder.
struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(Theme.accentGradient)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 320)
        .padding(32)
    }
}

/// Byte and rate formatting helpers.
enum Format {
    static func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
    static func rate(_ bytesPerSec: Double) -> String {
        bytes(Int64(bytesPerSec)) + "/s"
    }
    static func eta(_ seconds: Double) -> String {
        if seconds < 1 { return "–" }
        if seconds < 60 { return "\(Int(seconds))s" }
        let m = Int(seconds) / 60, s = Int(seconds) % 60
        return "\(m)m \(s)s"
    }
}
