import SwiftUI
import SwiftTerm

/// Lets SwiftUI reach into the UIKit terminal (e.g. to dismiss the keyboard).
final class TerminalController {
    weak var view: TerminalView?
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

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView()
        view.terminalDelegate = context.coordinator
        // Suppress SwiftTerm's built-in keyboard accessory; Harbor shows its own
        // glass key bar, so we don't want two stacked rows. (setupAccessoryView
        // runs once during init, so clearing it here is enough.)
        view.inputAccessoryView = nil
        applyFonts(view)
        view.backgroundColor = Theme.bgUI
        view.nativeBackgroundColor = Theme.bgUI
        view.nativeForegroundColor = UIColor(white: 0.92, alpha: 1)
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
    }

    private func applyFonts(_ view: TerminalView) {
        let regular = TerminalFont.mono(fontSize)
        let bold = TerminalFont.mono(fontSize, weight: .bold)
        view.setFonts(normal: regular, bold: bold, italic: regular, boldItalic: bold)
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        let session: SSHSession
        weak var terminalView: TerminalView?
        init(session: SSHSession) { self.session = session }

        // SwiftTerm invokes these on the main thread.
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            MainActor.assumeIsolated { session.sendToShell(Data(data)) }
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
