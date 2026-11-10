import Foundation

/// A reusable command (or sequence) the user can run in any session.
struct Snippet: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var command: String = ""
    var createdAt: Date = Date()

    /// `true` when the command spans multiple lines.
    var isMultiline: Bool { command.contains("\n") }

    var preview: String {
        command.split(separator: "\n").first.map(String.init) ?? command
    }
}
