import SwiftUI
import UIKit

// =====================================================================================
// OffGrid Chat: Next-Gen iOS Liquid Glass UI
// UI / Presentation Layer
//
// IMPORTANT:
// - MeshEngine behavior is unchanged.
// - Chat behavior is unchanged.
// - QR verification behavior is unchanged.
// - Transport behavior is unchanged.
// - Existing IDs and engine calls are unchanged.
// - Changes are focused on sizing, margins, layout, animations and transitions.
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

            return AppThemeStyle(rawValue: rawValue)
                ?? .midnightBlue
        }

        set {
            UserDefaults.standard.set(
                newValue.rawValue,
                forKey: key
            )
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


// MARK: - Liquid Glass & Modifiers

#if compiler(>=6.2)

@available(iOS 26.0, *)
private func makeGlass(
    tint: Color?,
    interactive: Bool
) -> Glass {

    var g = Glass.regular

    if let tint {
        g = g.tint(tint)
    }

    if interactive {
        g = g.interactive()
    }

    return g
}

#endif


struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool
    let glassID: String?
    let namespace: Namespace.ID?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.base.opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(tint ?? Color.white.opacity(0.3), lineWidth: 1)
                )
        } else {
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                var g = Glass.regular
                if let tint {
                    g = g.tint(tint)
                }
                if interactive {
                    g = g.interactive()
                }
                let baseView = content.glassEffect(g, in: .rect(cornerRadius: cornerRadius))
                if let glassID, let namespace {
                    baseView.glassEffectID(glassID, in: namespace)
                } else {
                    baseView
                }
            } else {
                content.frostedGlass(cornerRadius: cornerRadius, tint: tint)
            }
            #else
            content.frostedGlass(cornerRadius: cornerRadius, tint: tint)
            #endif
        }
    }
}


extension View {

    @ViewBuilder
    func glassCard(
        cornerRadius: CGFloat = 24,
        tint: Color? = nil,
        interactive: Bool = false,
        glassID: String? = nil,
        namespace: Namespace.ID? = nil
    ) -> some View {
        self.modifier(
            GlassCardModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                interactive: interactive,
                glassID: glassID,
                namespace: namespace
            )
        )
    }

    fileprivate func frostedGlass(
        cornerRadius: CGFloat,
        tint: Color?
    ) -> some View {

        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )

        return self
            .background(
                .ultraThinMaterial,
                in: shape
            )
            .background(
                shape.fill(
                    (tint ?? Color.white).opacity(
                        tint == nil ? 0.06 : 0.22
                    )
                )
            )
            .overlay(
                VStack {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 1.2)

                    Spacer()
                }
                .mask(shape)
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.04),
                            Color.black.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.black.opacity(0.4),
                radius: 20,
                y: 10
            )
    }

    @ViewBuilder
    func glassTransition() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffectTransition()
        } else {
            self.transition(.opacity)
        }
        #else
        self.transition(.opacity)
        #endif
    }
}


// MARK: - Glass Group

struct GlassGroup: View {

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

        configuration.label
            .font(
                .system(
                    .body,
                    design: .rounded
                )
                .weight(.semibold)
            )
            .foregroundStyle(Color.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .glassCard(
                cornerRadius: 100,
                tint: tint,
                interactive: true
            )
            .scaleEffect(
                configuration.isPressed ? 0.96 : 1
            )
            .brightness(
                configuration.isPressed ? 0.08 : 0
            )
            .animation(
                .spring(
                    response: 0.3,
                    dampingFraction: 0.7
                ),
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
                configuration.isPressed ? 0.96 : 1
            )
            .brightness(
                configuration.isPressed ? 0.06 : 0
            )
            .opacity(
                configuration.isPressed ? 0.92 : 1
            )
            .animation(
                .spring(
                    response: 0.3,
                    dampingFraction: 0.7
                ),
                value: configuration.isPressed
            )
    }
}


// MARK: - Dynamic Background

struct AppBackground: View {

