import SwiftUI
import Combine

// ╔══════════════════════════════════════════════════════════════════╗
// ║                     Hat · Design System                        ║
// ║  Single source of truth for all visual tokens and components.  ║
// ║  Minimal, warm, refined — inspired by Notion, Linear, Raycast ║
// ╚══════════════════════════════════════════════════════════════════╝

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

    // MARK: Colors — Warm neutrals + refined indigo accent
    enum Colors {
        // Backgrounds — warm blacks
        static let background = Color.adaptive(
            light: Color(NSColor(red: 0.973, green: 0.973, blue: 0.969, alpha: 1.0)),   // #F8F8F7
            dark:  Color(NSColor(red: 0.047, green: 0.047, blue: 0.055, alpha: 1.0))     // #0C0C0E
        )
        static let backgroundSecondary = Color.adaptive(
            light: Color(NSColor(red: 0.949, green: 0.949, blue: 0.945, alpha: 1.0)),    // #F2F2F1
            dark:  Color(NSColor(red: 0.067, green: 0.067, blue: 0.078, alpha: 1.0))     // #111114
        )

        // Surfaces — layered depth with warm undertone
        static let surface = Color.adaptive(
            light: Color.white,
            dark:  Color(NSColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0))     // #1C1C1E
        )
        static let surfaceSecondary = Color.adaptive(
            light: Color(NSColor(red: 0.953, green: 0.953, blue: 0.953, alpha: 1.0)),    // #F3F3F3
            dark:  Color.white.opacity(0.055)
        )
        static let surfaceTertiary = Color.adaptive(
            light: Color(NSColor(red: 0.929, green: 0.929, blue: 0.929, alpha: 1.0)),    // #EDEDED
            dark:  Color.white.opacity(0.035)
        )
        static let surfaceElevated = Color.adaptive(
            light: Color.white,
            dark:  Color.white.opacity(0.08)
        )
        static let surfaceHover = Color.adaptive(
            light: Color.black.opacity(0.04),
            dark:  Color.white.opacity(0.06)
        )

        // Borders — subtle
        static let border = Color.adaptive(
            light: Color.black.opacity(0.08),
            dark:  Color.white.opacity(0.07)
        )
        static let borderHighlight = Color.adaptive(
            light: Color.black.opacity(0.12),
            dark:  Color.white.opacity(0.10)
        )
        static var borderFocused: Color { accentPrimary.opacity(0.50) }

        // Text — clean hierarchy
        static let textPrimary = Color.adaptive(
            light: Color(NSColor(red: 0.106, green: 0.106, blue: 0.118, alpha: 1.0)),    // #1B1B1E
            dark:  Color(NSColor(red: 0.933, green: 0.933, blue: 0.941, alpha: 1.0))     // #EEEEFO
        )
        static let textSecondary = Color.adaptive(
            light: Color(NSColor(red: 0.376, green: 0.376, blue: 0.400, alpha: 1.0)),    // #606066
            dark:  Color(NSColor(red: 0.780, green: 0.780, blue: 0.800, alpha: 1.0))     // #C7C7CC
        )
        static let textMuted = Color.adaptive(
            light: Color(NSColor(red: 0.502, green: 0.502, blue: 0.522, alpha: 1.0)),    // #808085
            dark:  Color(NSColor(red: 0.620, green: 0.620, blue: 0.645, alpha: 1.0))     // #9E9EA5
        )

        // Accent — adaptive for buttons (dark text on light, light text on dark)
        static let accent = Color.adaptive(
            light: Color(NSColor(red: 0.106, green: 0.106, blue: 0.118, alpha: 1.0)),    // #1B1B1E
            dark:  Color(NSColor(red: 0.933, green: 0.933, blue: 0.941, alpha: 1.0))     // #EEEEF0
        )
        static var accentSubtle: Color {
            Color.adaptive(
                light: accentPrimary.opacity(0.08),
                dark:  accentPrimary.opacity(0.12)
            )
        }
        // Primary accent — user-customizable via AppTheme preset
        static var accentPrimary: Color {
            AppTheme.current.color
        }
        static var accentPrimaryHover: Color {
            AppTheme.current.hoverColor
        }

        // Input — dedicated input background
        static let inputBackground = Color.adaptive(
            light: Color(NSColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1.0)),    // #F4F4F4
            dark:  Color.white.opacity(0.055)
        )

        // Semantic — muted, professional
        static let success = Color(NSColor(red: 0.204, green: 0.780, blue: 0.549, alpha: 1.0)) // #34C78C
        static let error   = Color(NSColor(red: 0.937, green: 0.388, blue: 0.388, alpha: 1.0)) // #EF6363
        static let warning = Color(NSColor(red: 0.949, green: 0.694, blue: 0.251, alpha: 1.0)) // #F2B140

        // Glass surfaces — semi-transparent overlays on blur
        static let glassSurface = Color.adaptive(
            light: Color.white.opacity(0.45),
            dark:  Color.white.opacity(0.15)
        )
        static let glassSurfaceSecondary = Color.adaptive(
            light: Color.white.opacity(0.30),
            dark:  Color.white.opacity(0.10)
        )
        static let glassSurfaceElevated = Color.adaptive(
            light: Color.white.opacity(0.55),
            dark:  Color.white.opacity(0.18)
        )

        // Glass borders — light highlight strokes on frosted surfaces
        static let glassBorder = Color.adaptive(
            light: Color.white.opacity(0.60),
            dark:  Color.white.opacity(0.25)
        )
        static let glassBorderSubtle = Color.adaptive(
            light: Color.white.opacity(0.35),
            dark:  Color.white.opacity(0.15)
        )
    }

    // MARK: Typography — SF Pro (default system)
    enum Typography {
        static let largeTitle    = Font.system(size: 26, weight: .bold)
        static let title         = Font.system(size: 20, weight: .bold)
        static let heading       = Font.system(size: 16, weight: .semibold)
        static let subheading    = Font.system(size: 14, weight: .medium)
        static let bodyBold      = Font.system(size: 13, weight: .medium)
        static let body          = Font.system(size: 13, weight: .regular)
        static let bodySmall     = Font.system(size: 12.5, weight: .regular)
        static let bodyMono      = Font.system(size: 12, weight: .regular, design: .monospaced)
        static let caption       = Font.system(size: 11, weight: .regular)
        static let captionBold   = Font.system(size: 11, weight: .semibold)
        static let sectionHeader = Font.system(size: 11, weight: .medium)
        static let micro         = Font.system(size: 10, weight: .medium)
        static let codeBlock     = Font.system(size: 12, weight: .regular, design: .monospaced)
    }

    // MARK: Metrics — generous breathing room
    enum Metrics {
        static let radiusSmall:   CGFloat = 8
        static let radiusMedium:  CGFloat = 12
        static let radiusLarge:   CGFloat = 16
        static let radiusXLarge:  CGFloat = 20

        static let spacingXSmall:  CGFloat = 4
        static let spacingSmall:   CGFloat = 8
        static let spacingDefault: CGFloat = 16
        static let spacingLarge:   CGFloat = 24
        static let spacingXLarge:  CGFloat = 32
        static let spacingSection: CGFloat = 40

        // Layout
        static let sidebarWidth:      CGFloat = 220
        static let chatMaxWidth:      CGFloat = 680
        static let inputCornerRadius: CGFloat = 16
    }

    // MARK: Shadows — subtle elevation
    enum Shadows {
        static let soft     = (color: Color.black.opacity(0.06), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium   = (color: Color.black.opacity(0.10), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(3))
        static let elevated = (color: Color.black.opacity(0.14), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(6))
        static let glass    = (color: Color.black.opacity(0.20), radius: CGFloat(20), x: CGFloat(0), y: CGFloat(8))
    }

    // MARK: Animation — refined, professional
    enum Animation {
        static let durationFast:   Double = 0.15
        static let durationNormal: Double = 0.25
        static let durationSlow:   Double = 0.4

        // Springs — Core set (high damping = professional, no bounce)
        static let smooth  = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.88)
        static let snappy  = SwiftUI.Animation.spring(response: 0.22, dampingFraction: 0.9)
        static let gentle  = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.86)
        static let quickSnap = SwiftUI.Animation.spring(response: 0.16, dampingFraction: 0.92)

        // Easing
        static let hover   = SwiftUI.Animation.easeInOut(duration: durationFast)
        static let fade    = SwiftUI.Animation.easeOut(duration: 0.2)
        static let slowFade = SwiftUI.Animation.easeInOut(duration: 0.5)

        // Stagger helper
        static func staggerDelay(index: Int, base: Double = 0.04) -> SwiftUI.Animation {
            Theme.Animation.smooth.delay(Double(index) * base)
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
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        )
    }

    static var maeScaleFade: AnyTransition {
        .scale(scale: 0.94).combined(with: .opacity)
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

    static var maeFade: AnyTransition {
        .opacity
    }

    static var maeFadeScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.97).combined(with: .opacity),
            removal: .scale(scale: 1.01).combined(with: .opacity)
        )
    }

    // Lightweight transitions — no blur (GPU-expensive)
    static var maeBlurIn: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.97).combined(with: .opacity),
            removal: .opacity
        )
    }

    static var maeIrisIn: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1.6. Animation View Modifiers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MaeHoverEffect: ViewModifier {
    var scale: CGFloat = 1.0
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .onHover { hovering in
                withAnimation(Theme.Animation.snappy) {
                    isHovered = hovering
                }
            }
    }
}

