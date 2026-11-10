import SwiftUI
import SwiftTerm

/// Bridges SwiftTerm's UIKit `TerminalView` into SwiftUI and wires it to an
/// `SSHSession`: server bytes are fed in, keystrokes and resizes go back out.
struct TerminalScreen: UIViewRepresentable {
    let session: SSHSession
    var fontSize: CGFloat = 13

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView()
        view.terminalDelegate = context.coordinator
        view.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        view.backgroundColor = .black
        view.nativeBackgroundColor = .black
        view.nativeForegroundColor = UIColor(white: 0.92, alpha: 1)

        // Server → terminal.
        session.onShellData = { [weak view] data in
            guard let view else { return }
            view.feed(byteArray: ArraySlice(Array(data)))
        }
        context.coordinator.terminalView = view
        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        uiView.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
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