    var body: some View {

        ZStack {

            Theme.base
                .ignoresSafeArea()

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

    @Environment(
        \.accessibilityReduceMotion
    )
    private var reduceMotion

    @State private var waveAnim = false

    var body: some View {

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
                    width: 380,
                    height: 380
                )
                .blur(radius: 75)
                .offset(
                    x: -110,
                    y: waveAnim ? -210 : -170
                )

            Circle()
                .fill(
                    Color(
                        red: 0.30,
                        green: 0.15,
                        blue: 0.70
                    )
                    .opacity(0.4)
                )
                .frame(
                    width: 410,
                    height: 410
                )
                .blur(radius: 85)
                .offset(
                    x: 130,
                    y: waveAnim ? 280 : 235
                )

            LinearGradient(
                colors: [
                    Color(
                        red: 0.0,
                        green: 0.4,
                        blue: 0.9
                    )
                    .opacity(0.3),

                    Color.clear,

                    Color(
                        red: 0.4,
                        green: 0.2,
                        blue: 0.8
                    )
                    .opacity(0.3)
                ],
                startPoint: waveAnim
                    ? .topLeading
                    : .bottomLeading,
                endPoint: waveAnim
                    ? .bottomTrailing
                    : .topTrailing
            )
            .blur(radius: 50)
        }
        .onAppear {

            guard !reduceMotion else {
                return
            }

            withAnimation(
                .easeInOut(
                    duration: 8
                )
                .repeatForever(
                    autoreverses: true
                )
            ) {
                waveAnim.toggle()
            }
        }
    }
}


// MARK: - Obsidian Teal Background

struct ObsidianTealTubeBackground: View {

    @Environment(
        \.accessibilityReduceMotion
    )
    private var reduceMotion

    @State private var glowAnim = false

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
                    x: glowAnim ? 95 : -95,
                    y: -145
                )

            Ellipse()
                .fill(
                    Color(
                        red: 0.0,
                        green: 0.45,
                        blue: 0.70
                    )
                    .opacity(0.3)
                )
                .frame(
                    width: 400,
                    height: 430
                )
                .blur(radius: 90)
                .offset(
                    x: glowAnim ? -75 : 75,
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
        .onAppear {

            guard !reduceMotion else {
                return
            }

            withAnimation(
                .easeInOut(
                    duration: 7
                )
                .repeatForever(
                    autoreverses: true
                )
            ) {
                glowAnim.toggle()
            }
        }
    }
}


// MARK: - Status Dot

struct StatusDot: View {

    let on: Bool
    var size: CGFloat = 10

    @State private var pulse = false

    @Environment(
        \.accessibilityReduceMotion
    )
    private var reduceMotion

    var body: some View {

        ZStack {

            if on {

                Circle()
                    .fill(
                        Theme.mint.opacity(0.4)
                    )
                    .frame(
                        width: size * 2.2,
                        height: size * 2.2
                    )
                    .scaleEffect(
                        pulse ? 1.8 : 1
                    )
                    .opacity(
                        pulse ? 0 : 0.8
                    )
            }

            Circle()
                .fill(
                    on
                    ? Theme.mint
                    : Color.white.opacity(0.3)
                )
                .frame(
                    width: size,
                    height: size
                )
                .shadow(
                    color: on
                    ? Theme.mint.opacity(0.6)
                    : Color.clear,
                    radius: 4
                )
        }
        .frame(
            width: size * 2.5,
            height: size * 2.5
        )
        .onAppear {

            guard !reduceMotion else {
                return
            }

            withAnimation(
                .easeOut(
                    duration: 1.8
                )
                .repeatForever(
                    autoreverses: false
                )
            ) {
                pulse = true
            }
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: on
        )
    }
}


// MARK: - Radar

struct RadarView: View {

    @State private var go = false

    @Environment(
        \.accessibilityReduceMotion
    )
    private var reduceMotion

    var body: some View {

        ZStack {

            ForEach(
                0..<3,
                id: \.self
            ) { i in

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
                        go ? 1.15 : 0.2
                    )
                    .opacity(
                        go ? 0 : 0.85
                    )
                    .animation(
                        reduceMotion
                        ? nil
                        : .easeOut(
                            duration: 2.6
                        )
                        .repeatForever(
                            autoreverses: false
                        )
                        .delay(
                            Double(i) * 0.9
                        ),
                        value: go
                    )
            }

            Image(
                systemName:
                    "dot.radiowaves.left.and.right"
            )
            .font(
                .system(
                    size: 30,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                Theme.title
            )
            .shadow(
                color: Theme.accent.opacity(0.6),
                radius: 10
            )
        }
        .frame(
            width: 125,
            height: 125
        )
        .onAppear {
            go = true
        }
    }
}


// MARK: - Avatar

struct Avatar: View {

    let name: String
    let online: Bool

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
            width: 46,
            height: 46
        )
        .shadow(
            color: Color.black.opacity(0.3),
            radius: 8,
            y: 4
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
                    width: 13,
                    height: 13
                )
                .overlay(
                    Circle()
                        .stroke(
                            Color.black.opacity(0.6),
                            lineWidth: 2.5
                        )
                )
                .shadow(
                    color: online
                    ? Theme.mint.opacity(0.8)
                    : Color.clear,
                    radius: 4
                )
        }
    }
}


