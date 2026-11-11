import SwiftUI
import SwiftTerm
import Observation

/// Lets SwiftUI reach into the UIKit terminal (dismiss the keyboard) and shares
/// the "ctrl armed" state so a following keystroke becomes a control code.
@Observable
final class TerminalController {
    @ObservationIgnored weak var view: TerminalView?
    var ctrlArmed = false
    func dismissKeyboard() { _ = view?.resignFirstResponder() }
    func focus() { _ = view?.becomeFirstResponder() }
}

/// The terminal font. Fira Code gives a clean, modern monospace; we fall back
/// to the system monospace if it fails to load. (SwiftTerm renders per cell, so
/// Fira Code's programming ligatures are not combined — glyphs only.)
enum TerminalFont {
    static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name = weight == .bold ? "FiraCode-Bold" : (weight == .light ? "FiraCode-Light" : "FiraCode-Regular")
        return UIFont(name: name, size: size) ?? .monospacedSystemFont(ofSize: size, weight: weight)
    }
}

/// Bridges SwiftTerm's UIKit `TerminalView` into SwiftUI and wires it to an
/// `SSHSession`: server bytes are fed in, keystrokes and resizes go back out.
struct TerminalScreen: UIViewRepresentable {
    let session: SSHSession
    let controller: TerminalController
    var fontSize: CGFloat = 13

    func makeCoordinator() -> Coordinator { Coordinator(session: session, controller: controller) }

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView()
        view.terminalDelegate = context.coordinator
        // Suppress SwiftTerm's built-in keyboard accessory; Harbor shows its own
        // glass key bar, so we don't want two stacked rows.
        view.inputAccessoryView = nil
        applyFonts(view)
        applyColors(view)
        controller.view = view

        // Server → terminal.
        session.onShellData = { [weak view] data in
            guard let view else { return }
            view.feed(byteArray: ArraySlice(Array(data)))
        }
        context.coordinator.terminalView = view
        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        applyFonts(uiView)
        applyColors(uiView)
    }

    private func applyFonts(_ view: TerminalView) {
        let regular = TerminalFont.mono(fontSize)
        let bold = TerminalFont.mono(fontSize, weight: .bold)
        view.setFonts(normal: regular, bold: bold, italic: regular, boldItalic: bold)
    }

    /// Paints the terminal with the app's slate background instead of black.
    /// We set both the view-level native colors (used to clear the surface) and
    /// the terminal's default cell colors, applied again in updateUIView so a
    /// late init pass can't reset them to black.
    private func applyColors(_ view: TerminalView) {
        view.backgroundColor = Theme.bgUI
        view.nativeBackgroundColor = Theme.bgUI
        view.nativeForegroundColor = UIColor(white: 0.92, alpha: 1)
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        let session: SSHSession
        let controller: TerminalController
        weak var terminalView: TerminalView?
        init(session: SSHSession, controller: TerminalController) {
            self.session = session
            self.controller = controller
        }

        // SwiftTerm invokes these on the main thread.
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            MainActor.assumeIsolated {
                var bytes = Array(data)
                // If ctrl is armed, turn the next single character into its
                // control code (e.g. ctrl + d -> 0x04), then disarm.
                if controller.ctrlArmed {
                    controller.ctrlArmed = false
                    if bytes.count == 1 { bytes[0] = Self.controlByte(bytes[0]) }
                }
                session.sendToShell(Data(bytes))
            }
        }

        /// Maps a printable byte to its control code the way a keyboard ctrl does.
        static func controlByte(_ b: UInt8) -> UInt8 {
            switch b {
            case 0x61...0x7a: return b - 0x60   // a-z -> 0x01-0x1a
            case 0x41...0x5f: return b - 0x40   // @A-Z[\]^_ -> 0x00-0x1f
            default: return b
            }
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            MainActor.assumeIsolated { session.resizeTerminal(cols: newCols, rows: newRows) }
        }

        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func scrolled(source: TerminalView, position: Double) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {
            if let url = URL(string: link) { MainActor.assumeIsolated { UIApplication.shared.open(url) } }
        }
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {
            if let s = String(data: content, encoding: .utf8) { UIPasteboard.general.string = s }
        }
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
