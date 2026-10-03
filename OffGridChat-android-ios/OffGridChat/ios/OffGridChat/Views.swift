import SwiftUI
import UIKit
import DotLottie

// =====================================================================================
// OffGrid Chat: Liquid Glass UI (presentation layer only)
//
// - MeshEngine, Crypto, QR, transport, chat, SOS and navigation behavior are unchanged.
// - MeshEngine / PeerView / TransportInfo / MsgStatus / ChatMessage / ROOM_ID /
//   EMERGENCY_ID / Crypto / QRScannerView / qrImage are defined elsewhere and untouched.
// =====================================================================================


// MARK: - App Themes & Configuration

enum AppThemeStyle: String, CaseIterable, Identifiable {
    case midnightBlue = "Midnight Blue"
    case obsidianTeal = "Obsidian Teal"

    var id: String {
        rawValue
    }
}

struct ThemeManager {
    static let key = "selectedTheme"

    static var currentTheme: AppThemeStyle {
        get {
            let rawValue = UserDefaults.standard.string(forKey: key)
                ?? AppThemeStyle.midnightBlue.rawValue

            return AppThemeStyle(rawValue: rawValue) ?? .midnightBlue
        }

        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

struct Theme {

    static var base: Color {
        switch ThemeManager.currentTheme {

        case .midnightBlue:
            return Color(
                red: 0.02,
                green: 0.02,
                blue: 0.08
            )

        case .obsidianTeal:
            return Color(
                red: 0.01,
                green: 0.05,
                blue: 0.06
            )
        }
    }

    static var accent: Color {
        switch ThemeManager.currentTheme {

        case .midnightBlue:
            return Color(
                red: 0.20,
                green: 0.55,
                blue: 1.00
            )

        case .obsidianTeal:
            return Color(
                red: 0.00,
                green: 0.85,
                blue: 0.75
            )
        }
    }

    static var secondaryAccent: Color {
        switch ThemeManager.currentTheme {

        case .midnightBlue:
            return Color(
                red: 0.55,
                green: 0.30,
                blue: 0.95
            )

        case .obsidianTeal:
            return Color(
                red: 0.10,
                green: 0.50,
                blue: 0.60
            )
        }
    }

    static var mint: Color {
        Color(
            red: 0.30,
            green: 0.92,
            blue: 0.65
        )
    }

    static var danger: Color {
        Color(
            red: 1.00,
            green: 0.30,
            blue: 0.40
        )
    }

    static var outgoing: LinearGradient {
        switch ThemeManager.currentTheme {

        case .midnightBlue:
            return LinearGradient(
                colors: [
                    Color(
                        red: 0.15,
                        green: 0.50,
                        blue: 1.0
                    ),
                    Color(
                        red: 0.45,
                        green: 0.28,
                        blue: 0.95
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .obsidianTeal:
            return LinearGradient(
                colors: [
                    Color(
                        red: 0.00,
                        green: 0.70,
                        blue: 0.65
                    ),
                    Color(
                        red: 0.05,
                        green: 0.35,
                        blue: 0.55
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Darker accent used to tint outgoing glass bubbles so white text stays legible.
    static var outgoingTint: Color {
        switch ThemeManager.currentTheme {

        case .midnightBlue:
            return Color(
                red: 0.12,
                green: 0.42,
                blue: 0.95
            )

        case .obsidianTeal:
            return Color(
                red: 0.00,
                green: 0.52,
                blue: 0.52
            )
        }
    }

    static var title: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                accent,
                secondaryAccent
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}


// MARK: - Haptics

enum Haptics {

    static func tap() {
        UIImpactFeedbackGenerator(
            style: .light
        ).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator()
            .notificationOccurred(.warning)
    }
}


// MARK: - Motion

enum Motion {

    static let quick =
        Animation.easeInOut(duration: 0.25)

    static let standard =
        Animation.easeInOut(duration: 0.30)

    static let theme =
        Animation.easeInOut(duration: 0.30)
}


// MARK: - Motion Animation Modifier

struct MotionAnimationModifier<Value: Equatable>: ViewModifier {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {

        content.animation(
            reduceMotion
                ? Animation.easeInOut(duration: 0.15)
                : animation,
            value: value
        )
    }
}


// MARK: - Motion Transition Modifier

struct MotionTransitionModifier: ViewModifier {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let transition: AnyTransition

    func body(content: Content) -> some View {

        content.transition(
            reduceMotion
                ? AnyTransition.opacity
                : transition
        )
    }
}


extension View {

    func motion<Value: Equatable>(
        _ animation: Animation = Motion.standard,
        value: Value
    ) -> some View {

        modifier(
            MotionAnimationModifier(
                animation: animation,
                value: value
            )
        )
    }

    func motionTransition(
        _ transition: AnyTransition
    ) -> some View {

        modifier(
            MotionTransitionModifier(
                transition: transition
            )
        )
    }

    @ViewBuilder
    func symbolReplace() -> some View {

        if #available(iOS 17.0, *) {

            self.contentTransition(
                .symbolEffect(.replace)
            )

        } else {

            self
        }
    }
}


// MARK: - Liquid Glass

enum GlassSurfaceStyle {
    case regular
    case clear
}


#if compiler(>=6.2)

@available(iOS 26.0, *)
private func makeGlass(
    style: GlassSurfaceStyle,
    tint: Color?,
    interactive: Bool
) -> Glass {

    var glass: Glass

    switch style {

    case .regular:
        glass = .regular

    case .clear:
        glass = .clear
    }

    if let tint {
        glass = glass.tint(tint)
    }

    if interactive {
        glass = glass.interactive()
    }

    return glass
}

@available(iOS 26.0, *)
private func makeGlass(
    tint: Color?,
    interactive: Bool
) -> Glass {

    makeGlass(
        style: .regular,
        tint: tint,
        interactive: interactive
    )
}

#endif


// MARK: - Glass Edge

private struct GlassEdge<ShapeType: InsettableShape>: View {

    let shape: ShapeType

    var body: some View {

        shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.30),
                        Color.white.opacity(0.06),
                        Color.black.opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.75
            )
            .allowsHitTesting(false)
    }
}


// MARK: - Glass Surface

struct GlassSurface<ShapeType: InsettableShape>: ViewModifier {

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    let shape: ShapeType

    var style: GlassSurfaceStyle = .regular
    var tint: Color? = nil
    var interactive: Bool = false

    @ViewBuilder
    func body(content: Content) -> some View {

        if reduceTransparency {

            content
                .background(
                    shape.fill(
                        tint == nil
                            ? Theme.base.opacity(0.94)
                            : (tint ?? Theme.base).opacity(0.92)
                    )
                )
                .overlay(
                    GlassEdge(shape: shape)
                )

        } else {

            glass(content)
        }
    }

    @ViewBuilder
    private func glass(
        _ content: Content
    ) -> some View {

        #if compiler(>=6.2)

        if #available(iOS 26.0, *) {

            content
                .glassEffect(
                    makeGlass(
                        style: style,
                        tint: tint,
                        interactive: interactive
                    ),
                    in: shape
                )
                .overlay(
                    GlassEdge(shape: shape)
                )

        } else {

            content.frostedSurface(
                in: shape,
                tint: tint
            )
        }

        #else

        content.frostedSurface(
            in: shape,
            tint: tint
        )

        #endif
    }
}


// MARK: - Glass Extensions

extension View {

    /// Material fallback for systems below iOS 26.
    func frostedSurface<ShapeType: InsettableShape>(
        in shape: ShapeType,
        tint: Color?
    ) -> some View {

        self
            .background(
                .ultraThinMaterial,
                in: shape
            )
            .background(
                shape.fill(
                    (tint ?? Color.white).opacity(
                        tint == nil
                            ? 0.06
                            : 0.20
                    )
                )
            )
            .overlay(
                GlassEdge(shape: shape)
            )
            .shadow(
                color: Color.black.opacity(0.24),
                radius: 12,
                y: 6
            )
    }

    func glassSurface<ShapeType: InsettableShape>(
        shape: ShapeType,
        style: GlassSurfaceStyle = .regular,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {

        modifier(
            GlassSurface(
                shape: shape,
                style: style,
                tint: tint,
                interactive: interactive
            )
        )
    }

    func glassCard(
        cornerRadius: CGFloat = 24,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {

        glassSurface(
            shape: RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            ),
            tint: tint,
            interactive: interactive
        )
    }

    func glassCapsule(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {

        glassSurface(
            shape: Capsule(
                style: .continuous
            ),
            tint: tint,
            interactive: interactive
        )
    }

    func glassCircle(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {

        glassSurface(
            shape: Circle(),
            tint: tint,
            interactive: interactive
        )
    }

    /// Kept for compatibility with the original file.
    fileprivate func frostedGlass(
        cornerRadius: CGFloat,
        tint: Color?
    ) -> some View {

        frostedSurface(
            in: RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            ),
            tint: tint
        )
    }

    /// Gives a Liquid Glass element a stable identity and transition.
    @ViewBuilder
    func glassMorph(
        id: String,
        in namespace: Namespace.ID?
    ) -> some View {

        #if compiler(>=6.2)

        if #available(iOS 26.0, *),
           let namespace {

            GlassMorphView(
                content: self,
                id: id,
                namespace: namespace
            )

        } else {

            self
        }

        #else

        self

        #endif
    }

    /// Non-glass input surface used inside a glass card.
    /// This avoids unnecessary glass-on-glass stacking.
    func fieldSurface() -> some View {

        self
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        Color.white.opacity(0.10)
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(0.14),
                        lineWidth: 0.5
                    )
            )
    }
}


// MARK: - Glass Morph View

#if compiler(>=6.2)

@available(iOS 26.0, *)
private struct GlassMorphView<Content: View>: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let content: Content
    let id: String
    let namespace: Namespace.ID

    var body: some View {

        if reduceMotion {

            content
                .glassEffectID(
                    id,
                    in: namespace
                )
                .glassEffectTransition(
                    .identity
                )

        } else {

            content
                .glassEffectID(
                    id,
                    in: namespace
                )
                .glassEffectTransition(
                    .materialize
                )
        }
    }
}

#endif


// MARK: - Glass Group

struct GlassGroup<Content: View>: View {

    let spacing: CGFloat
    let content: () -> Content

    init(
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {

        #if compiler(>=6.2)

        if #available(iOS 26.0, *) {

            GlassEffectContainer(
                spacing: spacing
            ) {
                content()
            }

        } else {

            content()
        }

        #else

        content()

        #endif
    }
}


// MARK: - Button Styles

struct GlassButtonStyle: ButtonStyle {

    var tint: Color? = nil

    func makeBody(
        configuration: Configuration
    ) -> some View {

        GlassButtonBody(
            configuration: configuration,
            tint: tint
        )
    }
}


private struct GlassButtonBody: View {

    let configuration: ButtonStyleConfiguration
    let tint: Color?

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @ScaledMetric(relativeTo: .body)
    private var minHeight: CGFloat = 44

    var body: some View {

        configuration.label
            .font(
                .system(
                    .body,
                    design: .rounded
                )
                .weight(.semibold)
            )
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: minHeight)
            .glassCapsule(
                tint: tint,
                interactive: true
            )
            .scaleEffect(
                configuration.isPressed && !reduceMotion
                    ? 0.96
                    : 1
            )
            .animation(
                Motion.quick,
                value: configuration.isPressed
            )
    }
}


struct PressableStyle: ButtonStyle {

    func makeBody(
        configuration: Configuration
    ) -> some View {

        configuration.label
            .scaleEffect(
                configuration.isPressed
                    ? 0.98
                    : 1
            )
            .opacity(
                configuration.isPressed
                    ? 0.90
                    : 1
            )
            .animation(
                Motion.quick,
                value: configuration.isPressed
            )
    }
}


// MARK: - App Background

struct AppBackground: View {

    var body: some View {

        ZStack {

            Theme.base

            switch ThemeManager.currentTheme {

            case .midnightBlue:
                MidnightBlueWaveBackground()

            case .obsidianTeal:
                ObsidianTealTubeBackground()
            }
        }
        .ignoresSafeArea()
    }
}


// MARK: - Midnight Blue Background

struct MidnightBlueWaveBackground: View {

    var body: some View {

        GeometryReader { geo in

            let width = max(
                geo.size.width,
                1
            )

            let height = max(
                geo.size.height,
                1
            )

            ZStack {

                Circle()
                    .fill(
                        Color(
                            red: 0.05,
                            green: 0.35,
                            blue: 0.85
                        )
                        .opacity(0.45)
                    )
                    .frame(
                        width: width,
                        height: width
                    )
                    .blur(radius: 75)
                    .position(
                        x: width * 0.22,
                        y: height * 0.14
                    )

                Circle()
                    .fill(
                        Color(
                            red: 0.30,
                            green: 0.15,
                            blue: 0.70
                        )
                        .opacity(0.40)
                    )
                    .frame(
                        width: width * 1.05,
                        height: width * 1.05
                    )
                    .blur(radius: 85)
                    .position(
                        x: width * 0.82,
                        y: height * 0.86
                    )

                Circle()
                    .fill(
                        Color(
                            red: 0.10,
                            green: 0.45,
                            blue: 0.95
                        )
                        .opacity(0.22)
                    )
                    .frame(
                        width: width * 0.70,
                        height: width * 0.70
                    )
                    .blur(radius: 70)
                    .position(
                        x: width * 0.85,
                        y: height * 0.48
                    )

                LinearGradient(
                    colors: [
                        Color(
                            red: 0.0,
                            green: 0.4,
                            blue: 0.9
                        )
                        .opacity(0.25),

                        Color.clear,

                        Color(
                            red: 0.4,
                            green: 0.2,
                            blue: 0.8
                        )
                        .opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 50)
            }
            .frame(
                width: width,
                height: height
            )
        }
        .clipped()
    }
}


// MARK: - Obsidian Teal Background

struct ObsidianTealTubeBackground: View {

    var body: some View {

        ZStack {

            Ellipse()
                .fill(
                    Color(
                        red: 0.0,
                        green: 0.65,
                        blue: 0.55
                    )
                    .opacity(0.35)
                )
                .frame(
                    width: 360,
                    height: 480
                )
                .blur(radius: 80)
                .offset(
                    x: 30,
                    y: -145
                )

            Ellipse()
                .fill(
                    Color(
                        red: 0.0,
                        green: 0.45,
                        blue: 0.70
                    )
                    .opacity(0.30)
                )
                .frame(
                    width: 400,
                    height: 430
                )
                .blur(radius: 90)
                .offset(
                    x: -30,
                    y: 190
                )

            LinearGradient(
                colors: [
                    Color(
                        red: 0.0,
                        green: 0.8,
                        blue: 0.7
                    )
                    .opacity(0.15),

                    Color.clear,

                    Color(
                        red: 0.0,
                        green: 0.5,
                        blue: 0.6
                    )
                    .opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 60)
        }
    }
}


// MARK: - Status Dot

struct StatusDot: View {

    let on: Bool

    var size: CGFloat = 10

    var body: some View {

        ZStack {

            if on {

                Circle()
                    .fill(
                        Theme.mint.opacity(0.25)
                    )
                    .frame(
                        width: size * 2,
                        height: size * 2
                    )
            }

            Circle()
                .fill(
                    on
                        ? Theme.mint
                        : Color.white.opacity(0.30)
                )
                .frame(
                    width: size,
                    height: size
                )
                .shadow(
                    color: on
                        ? Theme.mint.opacity(0.60)
                        : Color.clear,
                    radius: 4
                )
        }
        .frame(
            width: size * 2.5,
            height: size * 2.5
        )
        .motion(
            Motion.quick,
            value: on
        )
        .accessibilityHidden(true)
    }
}


// MARK: - Radar

struct RadarView: View {

    @ScaledMetric(relativeTo: .title)
    private var side: CGFloat = 120

    var body: some View {

        ZStack {

            ForEach(
                0..<3,
                id: \.self
            ) { index in

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Theme.accent,
                                Theme.secondaryAccent
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
                    .scaleEffect(
                        0.45
                        + CGFloat(index) * 0.28
                    )
                    .opacity(
                        0.75
                        - Double(index) * 0.20
                    )
            }

            Image(
                systemName:
                    "dot.radiowaves.left.and.right"
            )
            .symbolRenderingMode(.hierarchical)
            .font(
                .title2.weight(.semibold)
            )
            .foregroundStyle(
                Theme.title
            )
        }
        .frame(
            width: side,
            height: side
        )
        .accessibilityHidden(true)
    }
}


// MARK: - Avatar

struct Avatar: View {

    let name: String
    let online: Bool

    @ScaledMetric(relativeTo: .headline)
    private var size: CGFloat = 44

    var body: some View {

        ZStack {

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.accent,
                            Theme.secondaryAccent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(
                String(
                    name.prefix(1)
                )
                .uppercased()
            )
            .font(
                .system(
                    .headline,
                    design: .rounded
                )
                .weight(.bold)
            )
            .foregroundStyle(Color.white)
        }
        .frame(
            width: size,
            height: size
        )
        .overlay(
            alignment: .bottomTrailing
        ) {

            Circle()
                .fill(
                    online
                        ? Theme.mint
                        : Color.gray
                )
                .frame(
                    width: size * 0.28,
                    height: size * 0.28
                )
                .overlay(
                    Circle()
                        .stroke(
                            Color.black.opacity(0.60),
                            lineWidth: 2
                        )
                )
        }
        .accessibilityHidden(true)
    }
}


// MARK: - Section Title

struct SectionTitle: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {

        HStack(spacing: 8) {

            Text(
                text.uppercased()
            )
            .font(
                .system(
                    .caption,
                    design: .rounded
                )
                .weight(.bold)
            )
            .tracking(1.2)
            .foregroundStyle(
                Color.white.opacity(0.75)
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }
}


// MARK: - Row Card

struct RowCard: View {

    let icon: String
    let title: String
    let subtitle: String

    var tint: Color = Theme.accent

    @ScaledMetric(relativeTo: .headline)
    private var iconSize: CGFloat = 44

    var body: some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(
                    width: iconSize,
                    height: iconSize
                )
                .background(
                    Circle()
                        .fill(
                            tint.opacity(0.35)
                        )
                )
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(title)
                    .font(
                        .system(
                            .headline,
                            design: .rounded
                        )
                        .weight(.semibold)
                    )
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(
                        Color.white.opacity(0.75)
                    )
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(
                    Color.white.opacity(0.5)
                )
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .glassCard(
            cornerRadius: 22,
            tint: tint.opacity(0.12)
        )
        .accessibilityElement(
            children: .combine
        )
    }
}


// MARK: - Peer Row

struct PeerRow: View {

    let p: PeerView

    var body: some View {

        HStack(spacing: 12) {

            Avatar(
                name: p.nick,
                online: p.online
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                HStack(spacing: 6) {

                    Text(p.nick)
                        .font(
                            .system(
                                .headline,
                                design: .rounded
                            )
                            .weight(.semibold)
                        )
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if p.verified {

                        Image(
                            systemName:
                                "checkmark.seal.fill"
                        )
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            Theme.accent
                        )
                        .font(.subheadline)
                        .accessibilityLabel("Verified")
                        .motionTransition(
                            .opacity.combined(
                                with: .scale(
                                    scale: 0.9
                                )
                            )
                        )
                    }
                }

                HStack(
                    alignment: .firstTextBaseline,
                    spacing: 4
                ) {

                    Image(
                        systemName:
                            p.online
                            ? "antenna.radiowaves.left.and.right"
                            : "moon.zzz.fill"
                    )
                    .font(.caption2)
                    .symbolReplace()

                    Text(
                        p.online
                        ? "\(p.hops) hop(s) · \(p.via) \(p.signal)"
                        : "offline · messages will queue"
                    )
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
                .font(.subheadline)
                .foregroundStyle(
                    Color.white.opacity(0.75)
                )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(
                    Color.white.opacity(0.5)
                )
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .glassCard(
            cornerRadius: 22
        )
        .motion(
            Motion.quick,
            value: p.verified
        )
        .accessibilityElement(
            children: .combine
        )
    }
}


// MARK: - Banner

struct BannerCard: View {

    let icon: String
    let text: String

    var tint: Color = Theme.danger

    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {

        ViewThatFits(
            in: .horizontal
        ) {

            HStack(spacing: 12) {

                bannerIcon

                bannerText

                if let actionTitle,
                   let action {

                    bannerAction(
                        title: actionTitle,
                        action: action
                    )
                }
            }

            VStack(
                alignment: .leading,
                spacing: 12
            ) {

                HStack(
                    alignment: .top,
                    spacing: 12
                ) {

                    bannerIcon

                    bannerText
                }

                if let actionTitle,
                   let action {

                    bannerAction(
                        title: actionTitle,
                        action: action
                    )
                }
            }
        }
        .padding(14)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .glassCard(
            cornerRadius: 20,
            tint: tint.opacity(0.20)
        )
    }

    private var bannerIcon: some View {

        Image(systemName: icon)
            .symbolRenderingMode(.hierarchical)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private var bannerText: some View {

        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.white)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .lineLimit(5)
            .layoutPriority(1)
    }

    private func bannerAction(
        title: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(
            title,
            action: action
        )
        .font(
            .subheadline.weight(.semibold)
        )
        .foregroundStyle(
            Theme.accent
        )
        .frame(minHeight: 44)
        .buttonStyle(
            PressableStyle()
        )
    }
}


// MARK: - Transport Chip

struct TransportChip: View {

    let info: TransportInfo

    var ns: Namespace.ID? = nil

    var body: some View {

        HStack(spacing: 6) {

            StatusDot(
                on:
                    info.state.active
                    && info.state.links > 0,
                size: 6
            )

            Text(info.label)
                .font(
                    .system(
                        .subheadline,
                        design: .rounded
                    )
                    .weight(.semibold)
                )
                .foregroundStyle(Color.white)
                .lineLimit(1)

            Text(
                info.state.active
                ? "\(info.state.links)"
                : "off"
            )
            .font(.caption)
            .foregroundStyle(
                Color.white.opacity(0.8)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassCapsule()
        .glassMorph(
            id: "transport-\(info.label)",
            in: ns
        )
        .accessibilityElement(
            children: .combine
        )
    }
}


// MARK: - Root

struct RootView: View {

    @EnvironmentObject var engine: MeshEngine

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @AppStorage("selectedTheme")
    private var selectedTheme:
        AppThemeStyle = .midnightBlue

    var body: some View {

        Group {

            if engine.nickname.isEmpty {

                NicknameView()
                    .motionTransition(
                        .opacity
                    )

            } else {

                NavigationStack {

                    PeersView()
                }
                .motionTransition(
                    .opacity
                )
            }
        }
        .animation(
            reduceMotion
                ? .easeInOut(duration: 0.15)
                : .easeInOut(duration: 0.30),
            value: engine.nickname.isEmpty
        )
        .animation(
            reduceMotion
                ? .easeInOut(duration: 0.15)
                : Motion.theme,
            value: selectedTheme
        )
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .id(selectedTheme)
    }
}


// MARK: - Nickname View

struct NicknameView: View {

    @EnvironmentObject var engine: MeshEngine

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @ScaledMetric(relativeTo: .largeTitle)
    private var titleSize: CGFloat = 34

    @State private var nick = ""
    @State private var appeared = false

    private var isEmpty: Bool {

        nick
            .trimmingCharacters(
                in: .whitespaces
            )
            .isEmpty
    }

    private var shown: Bool {

        appeared || reduceMotion
    }

    var body: some View {

        ScrollView {

            VStack(spacing: 24) {

                Spacer(minLength: 24)

                RadarView()
                    .opacity(
                        shown
                            ? 1
                            : 0
                    )

                VStack(spacing: 12) {

                    Text("OffGrid Chat")
                        .font(
                            .system(
                                size: titleSize,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            Theme.title
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityAddTraits(
                            .isHeader
                        )

                    Text(
                        "Secure decentralized mesh communication. Operates entirely off-grid via Bluetooth and local Wi-Fi."
                    )
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        Color.white.opacity(0.85)
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .padding(.horizontal, 8)
                }
                .offset(
                    y: shown ? 0 : 12
                )
                .opacity(
                    shown ? 1 : 0
                )

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Label(
                        "Choose Nickname",
                        systemImage:
                            "person.crop.circle.badge.plus"
                    )
                    .symbolRenderingMode(
                        .hierarchical
                    )
                    .font(
                        .system(
                            .headline,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.white
                    )

                    TextField(
                        "",
                        text: $nick,
                        prompt:
                            Text("Enter display name")
                            .foregroundColor(
                                Color.white.opacity(0.55)
                            )
                    )
                    .font(
                        .system(
                            .body,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.white
                    )
                    .fieldSurface()
                    .accessibilityLabel(
                        "Display name"
                    )

                    Text(
                        "No account required. Your cryptographic keypair verifies your identity across the mesh."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        Color.white.opacity(0.70)
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
                .padding(20)
                .frame(
                    maxWidth: 520,
                    alignment: .leading
                )
                .glassCard(
                    cornerRadius: 28
                )
                .offset(
                    y: shown ? 0 : 16
                )
                .opacity(
                    shown ? 1 : 0
                )

                Button {

                    Haptics.success()

                    engine.setNickname(nick)

                } label: {

                    HStack {

                        Text("Initialize Node")

                        Image(
                            systemName:
                                "arrow.right"
                        )
                    }
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(
                    GlassButtonStyle(
                        tint:
                            Theme.accent.opacity(0.80)
                    )
                )
                .frame(
                    maxWidth: 520
                )
                .disabled(isEmpty)
                .opacity(
                    isEmpty
                        ? 0.5
                        : 1
                )
                .motion(
                    Motion.quick,
                    value: isEmpty
                )
                .opacity(
                    shown
                        ? 1
                        : 0
                )

                Spacer(minLength: 24)
            }
            .frame(
                maxWidth: .infinity
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .background {
            AppBackground()
        }
        .onAppear {

            if reduceMotion {

                appeared = true

            } else {

                withAnimation(
                    .easeInOut(
                        duration: 0.30
                    )
                ) {
                    appeared = true
                }
            }
        }
    }
}


// MARK: - Animation View Wrapper

struct AnimationView: View {

    var body: some View {

        DotLottieAnimation(
            webURL:
                "https://lottie.host/bc6e7107-956e-4207-84f3-d5f3da7884b6/KnpyDwX8Du.lottie",
            config:
                AnimationConfig(
                    autoplay: true,
                    loop: false
                )
        )
        .view()
        .accessibilityHidden(true)
    }
}


// MARK: - Peers View

struct PeersView: View {

    @EnvironmentObject var engine: MeshEngine

    @Namespace private var glassNS

    private var peerKey: [String] {

        engine.peers.map {

            $0.id
            + ($0.online ? "1" : "0")
        }
    }

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                // MARK: Transport Status

                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {

                    GlassGroup(
                        spacing: 8
                    ) {

                        HStack(spacing: 8) {

                            ForEach(
                                engine.transportInfos
                            ) {

                                TransportChip(
                                    info: $0,
                                    ns: glassNS
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 4)
                    }
                }

                // MARK: Errors

                ForEach(
                    engine.transportInfos.filter {
                        $0.state.error != nil
                    }
                ) { transport in

                    BannerCard(
                        icon:
                            "exclamationmark.triangle.fill",
                        text:
                            "\(transport.label): \(transport.state.error ?? "")"
                    )
                    .motionTransition(
                        .opacity.combined(
                            with: .move(
                                edge: .top
                            )
                        )
                    )
                }

                // MARK: Main Rooms

                VStack(spacing: 12) {

                    NavigationLink(
                        destination:
                            ChatView(
                                convId: ROOM_ID,
                                title: "Group Room"
                            )
                    ) {

                        RowCard(
                            icon: "person.3.fill",
                            title: "Group Room",
                            subtitle:
                                "Broadcast to all reachable mesh nodes (signed)"
                        )
                    }
                    .buttonStyle(
                        PressableStyle()
                    )

                    NavigationLink(
                        destination:
                            ChatView(
                                convId: EMERGENCY_ID,
                                title: "Emergency SOS"
                            )
                    ) {

                        RowCard(
                            icon:
                                "exclamationmark.octagon.fill",
                            title: "Emergency SOS",
                            subtitle:
                                "High-priority alert to all nearby nodes",
                            tint: Theme.danger
                        )
                    }
                    .buttonStyle(
                        PressableStyle()
                    )
                }

                SectionTitle(
                    "Discovered Nodes"
                )

                // MARK: Empty State

                if engine.peers.isEmpty {

                    VStack(spacing: 12) {

                        RadarView()

                        Text(
                            "Scanning Mesh Network…"
                        )
                        .font(
                            .system(
                                .headline,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            Color.white
                        )
                        .multilineTextAlignment(
                            .center
                        )

                        Text(
                            "No peers detected yet. Ensure Bluetooth is enabled and devices are within close proximity."
                        )
                        .font(.subheadline)
                        .multilineTextAlignment(
                            .center
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.75)
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                    .frame(
                        maxWidth: .infinity
                    )
                    .glassCard(
                        cornerRadius: 26
                    )
                    .motionTransition(
                        .opacity
                    )
                }

                // MARK: Peers

                ForEach(
                    engine.peers
                ) { peer in

                    NavigationLink(
                        destination:
                            ChatView(
                                convId: peer.id,
                                title: peer.nick
                            )
                    ) {

                        PeerRow(
                            p: peer
                        )
                    }
                    .buttonStyle(
                        PressableStyle()
                    )
                    .motionTransition(
                        .opacity.combined(
                            with: .move(
                                edge: .trailing
                            )
                        )
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(
                maxWidth: 620
            )
            .frame(
                maxWidth: .infinity
            )
            .motion(
                Motion.standard,
                value: peerKey
            )
        }
        .scrollIndicators(.hidden)
        .background {
            AppBackground()
        }
        .toolbar {

            // MARK: Custom Navigation Header

            ToolbarItem(
                placement:
                    .navigationBarLeading
            ) {

                HStack(spacing: 8) {

                    AnimationView()
                        .frame(
                            width: 38,
                            height: 38
                        )

                    VStack(
                        alignment: .leading,
                        spacing: 1
                    ) {

                        Text("MENSAGIP")
                            .font(
                                .system(
                                    .subheadline,
                                    design: .rounded
                                )
                                .weight(.bold)
                            )
                            .foregroundStyle(
                                Color.white
                            )

                        Text("OffGrid Chat")
                            .font(
                                .system(
                                    .caption2,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(
                                Color.white.opacity(0.55)
                            )
                    }
                }
            }

            // MARK: Toolbar Actions

            ToolbarItemGroup(
                placement:
                    .navigationBarTrailing
            ) {

                NavigationLink {

                    IdentityView()

                } label: {

                    Image(
                        systemName:
                            "qrcode.viewfinder"
                    )
                }
                .accessibilityLabel(
                    "Identity"
                )
                .accessibilityHint(
                    "Shows your fingerprint and QR code"
                )

                NavigationLink {

                    RadiosView()

                } label: {

                    Image(
                        systemName:
                            "waveform.badge.magnifyingglass"
                    )
                }
                .accessibilityLabel(
                    "Radios and Settings"
                )
            }
        }
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )
    }
}


// MARK: - Chat View

struct ChatView: View {

    @EnvironmentObject var engine: MeshEngine

    let convId: String
    let title: String

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State private var text = ""

    @ScaledMetric(relativeTo: .body)
    private var controlSize: CGFloat = 44

    private var msgs: [ChatMessage] {

        engine.messages
            .filter {
                $0.convId == convId
            }
            .sorted {
                $0.ts < $1.ts
            }
    }

    private var isGroup: Bool {

        convId == ROOM_ID
            || convId == EMERGENCY_ID
    }

    private var isSOS: Bool {

        convId == EMERGENCY_ID
    }

    private var peer: PeerView? {

        engine.peers.first {
            $0.id == convId
        }
    }

    private var isEmpty: Bool {

        text
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
    }

    private func isContinuation(
        _ message: ChatMessage
    ) -> Bool {

        let list = msgs

        guard
            let index =
                list.firstIndex(
                    where: {
                        $0.id == message.id
                    }
                ),
            index > 0
        else {
            return false
        }

        return
            list[index - 1].senderId
                == message.senderId
            &&
            list[index - 1].outgoing
                == message.outgoing
    }

    @ViewBuilder
    private func statusBadge(
        _ status: MsgStatus
    ) -> some View {

        HStack(spacing: 4) {

            switch status {

            case .queued:

                Image(
                    systemName: "clock.fill"
                )
                .font(.caption2)

                Text("Queued")

            case .sent:

                Image(
                    systemName: "checkmark"
                )
                .font(.caption2)

                Text("Sent")

            case .delivered:

                Image(
                    systemName: "checkmark.2"
                )
                .font(.caption2)

                Text("Delivered")

            case .failed:

                Image(
                    systemName:
                        "exclamationmark.circle.fill"
                )
                .font(.caption2)

                Text("Failed · Tap to retry")

            case .received:

                EmptyView()
            }
        }
        .font(
            .caption2.weight(.medium)
        )
        .foregroundStyle(
            status == .failed
                ? Theme.danger
                : Color.white.opacity(0.70)
        )
    }

    var body: some View {

        VStack(spacing: 0) {

            VStack(spacing: 8) {

                if let peer,
                   !peer.verified {

                    BannerCard(
                        icon:
                            "shield.lefthalf.filled",
                        text:
                            "Unverified peer. Compare cryptographic fingerprint on their Identity screen.",
                        actionTitle: "Verify"
                    ) {

                        Haptics.success()

                        engine.setVerified(
                            peer.id
                        )
                    }
                    .motionTransition(
                        .opacity.combined(
                            with: .move(
                                edge: .top
                            )
                        )
                    )
                }

                if isSOS {

                    BannerCard(
                        icon:
                            "exclamationmark.octagon.fill",
                        text:
                            "Emergency Broadcast active. Messages are signed and broadcast globally across the mesh."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .motion(
                Motion.standard,
                value: peer?.verified
            )

            ScrollViewReader { proxy in

                ScrollView {

                    LazyVStack(spacing: 0) {

                        ForEach(msgs) { message in

                            bubble(message)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .motion(
                        Motion.standard,
                        value: msgs.count
                    )
                }
                .scrollDismissesKeyboard(
                    .interactively
                )
                .onChange(
                    of: msgs.count
                ) { _ in

                    scrollToEnd(
                        proxy,
                        animated: !reduceMotion
                    )
                }
                .onAppear {

                    scrollToEnd(
                        proxy,
                        animated: false
                    )
                }
            }
        }
        .safeAreaInset(
            edge: .bottom
        ) {

            inputBar
        }
        .background {
            AppBackground()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )
    }

    private func scrollToEnd(
        _ proxy: ScrollViewProxy,
        animated: Bool
    ) {

        guard let last = msgs.last else {
            return
        }

        DispatchQueue.main.async {

            if animated {

                withAnimation(
                    .easeOut(
                        duration: 0.25
                    )
                ) {

                    proxy.scrollTo(
                        last.id,
                        anchor: .bottom
                    )
                }

            } else {

                proxy.scrollTo(
                    last.id,
                    anchor: .bottom
                )
            }
        }
    }

    @ViewBuilder
    private func bubble(
        _ message: ChatMessage
    ) -> some View {

        let who =
            engine.peers.first {
                $0.id == message.senderId
            }?.nick
            ?? String(
                message.senderId.prefix(6)
            )

        let continuation =
            isContinuation(message)

        VStack(
            alignment:
                message.outgoing
                ? .trailing
                : .leading,
            spacing: 4
        ) {

            if isGroup
                && !message.outgoing
                && !continuation {

                HStack(spacing: 4) {

                    Image(
                        systemName: "person.fill"
                    )
                    .font(.caption2)

                    Text(who)
                        .font(
                            .subheadline.weight(
                                .bold
                            )
                        )
                        .lineLimit(1)
                }
                .foregroundStyle(
                    Theme.accent
                )
            }

            if message.outgoing {

                Text(message.text)
                    .foregroundStyle(
                        Color.white
                    )
                    .multilineTextAlignment(
                        .leading
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassSurface(
                        shape:
                            RoundedRectangle(
                                cornerRadius: 20,
                                style: .continuous
                            ),
                        tint:
                            Theme.outgoingTint
                                .opacity(0.75)
                    )

            } else {

                Text(message.text)
                    .foregroundStyle(
                        Color.white
                    )
                    .multilineTextAlignment(
                        .leading
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassCard(
                        cornerRadius: 20
                    )
            }

            if message.outgoing {

                statusBadge(
                    message.status
                )
                .motion(
                    Motion.quick,
                    value: message.status
                )
            }
        }
        .padding(
            .leading,
            message.outgoing ? 56 : 0
        )
        .padding(
            .trailing,
            message.outgoing ? 0 : 56
        )
        .frame(
            maxWidth: .infinity,
            alignment:
                message.outgoing
                ? .trailing
                : .leading
        )
        .padding(
            .top,
            continuation ? 2 : 10
        )
        .id(message.id)
        .motionTransition(
            .asymmetric(
                insertion:
                    .opacity.combined(
                        with:
                            .move(
                                edge: .bottom
                            )
                    ),
                removal: .opacity
            )
        )
        .onTapGesture {

            if message.status == .failed {

                Haptics.warning()

                engine.retry(
                    message.id
                )
            }
        }
        .accessibilityElement(
            children: .combine
        )
        .accessibilityAddTraits(
            message.status == .failed
                ? .isButton
                : []
        )
    }

    private var sendButton: some View {

        Button(
            action: sendNow
        ) {

            Image(
                systemName:
                    "paperplane.fill"
            )
            .symbolRenderingMode(
                .hierarchical
            )
            .font(
                .body.weight(.semibold)
            )
            .foregroundStyle(
                Color.white
            )
            .frame(
                width: controlSize,
                height: controlSize
            )
        }
        .glassCircle(
            tint:
                Theme.accent.opacity(0.70),
            interactive: true
        )
        .accessibilityLabel(
            "Send message"
        )
        .accessibilityHint(
            isEmpty
                ? "Enter a message first"
                : "Sends the message"
        )
    }

    private var sosButton: some View {

        Button(
            action: sendNow
        ) {

            HStack(spacing: 6) {

                Image(
                    systemName:
                        "exclamationmark.triangle.fill"
                )

                Text("SOS")
            }
            .font(
                .system(
                    .subheadline,
                    design: .rounded
                )
                .weight(.heavy)
            )
            .foregroundStyle(
                Color.white
            )
            .padding(.horizontal, 16)
            .frame(
                minHeight: controlSize
            )
        }
        .glassCapsule(
            tint:
                Theme.danger.opacity(0.85),
            interactive: true
        )
        .padding(.leading, 4)
        .accessibilityLabel(
            "Send SOS"
        )
        .accessibilityHint(
            "Broadcasts an emergency message to all nearby nodes"
        )
    }

    private var inputBar: some View {

        GlassGroup(
            spacing: 8
        ) {

            HStack(spacing: 12) {

                TextField(
                    "",
                    text: $text,
                    prompt:
                        Text("Secure message...")
                        .foregroundColor(
                            Color.white.opacity(
                                0.55
                            )
                        )
                )
                .font(
                    .system(
                        .body,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    Color.white
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(
                    minHeight: controlSize
                )
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity
                )
                .glassCapsule()
                .accessibilityLabel(
                    "Message"
                )

                Group {

                    if isSOS {

                        sosButton

                    } else {

                        sendButton
                    }
                }
                .disabled(isEmpty)
                .opacity(
                    isEmpty ? 0.5 : 1
                )
                .motion(
                    Motion.quick,
                    value: isEmpty
                )
            }
            .frame(
                maxWidth: .infinity
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func sendNow() {

        guard !isEmpty else {
            return
        }

        engine.send(
            to: convId,
            text
        )

        text = ""

        if isSOS {

            Haptics.warning()

        } else {

            Haptics.tap()
        }
    }
}


// MARK: - Identity

struct IdentityView: View {

    @EnvironmentObject var engine: MeshEngine

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State private var scanning = false
    @State private var result: String?
    @State private var copied = false
    @State private var qrPic = UIImage()

    private func identityNick(
        _ peer: PeerView
    ) -> some View {

        Text(peer.nick)
            .font(
                .system(
                    .headline,
                    design: .rounded
                )
                .weight(.semibold)
            )
            .foregroundStyle(
                Color.white
            )
            .lineLimit(1)
    }

    private func identityBadge(
        _ peer: PeerView
    ) -> some View {

        Label(
            peer.verified
                ? "Verified"
                : "Unverified",
            systemImage:
                peer.verified
                ? "checkmark.seal.fill"
                : "exclamationmark.shield"
        )
        .symbolRenderingMode(
            .hierarchical
        )
        .font(
            .caption.weight(.semibold)
        )
        .foregroundStyle(
            peer.verified
                ? Theme.mint
                : Theme.danger
        )
        .fixedSize()
    }

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                // MARK: Fingerprint

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Label(
                        "Cryptographic Fingerprint",
                        systemImage:
                            "lock.shield.fill"
                    )
                    .symbolRenderingMode(
                        .hierarchical
                    )
                    .font(
                        .system(
                            .headline,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.white
                    )
                    .accessibilityAddTraits(
                        .isHeader
                    )

                    Text(
                        Crypto.fingerprint(
                            engine.me
                        )
                    )
                    .font(
                        .system(
                            .footnote,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(
                        Color.white
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .multilineTextAlignment(
                        .leading
                    )

                    Button {

                        UIPasteboard.general.string =
                            Crypto.fingerprint(
                                engine.me
                            )

                        Haptics.success()

                        withAnimation(
                            Motion.quick
                        ) {

                            copied = true
                        }

                        DispatchQueue.main.asyncAfter(
                            deadline:
                                .now()
                                + 1.5
                        ) {

                            withAnimation(
                                Motion.quick
                            ) {

                                copied = false
                            }
                        }

                    } label: {

                        Label(
                            copied
                                ? "Copied to Clipboard"
                                : "Copy Fingerprint",
                            systemImage:
                                copied
                                ? "checkmark.circle.fill"
                                : "doc.on.doc"
                        )
                        .font(
                            .subheadline.weight(
                                .semibold
                            )
                        )
                        .symbolReplace()
                        .frame(
                            minHeight: 44,
                            alignment: .leading
                        )
                    }
                    .foregroundStyle(
                        Theme.accent
                    )
                    .buttonStyle(
                        PressableStyle()
                    )
                    .accessibilityLabel(
                        copied
                            ? "Fingerprint copied"
                            : "Copy fingerprint"
                    )
                }
                .padding(18)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .glassCard(
                    cornerRadius: 26
                )

                // MARK: QR

                VStack(spacing: 16) {

                    Image(uiImage: qrPic)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: 240
                        )
                        .padding(16)
                        .background(
                            Color.white,
                            in:
                                RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                        )
                        .accessibilityLabel(
                            "Your identity QR code"
                        )

                    Text(
                        "Show this QR code to a friend in person to securely verify your mesh identity."
                    )
                    .font(.subheadline)
                    .multilineTextAlignment(
                        .center
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.85)
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .padding(.horizontal, 8)

                    if let result {

                        let success =
                            result.hasPrefix(
                                "Successfully"
                            )

                        Label(
                            result,
                            systemImage:
                                success
                                ? "checkmark.shield.fill"
                                : "xmark.shield.fill"
                        )
                        .symbolRenderingMode(
                            .hierarchical
                        )
                        .font(
                            .subheadline.weight(
                                .semibold
                            )
                        )
                        .foregroundStyle(
                            success
                                ? Theme.mint
                                : Theme.danger
                        )
                        .multilineTextAlignment(
                            .center
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .motionTransition(
                            .opacity
                        )
                    }
                }
                .padding(20)
                .frame(
                    maxWidth: .infinity
                )
                .glassCard(
                    cornerRadius: 28
                )

                Button {

                    Haptics.tap()

                    scanning = true

                } label: {

                    Label(
                        "Scan Peer QR Code",
                        systemImage:
                            "qrcode.viewfinder"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(
                    GlassButtonStyle(
                        tint:
                            Theme.accent.opacity(
                                0.70
                            )
                    )
                )

                SectionTitle(
                    "Known Peer Identities"
                )

                // MARK: Known Peers

                ForEach(
                    engine.peers
                ) { peer in

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        ViewThatFits(
                            in: .horizontal
                        ) {

                            HStack(spacing: 8) {

                                identityNick(
                                    peer
                                )

                                Spacer(
                                    minLength: 8
                                )

                                identityBadge(
                                    peer
                                )
                            }

                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {

                                identityNick(
                                    peer
                                )

                                identityBadge(
                                    peer
                                )
                            }
                        }

                        Text(
                            peer.fingerprint
                        )
                        .font(
                            .system(
                                .caption,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.80)
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .multilineTextAlignment(
                            .leading
                        )

                        if !peer.verified {

                            Button(
                                "Confirm Fingerprint Match"
                            ) {

                                Haptics.success()

                                engine.setVerified(
                                    peer.id
                                )
                            }
                            .font(
                                .subheadline.weight(
                                    .semibold
                                )
                            )
                            .foregroundStyle(
                                Theme.accent
                            )
                            .frame(
                                minHeight: 44,
                                alignment: .leading
                            )
                            .buttonStyle(
                                PressableStyle()
                            )
                        }
                    }
                    .padding(16)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .glassCard(
                        cornerRadius: 20
                    )
                    .motionTransition(
                        .opacity
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(
                maxWidth: 620
            )
            .frame(
                maxWidth: .infinity
            )
            .motion(
                Motion.standard,
                value: result
            )
            .motion(
                Motion.standard,
                value: engine.peers.count
            )
        }
        .scrollIndicators(.hidden)
        .background {
            AppBackground()
        }
        .navigationTitle(
            "Identity & Security"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )
        .onAppear {

            qrPic = qrImage(
                engine.myQr()
            )
        }
        .sheet(
            isPresented: $scanning
        ) {

            ZStack(
                alignment: .topTrailing
            ) {

                QRScannerView { code in

                    scanning = false

                    if let nick =
                        engine.verifyFromQr(
                            code
                        ) {

                        result =
                            "Successfully verified \(nick)"

                        Haptics.success()

                    } else {

                        result =
                            "Invalid OffGrid QR code"

                        Haptics.warning()
                    }
                }
                .ignoresSafeArea()

                Button("Cancel") {

                    scanning = false
                }
                .buttonStyle(
                    GlassButtonStyle()
                )
                .padding()
            }
        }
    }
}


// MARK: - Radios & Settings

struct RadiosView: View {

    @EnvironmentObject var engine: MeshEngine

    @AppStorage("selectedTheme")
    private var selectedTheme:
        AppThemeStyle = .midnightBlue

    @State private var host =
        UserDefaults.standard.string(
            forKey: "lanHost"
        ) ?? ""

    @State private var confirmStop = false

    private var restartButton: some View {

        Button {

            Haptics.tap()

            engine.start()

        } label: {

            Label(
                "Restart Node",
                systemImage:
                    "arrow.clockwise"
            )
            .frame(
                maxWidth: .infinity
            )
        }
        .buttonStyle(
            GlassButtonStyle(
                tint:
                    Theme.accent.opacity(0.70)
            )
        )
    }

    private var stopButton: some View {

        Button(
            role: .destructive
        ) {

            confirmStop = true

        } label: {

            Label(
                "Stop Mesh",
                systemImage: "power"
            )
            .frame(
                maxWidth: .infinity
            )
        }
        .buttonStyle(
            GlassButtonStyle(
                tint:
                    Theme.danger.opacity(0.70)
            )
        )
    }

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                // MARK: Theme

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Label(
                        "Visual Theme",
                        systemImage:
                            "paintpalette.fill"
                    )
                    .symbolRenderingMode(
                        .hierarchical
                    )
                    .font(
                        .system(
                            .headline,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.white
                    )

                    Picker(
                        "Theme",
                        selection:
                            $selectedTheme
                    ) {

                        ForEach(
                            AppThemeStyle.allCases
                        ) { theme in

                            Text(
                                theme.rawValue
                            )
                            .tag(theme)
                        }
                    }
                    .pickerStyle(
                        .segmented
                    )

                    Text(
                        "Switch between Midnight Blue and Obsidian Teal design aesthetics."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        Color.white.opacity(0.75)
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
                .padding(16)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .glassCard(
                    cornerRadius: 22
                )

                // MARK: Transports

                ForEach(
                    engine.transportInfos
                ) { transport in

                    HStack(
                        alignment: .top,
                        spacing: 12
                    ) {

                        StatusDot(
                            on:
                                transport.state.active
                                && transport.state.links > 0,
                            size: 9
                        )

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {

                            Text(
                                "\(transport.label): \(transport.state.active ? "Active" : "Inactive") · \(transport.state.links) link(s)"
                            )
                            .font(
                                .system(
                                    .headline,
                                    design: .rounded
                                )
                                .weight(.semibold)
                            )
                            .foregroundStyle(
                                Color.white
                            )
                            .lineLimit(3)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                            Text(
                                transport.state.detail
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                Color.white.opacity(
                                    0.80
                                )
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                            if let error =
                                transport.state.error {

                                Label(
                                    error,
                                    systemImage:
                                        "exclamationmark.triangle.fill"
                                )
                                .font(.subheadline)
                                .foregroundStyle(
                                    Theme.danger
                                )
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .layoutPriority(1)
                    }
                    .padding(16)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .glassCard(
                        cornerRadius: 20
                    )
                    .motionTransition(
                        .opacity.combined(
                            with:
                                .move(
                                    edge: .leading
                                )
                        )
                    )
                    .accessibilityElement(
                        children: .combine
                    )
                }

                // MARK: LAN Host

                SectionTitle(
                    "Android Hotspot Host (Optional)"
                )

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    TextField(
                        "",
                        text: $host,
                        prompt:
                            Text(
                                "Host IP (e.g. 192.168.43.1)"
                            )
                            .foregroundColor(
                                Color.white.opacity(
                                    0.55
                                )
                            )
                    )
                    .font(
                        .system(
                            .body,
                            design: .rounded
                        )
                    )
                    .keyboardType(
                        .numbersAndPunctuation
                    )
                    .autocorrectionDisabled()
                    .foregroundStyle(
                        Color.white
                    )
                    .fieldSurface()
                    .accessibilityLabel(
                        "Hotspot host IP address"
                    )
                    .onChange(
                        of: host
                    ) {

                        engine.lan.manualHost =
                            $0
                    }

                    Text(
                        "Connect to the Android hotspot Wi-Fi in iOS Settings, then open this app and enable Local Network access."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        Color.white.opacity(0.80)
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
                .padding(16)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .glassCard(
                    cornerRadius: 24
                )

                // MARK: Node Information

                Text(
                    "iOS suspends background execution. Bluetooth maintains limited connectivity, but backgrounded iPhones may not be discoverable by Android nodes. Keep the app open for optimal mesh routing."
                )
                .font(.subheadline)
                .foregroundStyle(
                    Color.white.opacity(0.80)
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .padding(16)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .glassCard(
                    cornerRadius: 24
                )

                // MARK: Node Controls

                GlassGroup(
                    spacing: 12
                ) {

                    ViewThatFits(
                        in: .horizontal
                    ) {

                        HStack(spacing: 12) {

                            restartButton
                                .frame(
                                    maxWidth: .infinity
                                )

                            stopButton
                                .frame(
                                    maxWidth: .infinity
                                )
                        }

                        VStack(spacing: 12) {

                            restartButton
                                .frame(
                                    maxWidth: .infinity
                                )

                            stopButton
                                .frame(
                                    maxWidth: .infinity
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(
                maxWidth: 620
            )
            .frame(
                maxWidth: .infinity
            )
        }
        .scrollIndicators(.hidden)
        .background {
            AppBackground()
        }
        .navigationTitle(
            "Radios & Settings"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )
        .confirmationDialog(
            "Stop OffGrid Chat?",
            isPresented:
                $confirmStop,
            titleVisibility: .visible
        ) {

            Button(
                "Stop",
                role: .destructive
            ) {

                engine.stop()
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}

        } message: {

            Text(
                "Mesh radios will power down and you will stop receiving transmissions until restarted."
            )
        }
    }
}
