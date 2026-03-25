import SwiftUI
import Combine

// ╔══════════════════════════════════════════════════════════════════╗
// ║                     Hat · Design System                        ║
// ║  Single source of truth for all visual tokens and components.  ║
// ║  Inspired by Claude (Anthropic) — warm, minimal, adaptive.    ║
// ╚══════════════════════════════════════════════════════════════════╝

// MARK: - Font Extension (Cormorant Garamond)

extension Font {
    static func cormorantGaramond(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .light:    fontName = "CormorantGaramond-Light"
        case .medium:   fontName = "CormorantGaramond-Medium"
        case .semibold: fontName = "CormorantGaramond-SemiBold"
        case .bold:     fontName = "CormorantGaramond-Bold"
        default:        fontName = "CormorantGaramond-Regular"
        }
        return .custom(fontName, size: size)
    }
}

// MARK: - Adaptive Color Helper

extension Color {
    /// Creates a color that adapts to light/dark appearance automatically.
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. Design Tokens
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum Theme {

    // MARK: Colors — Claude-inspired warm palette
    enum Colors {
        // Backgrounds — warm cream (light) / warm dark (dark)
        static let background = Color.adaptive(
            light: Color(NSColor(red: 0.98, green: 0.976, blue: 0.965, alpha: 1.0)),  // #FAF9F6
            dark:  Color(NSColor(red: 0.102, green: 0.098, blue: 0.082, alpha: 1.0))  // #1A1915
        )
        static let backgroundSecondary = Color.adaptive(
            light: Color(NSColor(red: 0.941, green: 0.929, blue: 0.902, alpha: 1.0)), // #F0EDE6
            dark:  Color(NSColor(red: 0.078, green: 0.075, blue: 0.059, alpha: 1.0))  // #14130F
        )

        // Surfaces — flat, warm
        static let surface = Color.adaptive(
            light: Color.white,
            dark:  Color.white.opacity(0.05)
        )
        static let surfaceSecondary = Color.adaptive(
            light: Color(NSColor(red: 0.961, green: 0.949, blue: 0.922, alpha: 1.0)), // #F5F2EB
            dark:  Color.white.opacity(0.04)
        )
        static let surfaceElevated = Color.adaptive(
            light: Color.white,
            dark:  Color.white.opacity(0.07)
        )

        // Borders
        static let border = Color.adaptive(
            light: Color.black.opacity(0.08),
            dark:  Color.white.opacity(0.08)
        )
        static let borderHighlight = Color.adaptive(
            light: Color.black.opacity(0.12),
            dark:  Color.white.opacity(0.12)
        )
        static let borderFocused = Color(NSColor(red: 0.855, green: 0.467, blue: 0.337, alpha: 0.4)) // #DA7756 @ 40%

        // Text — warm tones
        static let textPrimary = Color.adaptive(
            light: Color(NSColor(red: 0.102, green: 0.098, blue: 0.082, alpha: 1.0)), // #1A1915
            dark:  Color(NSColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1.0))  // #F5F0E8
        )
        static let textSecondary = Color.adaptive(
            light: Color(NSColor(red: 0.420, green: 0.388, blue: 0.333, alpha: 1.0)), // #6B6355
            dark:  Color(NSColor(red: 0.722, green: 0.678, blue: 0.620, alpha: 1.0))  // #B8AD9E
        )
        static let textMuted = Color.adaptive(
            light: Color(NSColor(red: 0.612, green: 0.573, blue: 0.518, alpha: 1.0)), // #9C9284
            dark:  Color(NSColor(red: 0.478, green: 0.439, blue: 0.376, alpha: 1.0))  // #7A7060
        )

        // Accent — adaptive for buttons (dark text on light, cream on dark)
        static let accent = Color.adaptive(
            light: Color(NSColor(red: 0.102, green: 0.098, blue: 0.082, alpha: 1.0)), // #1A1915
            dark:  Color(NSColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1.0))  // #F5F0E8
        )
        static let accentSubtle = Color.adaptive(
            light: Color(NSColor(red: 0.855, green: 0.467, blue: 0.337, alpha: 0.10)),
            dark:  Color(NSColor(red: 0.855, green: 0.467, blue: 0.337, alpha: 0.15))
        )
        // Claude signature terracotta/orange
        static let accentOrange = Color(NSColor(red: 0.855, green: 0.467, blue: 0.337, alpha: 1.0)) // #DA7756
        // Warm sand secondary
        static let accentSand = Color(NSColor(red: 0.769, green: 0.659, blue: 0.510, alpha: 1.0))   // #C4A882

