import SwiftUI

// MARK: - Tokens (mauverse + PrivateMusic Liquid Glass patterns)

enum BrowserTheme {
    static let accent = Color(red: 0.09, green: 0.46, blue: 0.97)
    static let accentLight = Color(red: 0.20, green: 0.52, blue: 0.98)
    static let cyan = Color(red: 0.29, green: 0.78, blue: 1.0)
    static let violet = Color(red: 0.38, green: 0.42, blue: 0.92)
    static let privateAccent = Color(red: 0.58, green: 0.36, blue: 0.92)
    static let secure = Color(red: 0.16, green: 0.70, blue: 0.45)
    static let destructive = Color(red: 0.84, green: 0.32, blue: 0.36)
    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let canvas = Color(uiColor: .systemBackground)
    static let card = Color(uiColor: .secondarySystemBackground)
    static let navy = Color(red: 0.015, green: 0.075, blue: 0.13)

    static func accent(forPrivate isPrivate: Bool) -> Color {
        isPrivate ? privateAccent : accent
    }
}

enum BrowserSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let chromeInset: CGFloat = 12
}

enum BrowserRadius {
    static let compact: CGFloat = 14
    static let card: CGFloat = 20
    static let chrome: CGFloat = 28
    static let preview: CGFloat = 10
}

enum BrowserMotion {
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.82)
    static let chrome = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let grid = Animation.spring(response: 0.38, dampingFraction: 0.84)
    static let orb = Animation.easeInOut(duration: 10).repeatForever(autoreverses: true)
}

enum BrowserMetrics {
    static let iconButton: CGFloat = 44
    static let tabBadgeMinWidth: CGFloat = 26
}

// MARK: - Atmospheric canvas (empty / new tab)

struct BrowserBackground: View {
    var isPrivate: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            BrowserTheme.canvas
            LinearGradient(
                colors: backgroundGradient,
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            orb(color: orbPrimary, size: 420, blur: 80, x: drift ? 190 : 220, y: drift ? -320 : -350)
            orb(color: orbSecondary, size: 360, blur: 90, x: drift ? -190 : -220, y: drift ? 340 : 390)
            if isPrivate {
                orb(color: BrowserTheme.privateAccent.opacity(0.14), size: 300, blur: 70, x: 30, y: 100)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(BrowserMotion.orb) { drift = true }
        }
    }

    private var backgroundGradient: [Color] {
        if isPrivate {
            return colorScheme == .dark
                ? [Color(red: 0.08, green: 0.04, blue: 0.14), .black, BrowserTheme.privateAccent.opacity(0.10)]
                : [BrowserTheme.privateAccent.opacity(0.06), BrowserTheme.canvas, BrowserTheme.violet.opacity(0.05)]
        }
        return colorScheme == .dark
            ? [BrowserTheme.navy.opacity(0.97), .black, BrowserTheme.accent.opacity(0.10)]
            : [BrowserTheme.cyan.opacity(0.07), BrowserTheme.canvas, BrowserTheme.accent.opacity(0.05)]
    }

    private var orbPrimary: Color {
        isPrivate
            ? BrowserTheme.privateAccent.opacity(colorScheme == .dark ? 0.16 : 0.10)
            : BrowserTheme.cyan.opacity(colorScheme == .dark ? 0.16 : 0.11)
    }

    private var orbSecondary: Color {
        isPrivate
            ? BrowserTheme.violet.opacity(colorScheme == .dark ? 0.12 : 0.07)
            : BrowserTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.09)
    }

    private func orb(color: Color, size: CGFloat, blur: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: blur)
            .offset(x: x, y: y)
    }
}

// MARK: - Liquid Glass chrome

enum BrowserGlassStyle {
    case regular
    case thin
    case interactive
}

private struct BrowserGlassModifier: ViewModifier {
    let radius: CGFloat
    let style: BrowserGlassStyle
    var tint: Color?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    BrowserTheme.card.opacity(colorScheme == .dark ? 0.94 : 0.96),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .overlay { chromeStroke }
        } else if #available(iOS 26.0, *) {
            glass26(content)
                .overlay { chromeStroke.opacity(0.55) }
        } else {
            content
                .background(fallbackMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay { chromeStroke }
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func glass26(_ content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if let tint {
            content.glassEffect(.regular.tint(tint).interactive(style == .interactive), in: shape)
        } else {
            content.glassEffect(.regular.interactive(style == .interactive), in: shape)
        }
    }

    private var fallbackMaterial: Material {
        switch style {
        case .thin: .thinMaterial
        case .regular, .interactive: .ultraThinMaterial
        }
    }

    private var chromeStroke: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.white.opacity(0.26), Color.white.opacity(0.06)]
                        : [Color.white.opacity(0.82), Color.white.opacity(0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.85
            )
    }
}

private struct BrowserPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion && isEnabled ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.88 : (isEnabled ? 1 : 0.38))
            .animation(BrowserMotion.press, value: configuration.isPressed)
    }
}

extension View {
    func browserGlass(
        radius: CGFloat = BrowserRadius.chrome,
        style: BrowserGlassStyle = .regular,
        tint: Color? = nil
    ) -> some View {
        modifier(BrowserGlassModifier(radius: radius, style: style, tint: tint))
    }

    func browserPressable() -> some View {
        buttonStyle(BrowserPressStyle())
    }
}

// MARK: - Components

struct BrowserIconButton: View {
    let systemName: String
    var label: String
    var accent: Color = BrowserTheme.ink
    var isProminent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isProminent ? .white : accent)
                .frame(width: BrowserMetrics.iconButton, height: BrowserMetrics.iconButton)
                .background {
                    if isProminent {
                        Circle().fill(BrowserTheme.accent.gradient)
                    }
                }
        }
        .browserPressable()
        .accessibilityLabel(label)
    }
}

struct BrowserTabBadgeButton: View {
    let count: Int
    var isPrivate: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 15, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: BrowserMetrics.iconButton)
            .background(
                BrowserTheme.accent(forPrivate: isPrivate).gradient,
                in: Capsule(style: .continuous)
            )
            .shadow(color: BrowserTheme.accent(forPrivate: isPrivate).opacity(0.35), radius: 8, y: 3)
        }
        .browserPressable()
        .accessibilityLabel("Tabs, \(count) open")
    }
}

struct BrowserStatusPill: View {
    let title: String
    var icon: String = "hand.raised.fill"
    var color: Color = BrowserTheme.privateAccent

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .overlay {
                Capsule().strokeBorder(color.opacity(0.22), lineWidth: 0.6)
            }
    }
}

struct BrowserEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: BrowserSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(BrowserTheme.accent.gradient)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(BrowserTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(BrowserTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(BrowserSpacing.xl + 8)
        .browserGlass(radius: BrowserRadius.card)
    }
}
