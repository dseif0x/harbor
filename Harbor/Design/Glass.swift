import SwiftUI

extension View {
    /// Applies Liquid Glass on iOS 26+, falling back to a translucent material
    /// (optionally tinted) on earlier systems. One place so the whole app opts
    /// into the native look consistently.
    @ViewBuilder
    func harborGlass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            var glass: Glass = .regular
            if let tint { glass = glass.tint(tint) }
            if interactive { glass = glass.interactive() }
            self.glassEffect(glass, in: shape)
        } else {
            self.background(
                tint.map { AnyShapeStyle($0.opacity(0.22)) } ?? AnyShapeStyle(.ultraThinMaterial),
                in: shape
            )
        }
    }
}