// MARK: - Section Title

struct SectionTitle: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {

        HStack(spacing: 6) {

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
                Color.white.opacity(0.7)
            )

            Spacer()
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

    var body: some View {

        HStack(spacing: 13) {

            Image(systemName: icon)
                .font(
                    .system(
                        size: 19,
                        weight: .semibold
                    )
                )
                .foregroundStyle(Color.white)
                .frame(
                    width: 46,
                    height: 46
                )
                .background(
                    Circle()
                        .fill(
                            tint.opacity(0.35)
                        )
                        .shadow(
                            color: tint.opacity(0.5),
                            radius: 9
                        )
                )

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
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(
                        Color.white.opacity(0.7)
                    )
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )

            Image(systemName: "chevron.right")
                .font(
                    .caption.weight(.bold)
                )
                .foregroundStyle(
                    Color.white.opacity(0.4)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .glassCard(
            cornerRadius: 24,
            tint: tint.opacity(0.12)
        )
        .accessibilityElement(children: .combine)
    }
}


// MARK: - Peer Row

struct PeerRow: View {

    let p: PeerView

    var body: some View {

        HStack(spacing: 13) {

            Avatar(
                name: p.nick,
                online: p.online
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                HStack(spacing: 5) {

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

                    if p.verified {

                        Image(
                            systemName:
                                "checkmark.seal.fill"
                        )
                        .foregroundStyle(
                            Theme.accent
                        )
                        .font(.subheadline)
                        .shadow(
                            color: Theme.accent.opacity(0.7),
                            radius: 5
                        )
                        .transition(
                            .scale
                            .combined(with: .opacity)
                        )
                    }
                }

                HStack(spacing: 4) {

                    Image(
                        systemName:
                            p.online
                            ? "antenna.radiowaves.left.and.right"
                            : "moon.zzz.fill"
                    )
                    .font(.caption2)

                    Text(
                        p.online
                        ? "\(p.hops) hop(s) · \(p.via) \(p.signal)"
                        : "offline · messages will queue"
                    )
                    .lineLimit(2)
                }
                .font(.subheadline)
                .foregroundStyle(
                    Color.white.opacity(0.7)
                )
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(
                    .caption.weight(.bold)
                )
                .foregroundStyle(
                    Color.white.opacity(0.4)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .glassCard(
            cornerRadius: 24
        )
        .accessibilityElement(children: .combine)
        .animation(
            .easeInOut(duration: 0.3),
            value: p.verified
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

        HStack(spacing: 12) {

            Image(systemName: icon)
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .foregroundStyle(tint)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.white)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .lineLimit(4)

            if let actionTitle,
               let action {

                Button(
                    actionTitle,
                    action: action
                )
                .font(
                    .subheadline.weight(.semibold)
                )
                .foregroundStyle(
                    Theme.accent
                )
                .buttonStyle(
                    PressableStyle()
                )
                .accessibilityLabel(actionTitle)
            }
        }
        .padding(14)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .glassCard(
            cornerRadius: 20,
            tint: tint.opacity(0.28)
        )
        .accessibilityElement(children: .combine)
    }
}


// MARK: - Transport Chip

struct TransportChip: View {

    let info: TransportInfo

    var body: some View {

        HStack(spacing: 6) {

            StatusDot(
                on:
                    info.state.active &&
                    info.state.links > 0,
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
                Color.white.opacity(0.75)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassCard(
            cornerRadius: 100
        )
        .accessibilityElement(children: .combine)
    }
}


// MARK: - Root

struct RootView: View {

    @EnvironmentObject var engine: MeshEngine

    @AppStorage("selectedTheme")
    private var selectedTheme: AppThemeStyle =
        .midnightBlue

    var body: some View {

        Group {

            if engine.nickname.isEmpty {

                NicknameView()
                    .transition(
                        .opacity
                        .combined(
                            with:
                                .scale(scale: 1.03)
                        )
                    )

            } else {

                NavigationStack {

                    PeersView()
                }
                .transition(
                    .opacity
                )
            }
        }
        .animation(
            .easeInOut(duration: 0.45),
            value: engine.nickname.isEmpty
        )
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .id(selectedTheme)
    }
}


// MARK: - Nickname View

struct NicknameView: View {

    @EnvironmentObject var engine: MeshEngine

    @State private var nick = ""
    @State private var appeared = false

    private var isEmpty: Bool {
        nick
            .trimmingCharacters(
                in: .whitespaces
            )
            .isEmpty
    }

    var body: some View {

        ZStack {

            AppBackground()

            ScrollView {
                VStack(spacing: 24) {

                    Spacer(
                        minLength: 40
                    )

                    RadarView()
                        .scaleEffect(
                            appeared ? 1 : 0.75
                        )
                        .opacity(
                            appeared ? 1 : 0
                        )

                    VStack(spacing: 10) {

                        Text("OffGrid Chat")
                            .font(
                                .system(
                                    size: 38,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(
                                Theme.title
                            )
                            .shadow(
                                color:
                                    Theme.accent.opacity(0.4),
                                radius: 14
                            )
                            .minimumScaleFactor(0.8)

                        Text(
                            "Secure decentralized mesh communication. Operates entirely off-grid via Bluetooth and local Wi-Fi."
                        )
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(
                            Color.white.opacity(0.8)
                        )
                        .padding(
                            .horizontal,
                            8
                        )
                    }
                    .offset(
                        y: appeared ? 0 : 15
                    )
                    .opacity(
                        appeared ? 1 : 0
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
                                Text(
                                    "Enter display name"
                                )
                                .foregroundColor(
                                    Color.white.opacity(0.4)
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
                        .padding(
                            .horizontal,
                            16
                        )
                        .padding(
                            .vertical,
                            13
                        )
                        .frame(
                            maxWidth: .infinity
                        )
                        .glassCard(
                            cornerRadius: 18
                        )

                        Text(
                            "No account required. Your cryptographic keypair verifies your identity across the mesh."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            Color.white.opacity(0.65)
                        )

                        Button {

                            Haptics.success()

                            engine.setNickname(
                                nick
                            )

                        } label: {

                            HStack {

                                Text(
                                    "Initialize Node"
                                )

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
                                    Theme.accent.opacity(
                                        0.8
                                    )
                            )
                        )
                        .disabled(isEmpty)
                        .opacity(
                            isEmpty ? 0.5 : 1
                        )
                        .animation(
                            .easeInOut(
                                duration: 0.25
                            ),
                            value: isEmpty
                        )
                    }
                    .padding(20)
                    .frame(
                        maxWidth: 520
                    )
                    .glassCard(
                        cornerRadius: 30
                    )
                    .offset(
                        y: appeared ? 0 : 25
                    )
                    .opacity(
                        appeared ? 1 : 0
                    )

                    Spacer(
                        minLength: 40
                    )
                }
                .frame(
                    maxWidth: .infinity
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {

            withAnimation(
                .spring(
                    response: 0.8,
                    dampingFraction: 0.82
                )
            ) {
                appeared = true
            }
        }
    }
}


// MARK: - Peers View

struct PeersView: View {

    @EnvironmentObject var engine: MeshEngine

    @Namespace private var peerNamespace

    private var peerKey: [String] {
        engine.peers.map {
            $0.id +
            ($0.online ? "1" : "0")
        }
    }

    var body: some View {

        ZStack {

            AppBackground()

            ScrollView {

                VStack(spacing: 16) {

                    // MARK: Transport Status

                    GlassGroup(spacing: 8) {

                        ScrollView(
                            .horizontal,
                            showsIndicators: false
                        ) {

                            HStack(spacing: 8) {

                                ForEach(
                                    engine.transportInfos
                                ) {
                                    TransportChip(
                                        info: $0
                                    )
                                    .glassTransition()
                                }
                            }
                            .padding(
                                .horizontal,
                                4
                            )
                            .padding(
                                .vertical,
                                6
                            )
                        }
                    }

                    // MARK: Errors

                    ForEach(
                        engine.transportInfos.filter {
                            $0.state.error != nil
                        }
                    ) { t in

                        BannerCard(
                            icon:
                                "exclamationmark.triangle.fill",
                            text:
                                "\(t.label): \(t.state.error ?? "")"
                        )
                        .transition(
                            .move(edge: .top)
                            .combined(
                                with: .opacity
                            )
                        )
                    }

                    // MARK: Main Rooms

                    VStack(spacing: 10) {

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
                                    convId:
                                        EMERGENCY_ID,
                                    title:
                                        "Emergency SOS"
                                )
                        ) {

                            RowCard(
                                icon:
                                    "exclamationmark.octagon.fill",
                                title:
                                    "Emergency SOS",
                                subtitle:
                                    "High-priority alert to all nearby nodes",
                                tint:
                                    Theme.danger
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

                            Text(
                                "No peers detected yet. Ensure Bluetooth is enabled and devices are within close proximity."
                            )
                            .font(.subheadline)
                            .multilineTextAlignment(
                                .center
                            )
                            .foregroundStyle(
                                Color.white.opacity(0.7)
                            )
                            .padding(
                                .horizontal,
                                8
                            )
                        }
                        .padding(
                            .horizontal,
                            14
                        )
                        .padding(
                            .vertical,
                            22
                        )
                        .frame(
                            maxWidth: .infinity
                        )
                        .glassCard(
                            cornerRadius: 28
                        )
                        .transition(
                            .opacity
                            .combined(
                                with:
                                    .scale(
                                        scale: 0.96
                                    )
                            )
                        )
                    }

                    // MARK: Peers

                    ForEach(
                        engine.peers
                    ) { p in

                        NavigationLink(
                            destination:
                                ChatView(
                                    convId: p.id,
                                    title: p.nick
                                )
                        ) {

                            PeerRow(
                                p: p
                            )
                            .glassCard(cornerRadius: 24, glassID: p.id, namespace: peerNamespace)
                        }
                        .buttonStyle(
                            PressableStyle()
                        )
                        .transition(
                            .move(
                                edge: .trailing
                            )
                            .combined(
                                with: .opacity
                            )
                        )
                    }
                }
                .frame(
                    maxWidth: 620
                )
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .top,
                    6
                )
                .padding(
                    .bottom,
                    28
                )
                .animation(
                    .spring(
                        response: 0.5,
                        dampingFraction: 0.82
                    ),
                    value: peerKey
                )
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(
            "OffGrid Chat"
        )
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )
        .toolbar {

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
                .accessibilityLabel("Identity & QR")
                .accessibilityHint("View your cryptographic fingerprint and QR code")

                NavigationLink {

                    RadiosView()

                } label: {

                    Image(
                        systemName:
                            "waveform.badge.magnifyingglass"
                    )
                }
                .accessibilityLabel("Radios & Settings")
                .accessibilityHint("Configure mesh transports and visual themes")
            }
        }
    }
}


// MARK: - Chat View

struct ChatView: View {

    @EnvironmentObject var engine: MeshEngine

    let convId: String
    let title: String

    @State private var text = ""
    @State private var bounce = false
    @State private var glow = false

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
        convId == ROOM_ID ||
        convId == EMERGENCY_ID
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

    @ViewBuilder
    private func statusBadge(
        _ s: MsgStatus
    ) -> some View {

        HStack(spacing: 4) {

            switch s {

            case .queued:

                Image(
                    systemName:
                        "clock.fill"
                )
                .font(.caption2)

                Text("Queued")

            case .sent:

                Image(
                    systemName:
                        "checkmark"
                )
                .font(.caption2)

                Text("Sent")

            case .delivered:

                Image(
                    systemName:
                        "checkmark.2"
                )
                .font(.caption2)

                Text("Delivered")

            case .failed:

                Image(
                    systemName:
                        "exclamationmark.circle.fill"
                )
                .font(.caption2)

                Text(
                    "Failed · Tap to retry"
                )

            case .received:

                EmptyView()
            }
        }
        .font(
            .caption2.weight(.medium)
        )
        .foregroundStyle(
            s == .failed
            ? Theme.danger
            : Color.white.opacity(0.65)
        )
    }

    var body: some View {

        ZStack {

            AppBackground()

            VStack(spacing: 0) {

                VStack(spacing: 8) {

                    if let p = peer,
                       !p.verified {

                        BannerCard(
                            icon:
                                "shield.lefthalf.filled",
                            text:
                                "Unverified peer. Compare cryptographic fingerprint on their Identity screen.",
                            actionTitle:
                                "Verify"
                        ) {

                            Haptics.success()

                            engine.setVerified(
                                p.id
                            )
                        }
                        .transition(
                            .move(edge: .top)
                            .combined(
                                with: .opacity
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
                .padding(
                    .horizontal,
                    12
                )
                .padding(
                    .top,
                    8
                )
                .animation(
                    .spring(
                        response: 0.4,
                        dampingFraction: 0.85
                    ),
                    value:
                        peer?.verified
                )

                ScrollViewReader { proxy in

                    ScrollView {

                        LazyVStack(
                            spacing: 10
                        ) {

                            ForEach(
                                msgs
                            ) { m in

                                bubble(m)
                            }
                        }
                        .padding(
                            .horizontal,
                            14
                        )
                        .padding(
                            .vertical,
                            12
                        )
                        .animation(
                            .spring(
                                response: 0.45,
                                dampingFraction: 0.82
                            ),
                            value:
                                msgs.count
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
                            animated: true
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
        }
        .safeAreaInset(
            edge: .bottom
        ) {
            inputBar
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )
        .onAppear {

            guard isSOS else {
                return
            }

            withAnimation(
                .easeInOut(
                    duration: 1.0
                )
                .repeatForever(
                    autoreverses: true
                )
            ) {

                glow = true
            }
        }
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
                        duration: 0.3
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
        _ m: ChatMessage
    ) -> some View {

        let who =
            engine.peers.first {
                $0.id == m.senderId
            }?.nick
            ??
            String(
                m.senderId.prefix(6)
            )

        VStack(
            alignment:
                m.outgoing
                ? .trailing
                : .leading,
            spacing: 4
        ) {

            if isGroup &&
                !m.outgoing {

                HStack(spacing: 4) {

                    Image(
                        systemName:
                            "person.fill"
                    )
                    .font(.caption2)

                    Text(who)
                        .font(
                            .subheadline.weight(
                                .bold
                            )
                        )
                }
                .foregroundStyle(
                    Theme.accent
                )
            }

            if m.outgoing {

                Text(m.text)
                    .foregroundStyle(
                        Color.white
                    )
                    .padding(
                        .horizontal,
                        15
                    )
                    .padding(
                        .vertical,
                        11
                    )
                    .background(
                        Theme.outgoing,
                        in:
                            RoundedRectangle(
                                cornerRadius: 21,
                                style: .continuous
                            )
                    )
                    .shadow(
                        color:
                            Theme.accent.opacity(
                                0.35
                            ),
                        radius: 12,
                        y: 6
                    )

            } else {

                Text(m.text)
                    .foregroundStyle(
                        Color.white
                    )
                    .padding(
                        .horizontal,
                        15
                    )
                    .padding(
                        .vertical,
                        11
                    )
                    .glassCard(
                        cornerRadius: 21
                    )
            }

            if m.outgoing {

                statusBadge(
                    m.status
                )
                .animation(
                    .easeInOut(
                        duration: 0.25
                    ),
                    value:
                        m.status
                )
            }
        }
        .padding(
            .leading,
            m.outgoing ? 48 : 0
        )
        .padding(
            .trailing,
            m.outgoing ? 0 : 48
        )
        .frame(
            maxWidth: .infinity,
            alignment:
                m.outgoing
                ? .trailing
                : .leading
        )
        .id(m.id)
        .transition(
            .asymmetric(
                insertion:
                    .scale(
                        scale: 0.8,
                        anchor:
                            m.outgoing
                            ? .bottomTrailing
                            : .bottomLeading
                    )
                    .combined(
                        with: .opacity
                    ),

                removal:
                    .opacity
            )
        )
        .onTapGesture {

            if m.status == .failed {

                Haptics.warning()

                engine.retry(
                    m.id
                )
            }
        }
    }

    private var inputBar: some View {

        GlassGroup(spacing: 8) {

            HStack(spacing: 8) {

                TextField(
                    "",
                    text: $text,
                    prompt:
                        Text(
                            "Secure message..."
                        )
                        .foregroundColor(
                            Color.white.opacity(0.4)
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
                .padding(
                    .horizontal,
                    16
                )
                .padding(
                    .vertical,
                    12
                )
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity
                )
                .glassCard(
                    cornerRadius: 100
                )

                Button(
                    action: sendNow
                ) {

                    if isSOS {

                        HStack(spacing: 4) {

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
                        .padding(
                            .horizontal,
                            13
                        )
                        .frame(
                            height: 48
                        )

                    } else {

                        Image(
                            systemName:
                                "paperplane.fill"
                        )
                        .font(
                            .system(
                                size: 18,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            Color.white
                        )
                        .frame(
                            width: 48,
                            height: 48
                        )
                    }
                }
                .glassCard(
                    cornerRadius: 100,
                    tint:
                        isSOS
                        ? Theme.danger
                        : Theme.accent.opacity(0.7),
                    interactive: true
                )
                .scaleEffect(
                    bounce ? 1.12 : 1
                )
                .shadow(
                    color:
                        isSOS
                        ? Theme.danger.opacity(
                            glow ? 0.8 : 0.2
                        )
                        : Color.clear,
                    radius:
                        glow ? 18 : 6
                )
                .disabled(isEmpty)
                .opacity(
                    isEmpty ? 0.5 : 1
                )
                .animation(
                    .easeInOut(
                        duration: 0.2
                    ),
                    value: isEmpty
                )
                .accessibilityLabel("Send message")
            }
            .frame(
                maxWidth: .infinity
            )
        }
        .padding(
            .horizontal,
            12
        )
        .padding(
            .vertical,
            8
        )
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

        withAnimation(
            .spring(
                response: 0.25,
                dampingFraction: 0.45
            )
        ) {

            bounce = true
        }

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.15
        ) {

            withAnimation(
                .spring(
                    response: 0.3,
                    dampingFraction: 0.6
                )
            ) {

                bounce = false
            }
        }
    }
}


// MARK: - Identity

struct IdentityView: View {

    @EnvironmentObject var engine: MeshEngine

    @State private var scanning = false
    @State private var result: String?
    @State private var copied = false
    @State private var qrPic = UIImage()

    var body: some View {

        ZStack {

            AppBackground()

            ScrollView {

                VStack(spacing: 16) {

                    // MARK: Fingerprint

                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {

                        SectionTitle(
                            "Cryptographic Fingerprint"
                        )

                        Text(
                            Crypto.fingerprint(
                                engine.me
                            )
                        )
                        .font(
                            .system(
                                .caption,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(
                            Color.white
                        )
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)

                        Button {

                            UIPasteboard.general.string =
                                Crypto.fingerprint(
                                    engine.me
                                )

                            Haptics.success()

                            withAnimation {

                                copied = true
                            }

                            DispatchQueue.main.asyncAfter(
                                deadline:
                                    .now() + 1.5
                            ) {

                                withAnimation {

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
                        }
                        .foregroundStyle(
                            Theme.accent
                        )
                        .buttonStyle(
                            PressableStyle()
                        )
                        .accessibilityLabel("Copy cryptographic fingerprint")
                    }
                    .padding(16)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .glassCard(
                        cornerRadius: 24
                    )

                    // MARK: QR

                    VStack(spacing: 14) {

                        Image(
                            uiImage: qrPic
                        )
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: 210,
                            height: 210
                        )
                        .padding(14)
                        .background(
                            Color.white,
                            in:
                                RoundedRectangle(
                                    cornerRadius: 26,
                                    style: .continuous
                                )
                        )
                        .shadow(
                            color:
                                Theme.accent.opacity(0.4),
                            radius: 24
                        )

                        Text(
                            "Show this QR code to a friend in person to securely verify your mesh identity."
                        )
                        .font(.subheadline)
                        .multilineTextAlignment(
                            .center
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.8)
                        )
                        .padding(
                            .horizontal,
                            8
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
                        }
                        .buttonStyle(
                            GlassButtonStyle(
                                tint:
                                    Theme.accent.opacity(0.7)
                            )
                        )
                        .accessibilityLabel("Scan peer QR code")

                        if let r = result {

                            Label(
                                r,
                                systemImage:
                                    "checkmark.shield.fill"
                            )
                            .font(
                                .subheadline.weight(
                                    .semibold
                                )
                            )
                            .foregroundStyle(
                                Theme.mint
                            )
                            .multilineTextAlignment(
                                .center
                            )
                            .transition(
                                .scale
                                .combined(
                                    with: .opacity
                                )
                            )
                        }
                    }
                    .padding(18)
                    .frame(
                        maxWidth: .infinity
                    )
                    .glassCard(
                        cornerRadius: 30
                    )

                    SectionTitle(
                        "Known Peer Identities"
                    )

                    // MARK: Known Peers

                    ForEach(
                        engine.peers
                    ) { p in

                        VStack(
                            alignment: .leading,
                            spacing: 7
                        ) {

                            HStack {

                                Text(p.nick)
                                    .font(
                                        .system(
                                            .headline,
                                            design: .rounded
                                        )
                                        .weight(
                                            .semibold
                                        )
                                    )
                                    .foregroundStyle(
                                        Color.white
                                    )
                                    .lineLimit(1)

                                Spacer()

                                Label(
                                    p.verified
                                    ? "Verified"
                                    : "Unverified",
                                    systemImage:
                                        p.verified
                                        ? "checkmark.seal.fill"
                                        : "exclamationmark.shield"
                                )
                                .font(
                                    .caption.weight(
                                        .semibold
                                    )
                                )
                                .foregroundStyle(
                                    p.verified
                                    ? Theme.mint
                                    : Theme.danger
                                )
                            }

                            Text(
                                p.fingerprint
                            )
                            .font(
                                .system(
                                    .caption2,
                                    design: .monospaced
                                )
                            )
                            .foregroundStyle(
                                Color.white.opacity(0.75)
                            )
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)

                            if !p.verified {

                                Button(
                                    "Confirm Fingerprint Match"
                                ) {

                                    Haptics.success()

                                    engine.setVerified(
                                        p.id
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
                                .buttonStyle(
                                    PressableStyle()
                                )
                            }
                        }
                        .padding(14)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .glassCard(
                            cornerRadius: 22
                        )
                        .accessibilityElement(children: .combine)
                        .transition(
                            .opacity
                            .combined(
                                with:
                                    .scale(
                                        scale: 0.96
                                    )
                            )
                        )
                    }
                }
                .frame(
                    maxWidth: 620
                )
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .bottom,
                    28
                )
                .animation(
                    .spring(
                        response: 0.5,
                        dampingFraction: 0.85
                    ),
                    value: result
                )
                .animation(
                    .spring(
                        response: 0.5,
                        dampingFraction: 0.85
                    ),
                    value:
                        engine.peers.count
                )
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(
            "Identity & Security"
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

                    if let n =
                        engine.verifyFromQr(
                            code
                        ) {

                        result =
                            "Successfully verified \(n)"

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
    private var selectedTheme: AppThemeStyle =
        .midnightBlue

    @State private var host =
        UserDefaults.standard.string(
            forKey: "lanHost"
        ) ?? ""

    @State private var confirmStop = false

    var body: some View {

        ZStack {

            AppBackground()

            ScrollView {

                VStack(spacing: 16) {

                    // MARK: Theme

                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {

                        Label(
                            "Visual Theme",
                            systemImage:
                                "paintpalette.fill"
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
                            Color.white.opacity(0.7)
                        )
                    }
                    .padding(14)
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
                    ) { t in

                        HStack(
                            alignment: .top,
                            spacing: 12
                        ) {

                            StatusDot(
                                on:
                                    t.state.active &&
                                    t.state.links > 0,
                                size: 9
                            )

                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {

                                Text(
                                    "\(t.label): \(t.state.active ? "Active" : "Inactive") · \(t.state.links) link(s)"
                                )
                                .font(
                                    .system(
                                        .headline,
                                        design: .rounded
                                    )
                                    .weight(
                                        .semibold
                                    )
                                )
                                .foregroundStyle(
                                    Color.white
                                )
                                .lineLimit(2)

                                Text(
                                    t.state.detail
                                )
                                .font(
                                    .subheadline
                                )
                                .foregroundStyle(
                                    Color.white.opacity(0.75)
                                )

                                if let e =
                                    t.state.error {

                                    Text(e)
                                        .font(
                                            .subheadline
                                        )
                                        .foregroundStyle(
                                            Theme.danger
                                        )
                                }
                            }

                            Spacer(
                                minLength: 0
                            )
                        }
                        .padding(14)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .glassCard(
                            cornerRadius: 22
                        )
                        .accessibilityElement(children: .combine)
                        .transition(
                            .move(
                                edge: .leading
                            )
                            .combined(
                                with: .opacity
                            )
                        )
                    }

                    // MARK: LAN Host

                    SectionTitle(
                        "Android Hotspot Host (Optional)"
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {

                        TextField(
                            "",
                            text: $host,
                            prompt:
                                Text(
                                    "Host IP (e.g. 192.168.43.1)"
                                )
                                .foregroundColor(
                                    Color.white.opacity(0.4)
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
                        .padding(
                            .horizontal,
                            15
                        )
                        .padding(
                            .vertical,
                            13
                        )
                        .frame(
                            maxWidth: .infinity
                        )
                        .glassCard(
                            cornerRadius: 18
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
                            Color.white.opacity(0.75)
                        )
                    }
                    .padding(14)
                    .glassCard(
                        cornerRadius: 24
                    )

                    // MARK: Node Controls

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {

                        Text(
                            "iOS suspends background execution. Bluetooth maintains limited connectivity, but backgrounded iPhones may not be discoverable by Android nodes. Keep the app open for optimal mesh routing."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            Color.white.opacity(0.75)
                        )

                        HStack(
                            spacing: 8
                        ) {

                            Button {

                                Haptics.tap()

                                engine.start()

                            } label: {

                                Label(
                                    "Restart Node",
                                    systemImage:
                                        "arrow.clockwise"
                                )
                            }
                            .buttonStyle(
                                GlassButtonStyle(
                                    tint:
                                        Theme.accent.opacity(
                                            0.7
                                        )
                                )
                            )
                            .frame(
                                maxWidth: .infinity
                            )

                            Button(
                                role: .destructive
                            ) {

                                confirmStop = true

                            } label: {

                                Label(
                                    "Stop Mesh",
                                    systemImage:
                                        "power"
                                )
                            }
                            .buttonStyle(
                                GlassButtonStyle(
                                    tint:
                                        Theme.danger.opacity(
                                            0.7
                                        )
                                )
                            )
                            .frame(
                                maxWidth: .infinity
                            )
                        }
                    }
                    .padding(14)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .glassCard(
                        cornerRadius: 24
                    )
                }
                .frame(
                    maxWidth: 620
                )
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .bottom,
                    28
                )
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(
            "Radios & Settings"
        )
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )
        .confirmationDialog(
            "Stop OffGrid Chat?",
            isPresented:
                $confirmStop,
            titleVisibility:
                .visible
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