        // Semantic
        static let success = Color.adaptive(
            light: Color(NSColor(red: 0.302, green: 0.659, blue: 0.478, alpha: 1.0)), // #4DA87A
            dark:  Color(NSColor(red: 0.357, green: 0.725, blue: 0.549, alpha: 1.0))  // #5BB98C
        )
        static let error = Color.adaptive(
            light: Color(NSColor(red: 0.851, green: 0.310, blue: 0.310, alpha: 1.0)), // #D94F4F
            dark:  Color(NSColor(red: 0.878, green: 0.376, blue: 0.376, alpha: 1.0))  // #E06060
        )
        static let warning = Color.adaptive(
            light: Color(NSColor(red: 0.769, green: 0.580, blue: 0.251, alpha: 1.0)), // #C49440
            dark:  Color(NSColor(red: 0.831, green: 0.651, blue: 0.302, alpha: 1.0))  // #D4A04D
        )

        // Gradient helpers — orange to sand
        static let gradientStart = Color(NSColor(red: 0.855, green: 0.467, blue: 0.337, alpha: 1.0)) // #DA7756
        static let gradientEnd   = Color(NSColor(red: 0.769, green: 0.659, blue: 0.510, alpha: 1.0)) // #C4A882
        static let gradientSubtle = LinearGradient(
            colors: [gradientStart.opacity(0.04), gradientEnd.opacity(0.02)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Typography — SF Pro Rounded (Apple native)
    enum Typography {
        static let largeTitle    = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title         = Font.system(size: 22, weight: .bold, design: .rounded)
        static let heading       = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let subheading    = Font.system(size: 15, weight: .medium, design: .rounded)
        static let bodyBold      = Font.system(size: 14, weight: .medium, design: .rounded)
        static let body          = Font.system(size: 14, weight: .regular, design: .rounded)
        static let bodySmall     = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption       = Font.system(size: 11, weight: .regular, design: .rounded)
        static let captionBold   = Font.system(size: 11, weight: .semibold, design: .rounded)
        static let sectionHeader = Font.system(size: 11, weight: .semibold, design: .rounded)
        static let micro         = Font.system(size: 9, weight: .medium, design: .rounded)
    }

    // MARK: Metrics — generous breathing room
    enum Metrics {
        static let radiusSmall:  CGFloat = 8
        static let radiusMedium: CGFloat = 14
        static let radiusLarge:  CGFloat = 18

        static let spacingSmall:  CGFloat = 8
        static let spacingDefault: CGFloat = 14
        static let spacingLarge:  CGFloat = 20
        static let spacingXLarge: CGFloat = 28
    }

    // MARK: Shadows
    enum Shadows {
        static let soft   = (color: Color.black.opacity(0.08), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.12), radius: CGFloat(6), x: CGFloat(0), y: CGFloat(3))
    }

    // MARK: Animation
    enum Animation {
        // Durations
        static let durationFast:   Double = 0.2
        static let durationNormal: Double = 0.3
        static let durationSlow:   Double = 0.5

        // Springs — Core
        static let smooth  = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let gentle  = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let bouncy  = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.6)

        // Springs — Premium
        static let snappy     = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.82)
        static let responsive = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.75)
        static let expressive = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
        static let microBounce = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.65)

        // Easing
        static let hover   = SwiftUI.Animation.easeInOut(duration: durationFast)
        static let fade    = SwiftUI.Animation.easeOut(duration: 0.25)
        static let slowFade = SwiftUI.Animation.easeInOut(duration: 0.6)

        // Stagger helper — delay for item at index in a list
        static func staggerDelay(index: Int, base: Double = 0.04) -> SwiftUI.Animation {
            Theme.Animation.responsive.delay(Double(index) * base)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1.5. Standardized Transitions
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

extension AnyTransition {
    static var maeSlideIn: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    static var maePopIn: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.92)
                .combined(with: .opacity)
                .combined(with: .offset(y: 8)),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
    }

    static var maeScaleFade: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }

    static var maeSlideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    static var maeSlideFromLeading: AnyTransition {
        .move(edge: .leading).combined(with: .opacity)
    }

    static var maeFadeScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .scale(scale: 1.02).combined(with: .opacity)
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1.6. Animation View Modifiers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MaeHoverEffect: ViewModifier {
    var scale: CGFloat = 1.005
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .shadow(color: Theme.Colors.accent.opacity(isHovered ? 0.06 : 0), radius: 8)
            .onHover { hovering in
                withAnimation(Theme.Animation.snappy) {
                    isHovered = hovering
                }
            }
    }
}

