import SwiftUI

extension View {
    /// A Liquid Glass surface for Harbor's custom controls (cards, chips, keys).
    /// Optionally tinted and interactive (reacts to touch).
    func harborGlass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glassEffect(glass, in: shape)
    }
}
