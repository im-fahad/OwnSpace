import OwnSpaceCore
import SwiftUI

/// Liquid Glass on macOS 26 and later, a frosted material before that.
extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 20, tint: Color? = nil, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            let base = tint.map { Glass.regular.tint($0.opacity(0.18)) } ?? .regular
            glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.12)))
        }
    }

    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}

/// Groups nearby glass shapes so they blend and morph together; a plain stack before macOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension JunkCategory {
    var tint: Color {
        switch self {
        case .userCaches: .blue
        case .logs: .purple
        case .xcode: .cyan
        case .simulators: .teal
        case .packageCaches: .orange
        case .trash: .pink
        }
    }
}

/// Soft colored light behind the content, so the glass above it has something to refract.
struct AmbientBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            Circle()
                .fill(tint.opacity(0.35))
                .frame(width: 520, height: 520)
                .blur(radius: 120)
                .offset(x: 220, y: -200)
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .offset(x: -260, y: 240)
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.6), value: tint)
    }
}

/// A rounded, colored tile holding an SF Symbol, like the ones in System Settings.
struct SymbolTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}