struct MaeAppearAnimation: ViewModifier {
    var animation: SwiftUI.Animation = Theme.Animation.gentle
    var scale: CGFloat = 0.97
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
    var offsetY: CGFloat = 8
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
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(Theme.Animation.quickSnap, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

struct MaePulseEffect: ViewModifier {
    var minScale: CGFloat = 0.95
    var maxOpacity: Double = 1.0
    var minOpacity: Double = 0.65
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
            .onDisappear {
                isPulsing = false
            }
    }
}

struct MaeTypingDots: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let activeIndex = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 3

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Theme.Colors.accentPrimary.opacity(activeIndex == index ? 0.85 : 0.25))
                        .frame(width: 5, height: 5)
                        .scaleEffect(activeIndex == index ? 1.2 : 1.0)
                        .animation(Theme.Animation.snappy, value: activeIndex)
                }
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1.7. Glass Primitives
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct GlassBackground: View {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var overlayColor: Color = Theme.Colors.glassSurface
    var cornerRadius: CGFloat = Theme.Metrics.radiusMedium
    var borderColor: Color = Theme.Colors.glassBorder
    var borderWidth: CGFloat = 0.5

    var body: some View {
        ZStack {
            VisualEffectView(material: material, blendingMode: blendingMode)
            overlayColor
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. View Modifiers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

extension View {

    /// Frosted glass background with blur + semi-transparent overlay + border
    func maeGlassBackground(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background {
                GlassBackground(
                    material: .hudWindow,
                    blendingMode: .withinWindow,
                    overlayColor: Theme.Colors.glassSurface,
                    cornerRadius: cornerRadius,
                    borderColor: Theme.Colors.glassBorder,
                    borderWidth: 1.0
                )
            }
    }

    /// Glass surface for headers/toolbars — slightly more opaque
    func maeSurfaceBackground(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background {
                GlassBackground(
                    material: .hudWindow,
                    blendingMode: .withinWindow,
                    overlayColor: Theme.Colors.glassSurfaceElevated,
                    cornerRadius: cornerRadius,
                    borderColor: Theme.Colors.glassBorderSubtle,
                    borderWidth: 0.5
                )
            }
    }

    /// Glass card: lighter blur for content cards
    func maeCardStyle(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background {
                GlassBackground(
                    material: .hudWindow,
                    blendingMode: .withinWindow,
                    overlayColor: Theme.Colors.glassSurfaceSecondary,
                    cornerRadius: cornerRadius,
                    borderColor: Theme.Colors.glassBorderSubtle,
                    borderWidth: 1.0
                )
            }
    }

    /// Clean glass card: no border stroke
    func maeCleanCard(color: Color = Theme.Colors.glassSurfaceSecondary, cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background {
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    color
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
    }

    /// Glass text input style
    func maeInputStyle(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .textFieldStyle(.plain)
            .font(Theme.Typography.bodySmall)
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                GlassBackground(
                    material: .hudWindow,
                    blendingMode: .withinWindow,
                    overlayColor: Theme.Colors.glassSurfaceElevated,
                    cornerRadius: cornerRadius,
                    borderColor: Theme.Colors.glassBorderSubtle,
                    borderWidth: 0.5
                )
            }
    }

    /// Opaque text input style — keeps solid background for text readability
    func maeInputStyleOpaque(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .textFieldStyle(.plain)
            .font(Theme.Typography.bodySmall)
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.Colors.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
    }

    /// Accent-tinted glass — for user chat bubbles, highlighted badges
    func maeAccentGlass(cornerRadius: CGFloat = 14) -> some View {
        self
            .background {
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    Theme.Colors.accentPrimary.opacity(0.15)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Theme.Colors.accentPrimary.opacity(0.25), lineWidth: 1.0)
                )
            }
    }

    func maeGlassShadow() -> some View {
        let s = Theme.Shadows.glass
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    func maeSoftShadow() -> some View {
        let s = Theme.Shadows.soft
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    func maeMediumShadow() -> some View {
        let s = Theme.Shadows.medium
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    func maeElevatedShadow() -> some View {
        let s = Theme.Shadows.elevated
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    func maeHover(scale: CGFloat = 1.0) -> some View {
        self.modifier(MaeHoverEffect(scale: scale))
    }

    func maeAppearAnimation(animation: SwiftUI.Animation = Theme.Animation.gentle, scale: CGFloat = 0.97) -> some View {
        self.modifier(MaeAppearAnimation(animation: animation, scale: scale))
    }

    func maeStaggered(index: Int, baseDelay: Double = 0.04) -> some View {
        self.modifier(MaeStaggeredAppear(index: index, baseDelay: baseDelay))
    }

    func maePressEffect() -> some View {
        self.modifier(MaeButtonPressEffect())
    }

    func maePulse(duration: Double = 1.6) -> some View {
        self.modifier(MaePulseEffect(duration: duration))
    }

}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. Reusable Components
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MaeDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.border)
            .frame(height: 0.5)
    }
}

struct MaeCardStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.content
        }
        .background {
            GlassBackground(
                material: .hudWindow,
                blendingMode: .withinWindow,
                overlayColor: Theme.Colors.glassSurfaceSecondary,
                cornerRadius: Theme.Metrics.radiusMedium,
                borderColor: Theme.Colors.glassBorderSubtle,
                borderWidth: 1.0
            )
        }
    }
}