struct MaeAppearAnimation: ViewModifier {
    var animation: SwiftUI.Animation = Theme.Animation.gentle
    var scale: CGFloat = 0.95
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : scale)
            .opacity(isVisible ? 1.0 : 0.0)
            .onAppear {
                withAnimation(animation) {
                    isVisible = true
                }
            }
    }
}

struct MaeStaggeredAppear: ViewModifier {
    var index: Int
    var baseDelay: Double = 0.04
    var offsetY: CGFloat = 12
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(y: isVisible ? 0 : offsetY)
            .onAppear {
                withAnimation(Theme.Animation.staggerDelay(index: index, base: baseDelay)) {
                    isVisible = true
                }
            }
    }
}

struct MaeButtonPressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .opacity(isPressed ? 0.85 : 1.0)
            .animation(Theme.Animation.snappy, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

struct MaeShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Theme.Colors.accentOrange.opacity(0.06),
                        Theme.Colors.accentOrange.opacity(0.12),
                        Theme.Colors.accentOrange.opacity(0.06),
                        .clear
                    ],
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.8)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2.0
                }
            }
    }
}

struct MaePulseEffect: ViewModifier {
    var minScale: CGFloat = 0.92
    var maxOpacity: Double = 1.0
    var minOpacity: Double = 0.6
    var duration: Double = 1.6
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.0 : minScale)
            .opacity(isPulsing ? maxOpacity : minOpacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

struct MaeFloatingEffect: ViewModifier {
    var amplitude: CGFloat = 6
    var duration: Double = 3.0
    @State private var isFloating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -amplitude : amplitude)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isFloating = true
                }
            }
    }
}

struct MaeGlowHoverEffect: ViewModifier {
    var glowColor: Color = Theme.Colors.accentOrange
    var glowRadius: CGFloat = 12
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .shadow(color: glowColor.opacity(isHovered ? 0.25 : 0), radius: glowRadius)
            .brightness(isHovered ? 0.03 : 0)
            .animation(Theme.Animation.responsive, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct MaeTypingDots: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let activeIndex = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 3

            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Theme.Colors.accentOrange.opacity(activeIndex == index ? 0.9 : 0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(activeIndex == index ? 1.3 : 1.0)
                        .animation(Theme.Animation.microBounce, value: activeIndex)
                }
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. View Modifiers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

extension View {

    /// Flat surface background — replaces glass effect
    func maeGlassBackground(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
    }

    /// Neutral surface with border (assistant bubbles, cards)
    func maeSurfaceBackground(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
    }

    /// Standard card shape: surfaceSecondary + border
    func maeCardStyle(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background(Theme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }

    /// Text input style — flat solid background
    func maeInputStyle(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .textFieldStyle(.plain)
            .font(Theme.Typography.bodySmall)
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
    }

    /// Opaque text input style (same as maeInputStyle in flat design)
    func maeInputStyleOpaque(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .textFieldStyle(.plain)
            .font(Theme.Typography.bodySmall)
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
    }

    func maeSoftShadow() -> some View {
        let s = Theme.Shadows.soft
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    func maeMediumShadow() -> some View {
        let s = Theme.Shadows.medium
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    func maeHover(scale: CGFloat = 1.005) -> some View {
        self.modifier(MaeHoverEffect(scale: scale))
    }

    func maeAppearAnimation(animation: SwiftUI.Animation = Theme.Animation.gentle, scale: CGFloat = 0.95) -> some View {
        self.modifier(MaeAppearAnimation(animation: animation, scale: scale))
    }

    func maeStaggered(index: Int, baseDelay: Double = 0.04) -> some View {
        self.modifier(MaeStaggeredAppear(index: index, baseDelay: baseDelay))
    }

    func maePressEffect() -> some View {
        self.modifier(MaeButtonPressEffect())
    }

    func maeShimmer() -> some View {
        self.modifier(MaeShimmerEffect())
    }

    func maePulse(duration: Double = 1.6) -> some View {
        self.modifier(MaePulseEffect(duration: duration))
    }

    func maeFloating(amplitude: CGFloat = 6, duration: Double = 3.0) -> some View {
        self.modifier(MaeFloatingEffect(amplitude: amplitude, duration: duration))
    }

    func maeGlowHover(color: Color = Theme.Colors.accentOrange) -> some View {
        self.modifier(MaeGlowHoverEffect(glowColor: color))
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. Reusable Components
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MaeDivider: View {
    var body: some View {
        Divider().background(Theme.Colors.border)
    }
}

struct MaeGradientDivider: View {
    var tinted: Bool = false

    var body: some View {
        LinearGradient(
            colors: tinted
                ? [.clear, Theme.Colors.gradientStart.opacity(0.2), Theme.Colors.gradientEnd.opacity(0.2), .clear]
                : [.clear, Theme.Colors.border, .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

struct MaeCardStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.content
        }
        .background(Theme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

struct MaeSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(Theme.Typography.sectionHeader)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.bottom, 4)
            .padding(.top, 16)
            .padding(.horizontal, 4)
    }
}

struct MaeActionRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = Theme.Colors.accentOrange
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce, value: appeared)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
                    .onAppear { appeared = true }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle != nil ? "\(title), \(subtitle!)" : title)
    }
}

struct MaeIconButton: View {
    let icon: String
    var size: CGFloat = 16
    var color: Color = Theme.Colors.textSecondary
    var bgColor: Color = .clear
    var helpText: String? = nil
    let action: () -> Void
    @State private var tapCount: Int = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: tapCount)
                .padding(bgColor == .clear ? 6 : 8)
                .background(bgColor)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(helpText ?? "")
        .accessibilityLabel(helpText ?? "")
    }
}

struct MaePageBackground: View {
    var showGlow: Bool = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            if showGlow {
                RadialGradient(
                    gradient: Gradient(colors: [Theme.Colors.accentOrange.opacity(0.04), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 400
                )
            } else {
                RadialGradient(
                    gradient: Gradient(colors: [Theme.Colors.accentSand.opacity(0.02), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 400
                )
            }
        }
    }
}

struct MaeTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...1

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .maeInputStyle()
            .lineLimit(lineLimit)
    }
}

struct MaeStatusBadge: View {
    let label: String
    var color: Color = Theme.Colors.success
    var isActive: Bool = true

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color.opacity(isActive ? 0.9 : 0.4))
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(isActive ? 0.5 : 0), radius: 3)
                .maePulse(duration: isActive ? 2.0 : 0)