struct MaeSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(Theme.Typography.micro)
            .foregroundStyle(Theme.Colors.textMuted)
            .tracking(0.5)
            .padding(.bottom, 6)
            .padding(.top, 14)
            .padding(.horizontal, 4)
    }
}

struct MaeActionRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = Theme.Colors.accentPrimary
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce, value: appeared)
                    .frame(width: 28, height: 28)
                    .background { (iconColor.opacity(0.08) as Color) }
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .maeGlow(color: iconColor)
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
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
    }
}

struct MaeIconButton: View {
    let icon: String
    var size: CGFloat = 14
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
                .frame(width: 32, height: 32)
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
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .behindWindow
            )
            Theme.Colors.background.opacity(0.35)
        }
        .ignoresSafeArea()
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
                .fill(color.opacity(isActive ? 0.85 : 0.35))
                .frame(width: 5, height: 5)
                .maePulse(duration: isActive ? 2.0 : 0)

            Text(label)
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.Colors.glassBorderSubtle, lineWidth: 0.5))
    }
}

struct MaeChip: View {
    let label: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Theme.Colors.accentPrimary)
                    } else {
                        ZStack {
                            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                            Theme.Colors.glassSurfaceSecondary
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isSelected ? Color.clear : Theme.Colors.glassBorderSubtle, lineWidth: 0.5)
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
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(Theme.Colors.accentPrimary.opacity(0.04)))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.65))
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(Theme.Typography.heading)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
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
        HStack(spacing: 10) {
            capsuleLine
            Text(label)
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Colors.textMuted)
            capsuleLine
        }
        .padding(.vertical, 14)
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
    var style: ActionButtonStyle = .primary
    let action: () -> Void

    enum ActionButtonStyle {
        case primary, accent
    }

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
            .foregroundStyle(style == .accent ? .white : Theme.Colors.background)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                    .fill(style == .accent
                        ? AnyShapeStyle(Theme.Colors.accentPrimary)
                        : AnyShapeStyle(Theme.Colors.accent.opacity(0.9))
                    )
            )
        }
        .buttonStyle(.plain)
        .maePressEffect()
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
                        .fill(isHovered ? Theme.Colors.glassSurface : Color.clear)
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 4. Additional Components
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MaeProgressBar: View {
    let value: CGFloat  // 0...1
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.Colors.surfaceTertiary)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.Colors.accentPrimary)
                    .frame(width: max(height, geo.size.width * min(value, 1.0)))
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 2))
    }
}

struct MaeTag: View {
    let label: String
    var icon: String? = nil
    var color: Color = Theme.Colors.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
            }
            Text(label)
                .font(Theme.Typography.micro)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct MaeScrollToBottomButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .background(.thinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.Colors.glassBorderSubtle, lineWidth: 0.5))
                .scaleEffect(isHovered ? 1.03 : 1.0)
                .maeSoftShadow()
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.Animation.quickSnap) { isHovered = hovering }
        }
    }
}

extension View {
    /// Neon glow effect — colored shadow behind the view
    func maeGlow(color: Color = Theme.Colors.accentPrimary, radius: CGFloat = 6, opacity: Double = 0.4) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius)
    }
}