            Text(label)
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.surfaceSecondary)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.Colors.border, lineWidth: 0.5))
    }
}

struct MaeAccentGradient: View {
    var opacity: Double = 1.0

    var body: some View {
        LinearGradient(
            colors: [Theme.Colors.gradientStart, Theme.Colors.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(opacity)
    }
}

struct MaeChip: View {
    let label: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Theme.Colors.background : Theme.Colors.textPrimary.opacity(0.9))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.Colors.accentOrange : Theme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Theme.Colors.accentOrange.opacity(0.5) : Theme.Colors.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct MaeEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.accentOrange.opacity(0.04))
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(Theme.Colors.surfaceSecondary)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(Theme.Colors.border, lineWidth: 0.5))
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Theme.Colors.accentOrange.opacity(0.5))
            }
            .maeFloating(amplitude: 4, duration: 4.0)

            VStack(spacing: 6) {
                Text(title)
                    .font(Theme.Typography.heading)
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.8))

                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

struct MaeDateSeparator: View {
    let date: Date

    private var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoje" }
        if calendar.isDateInYesterday(date) { return "Ontem" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 8) {
            capsuleLine
            Text(label)
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Colors.textMuted)
            capsuleLine
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 24)
    }

    private var capsuleLine: some View {
        Rectangle()
            .fill(Theme.Colors.border)
            .frame(height: 0.5)
    }
}

struct MaeActionButton: View {
    let label: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(label)
                    .font(Theme.Typography.bodyBold)
            }
            .foregroundStyle(Theme.Colors.background)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                    .fill(Theme.Colors.accent.opacity(0.9))
            )
        }
        .buttonStyle(.plain)
        .maeGlowHover()
        .maePressEffect()
    }
}

struct MaeGradientBorderModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.Metrics.radiusMedium
    var lineWidth: CGFloat = 1.0
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Theme.Colors.gradientStart.opacity(0.4),
                                Theme.Colors.gradientEnd.opacity(0.2),
                                Theme.Colors.gradientStart.opacity(0.1),
                                Theme.Colors.gradientEnd.opacity(0.4),
                                Theme.Colors.gradientStart.opacity(0.4)
                            ],
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: lineWidth
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

extension View {
    func maeGradientBorder(cornerRadius: CGFloat = Theme.Metrics.radiusMedium, lineWidth: CGFloat = 1.0) -> some View {
        self.modifier(MaeGradientBorderModifier(cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}

struct MaeTooltipButton: View {
    let icon: String
    var size: CGFloat = 13
    var helpText: String
    var action: () -> Void
    @State private var isHovered = false
    @State private var tapCount: Int = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .symbolEffect(.bounce, value: tapCount)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Theme.Colors.surfaceSecondary : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.Animation.hover) { isHovered = hovering }
        }
        .help(helpText)
        .accessibilityLabel(helpText)
    }
}
