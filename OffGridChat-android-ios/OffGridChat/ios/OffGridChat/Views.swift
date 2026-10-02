import SwiftUI
import UIKit

// =====================================================================================
//  OffGrid Chat: Next-Gen iOS Liquid Glass UI (Theme Toggle & Professional Icons)
//  Presentation layer only. All behavior routes through `engine` exactly as before.
// =====================================================================================

// MARK: - App Themes & Configuration

enum AppThemeStyle: String, CaseIterable, Identifiable {
    case midnightBlue = "Midnight Blue"
    case obsidianTeal = "Obsidian Teal"
    var id: String { rawValue }
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
        case .midnightBlue: return Color(red: 0.02, green: 0.02, blue: 0.08)
        case .obsidianTeal: return Color(red: 0.01, green: 0.05, blue: 0.06)
        }
    }
    
    static var accent: Color {
        switch ThemeManager.currentTheme {
        case .midnightBlue: return Color(red: 0.20, green: 0.55, blue: 1.00)
        case .obsidianTeal: return Color(red: 0.00, green: 0.85, blue: 0.75)
        }
    }
    
    static var secondaryAccent: Color {
        switch ThemeManager.currentTheme {
        case .midnightBlue: return Color(red: 0.55, green: 0.30, blue: 0.95)
        case .obsidianTeal: return Color(red: 0.10, green: 0.50, blue: 0.60)
        }
    }

    static var mint: Color { Color(red: 0.30, green: 0.92, blue: 0.65) }
    static var danger: Color { Color(red: 1.00, green: 0.30, blue: 0.40) }

    static var outgoing: LinearGradient {
        switch ThemeManager.currentTheme {
        case .midnightBlue:
            return LinearGradient(colors: [Color(red: 0.15, green: 0.50, blue: 1.0), Color(red: 0.45, green: 0.28, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .obsidianTeal:
            return LinearGradient(colors: [Color(red: 0.00, green: 0.70, blue: 0.65), Color(red: 0.05, green: 0.35, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    static var title: LinearGradient {
        LinearGradient(colors: [Color.white, accent, secondaryAccent], startPoint: .leading, endPoint: .trailing)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - Liquid Glass & Advanced Styling

#if compiler(>=6.2)
@available(iOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var g = Glass.regular
    if let tint { g = g.tint(tint) }
    if interactive { g = g.interactive() }
    return g
}
#endif

extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.frostedGlass(cornerRadius: cornerRadius, tint: tint)
        }
        #else
        self.frostedGlass(cornerRadius: cornerRadius, tint: tint)
        #endif
    }

    fileprivate func frostedGlass(cornerRadius: CGFloat, tint: Color?) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(.ultraThinMaterial, in: shape)
            .background(shape.fill((tint ?? Color.white).opacity(tint == nil ? 0.06 : 0.22)))
            .overlay(
                VStack {
                    LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 1.2)
                    Spacer()
                }
                .mask(shape)
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.04), Color.black.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
    }
}


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
            GlassEffectContainer(spacing: spacing) {
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


struct GlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .glassCard(cornerRadius: 100, tint: tint, interactive: true)
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Dynamic Backgrounds (Inspired by Reference Images)

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.base.ignoresSafeArea()
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

/// Curved glowing blue wave background inspired by the reference wallpaper
struct MidnightBlueWaveBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var waveAnim = false
    
    var body: some View {
        ZStack {
            // Glowing upper blue orb
            Circle()
                .fill(Color(red: 0.05, green: 0.35, blue: 0.85).opacity(0.45))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -120, y: waveAnim ? -220 : -180)
            
            // Glowing lower indigo/violet orb
            Circle()
                .fill(Color(red: 0.30, green: 0.15, blue: 0.70).opacity(0.4))
                .frame(width: 450, height: 450)
                .blur(radius: 90)
                .offset(x: 140, y: waveAnim ? 300 : 250)
            
            // S-curve wave gradient overlay
            LinearGradient(colors: [Color(red: 0.0, green: 0.4, blue: 0.9).opacity(0.3), Color.clear, Color(red: 0.4, green: 0.2, blue: 0.8).opacity(0.3)],
                           startPoint: waveAnim ? .topLeading : .bottomLeading,
                           endPoint: waveAnim ? .bottomTrailing : .topTrailing)
                .blur(radius: 50)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                waveAnim.toggle()
            }
        }
    }
}

/// Glowing teal tubular mesh background inspired by the obsidian teal reference image
struct ObsidianTealTubeBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowAnim = false
    
    var body: some View {
        ZStack {
            // Deep teal glowing nodes
            Ellipse()
                .fill(Color(red: 0.0, green: 0.65, blue: 0.55).opacity(0.35))
                .frame(width: 380, height: 500)
                .blur(radius: 85)
                .offset(x: glowAnim ? 100 : -100, y: -150)
            
            Ellipse()
                .fill(Color(red: 0.0, green: 0.45, blue: 0.70).opacity(0.3))
                .frame(width: 420, height: 450)
                .blur(radius: 95)
                .offset(x: glowAnim ? -80 : 80, y: 200)
            
            // Neon mesh sheen
            LinearGradient(colors: [Color(red: 0.0, green: 0.8, blue: 0.7).opacity(0.15), Color.clear, Color(red: 0.0, green: 0.5, blue: 0.6).opacity(0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .blur(radius: 60)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                glowAnim.toggle()
            }
        }
    }
}

// MARK: - Polished Micro-Components (Zero Emojis)

struct StatusDot: View {
    let on: Bool
    var size: CGFloat = 10
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            if on {
                Circle().fill(Theme.mint.opacity(0.4)).frame(width: size * 2.2, height: size * 2.2)
                    .scaleEffect(pulse ? 1.8 : 1).opacity(pulse ? 0 : 0.8)
            }
            Circle().fill(on ? Theme.mint : Color.white.opacity(0.3)).frame(width: size, height: size)
                .shadow(color: on ? Theme.mint.opacity(0.6) : Color.clear, radius: 4)
        }
        .frame(width: size * 2.5, height: size * 2.5)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { pulse = true }
        }
        .animation(.easeInOut(duration: 0.3), value: on)
    }
}

struct RadarView: View {
    @State private var go = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(LinearGradient(colors: [Theme.accent, Theme.secondaryAccent], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                    .scaleEffect(go ? 1.15 : 0.2).opacity(go ? 0 : 0.85)
                    .animation(reduceMotion ? nil :
                        .easeOut(duration: 2.6).repeatForever(autoreverses: false).delay(Double(i) * 0.9), value: go)
            }
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.title)
                .shadow(color: Theme.accent.opacity(0.6), radius: 12)
        }
        .frame(width: 150, height: 150)
        .onAppear { go = true }
    }
}

struct Avatar: View {
    let name: String
    let online: Bool
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Theme.accent, Theme.secondaryAccent],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(Color.white)
        }
        .frame(width: 50, height: 50)
        .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
        .overlay(alignment: .bottomTrailing) {
            Circle().fill(online ? Theme.mint : Color.gray).frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 2.5))
                .shadow(color: online ? Theme.mint.opacity(0.8) : Color.clear, radius: 4)
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(spacing: 6) {
            Text(text.uppercased())
                .font(.system(.caption, design: .rounded).weight(.bold)).tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.7))
            Spacer()
        }
        .padding(.top, 12).padding(.leading, 6)
    }
}

struct RowCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = Theme.accent
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(tint.opacity(0.35)).shadow(color: tint.opacity(0.5), radius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(.headline, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
                Text(subtitle).font(.subheadline).foregroundStyle(Color.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 26, tint: tint.opacity(0.12))
    }
}

struct PeerRow: View {
    let p: PeerView
    var body: some View {
        HStack(spacing: 16) {
            Avatar(name: p.nick, online: p.online)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(p.nick).font(.system(.headline, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
                    if p.verified {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.accent).font(.subheadline)
                            .shadow(color: Theme.accent.opacity(0.7), radius: 5)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: p.online ? "antenna.radiowaves.left.and.right" : "moon.zzz.fill")
                        .font(.caption2)
                    Text(p.online ? "\(p.hops) hop(s) · \(p.via) \(p.signal)" : "offline · messages will queue")
                }
                .font(.subheadline).foregroundStyle(Color.white.opacity(0.7))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 26)
        .animation(.easeInOut(duration: 0.3), value: p.verified)
    }
}

struct BannerCard: View {
    let icon: String
    let text: String
    var tint: Color = Theme.danger
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(tint)
            Text(text).font(.subheadline).foregroundStyle(Color.white).frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22, tint: tint.opacity(0.28))
    }
}

struct TransportChip: View {
    let info: TransportInfo
    var body: some View {
        HStack(spacing: 7) {
            StatusDot(on: info.state.active && info.state.links > 0, size: 6)
            Text(info.label).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
            Text(info.state.active ? "\(info.state.links)" : "off")
                .font(.caption).foregroundStyle(Color.white.opacity(0.75))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .glassCard(cornerRadius: 100)
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var engine: MeshEngine

    @AppStorage("selectedTheme")
    private var selectedTheme: AppThemeStyle = .midnightBlue
    var body: some View {
        Group {
            if engine.nickname.isEmpty {
                NicknameView().transition(.opacity.combined(with: .scale(scale: 1.05)))
            } else {
                NavigationStack { PeersView() }.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: engine.nickname.isEmpty)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .id(selectedTheme)
    }
}

// MARK: - Nickname

struct NicknameView: View {
    @EnvironmentObject var engine: MeshEngine
    @State private var nick = ""
    @State private var appeared = false
    private var isEmpty: Bool { nick.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 28) {
                Spacer()
                RadarView().scaleEffect(appeared ? 1 : 0.6).opacity(appeared ? 1 : 0)
                VStack(spacing: 12) {
                    Text("OffGrid Chat")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.title)
                        .shadow(color: Theme.accent.opacity(0.4), radius: 14)
                    Text("Secure decentralized mesh communication. Operates entirely off-grid via Bluetooth and local Wi-Fi.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center).foregroundStyle(Color.white.opacity(0.8))
                        .padding(.horizontal, 10)
                }
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 14) {
                    Label("Choose Nickname", systemImage: "person.crop.circle.badge.plus")
                        .font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                    
                    TextField("", text: $nick, prompt: Text("Enter display name").foregroundColor(Color.white.opacity(0.4)))
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .glassCard(cornerRadius: 18)
                    
                    Text("No account required. Your cryptographic keypair verifies your identity across the mesh.")
                        .font(.subheadline).foregroundStyle(Color.white.opacity(0.65))
                    
                    Button {
                        Haptics.success()
                        engine.setNickname(nick)
                    } label: {
                        HStack {
                            Text("Initialize Node")
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Theme.accent.opacity(0.8)))
                    .disabled(isEmpty).opacity(isEmpty ? 0.5 : 1)
                    .animation(.easeInOut(duration: 0.25), value: isEmpty)
                }
                .padding(24).glassCard(cornerRadius: 34)
                .offset(y: appeared ? 0 : 40).opacity(appeared ? 1 : 0)
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) { appeared = true } }
    }
}

// MARK: - People (PeersView)

struct PeersView: View {
    @EnvironmentObject var engine: MeshEngine

    private var peerKey: [String] { engine.peers.map { $0.id + ($0.online ? "1" : "0") } }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    GlassGroup(spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(engine.transportInfos) { TransportChip(info: $0) }
                            }.padding(.horizontal, 6).padding(.vertical, 8)
                        }
                    }

                    ForEach(engine.transportInfos.filter { $0.state.error != nil }) { t in
                        BannerCard(icon: "exclamationmark.triangle.fill", text: "\(t.label): \(t.state.error ?? "")")
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    VStack(spacing: 12) {
                        NavigationLink(destination: ChatView(convId: ROOM_ID, title: "Group Room")) {
                            RowCard(icon: "person.3.fill", title: "Group Room",
                                    subtitle: "Broadcast to all reachable mesh nodes (signed)")
                        }.buttonStyle(PressableStyle())

                        NavigationLink(destination: ChatView(convId: EMERGENCY_ID, title: "Emergency SOS")) {
                            RowCard(icon: "exclamationmark.octagon.fill", title: "Emergency SOS",
                                    subtitle: "High-priority alert to all nearby nodes", tint: Theme.danger)
                        }.buttonStyle(PressableStyle())
                    }

                    SectionTitle("Discovered Nodes")

                    if engine.peers.isEmpty {
                        VStack(spacing: 14) {
                            RadarView()
                            Text("Scanning Mesh Network…").font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                            Text("No peers detected yet. Ensure Bluetooth is enabled and devices are within close proximity.")
                                .font(.subheadline).multilineTextAlignment(.center)
                                .foregroundStyle(Color.white.opacity(0.7)).padding(.horizontal, 16)
                        }
                        .padding(.vertical, 32).frame(maxWidth: .infinity)
                        .glassCard(cornerRadius: 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    ForEach(engine.peers) { p in
                        NavigationLink(destination: ChatView(convId: p.id, title: p.nick)) {
                            PeerRow(p: p)
                        }
                        .buttonStyle(PressableStyle())
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 32)
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: peerKey)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("OffGrid Mesh")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink { IdentityView() } label: { Image(systemName: "qrcode.viewfinder") }
                    .accessibilityLabel("Identity")
                NavigationLink { RadiosView() } label: { Image(systemName: "waveform.badge.magnifyingglass") }
                    .accessibilityLabel("Radios & Settings")
            }
        }
    }
}

// MARK: - Chat

struct ChatView: View {
    @EnvironmentObject var engine: MeshEngine
    let convId: String
    let title: String
    @State private var text = ""
    @State private var bounce = false
    @State private var glow = false

    private var msgs: [ChatMessage] { engine.messages.filter { $0.convId == convId }.sorted { $0.ts < $1.ts } }
    private var isGroup: Bool { convId == ROOM_ID || convId == EMERGENCY_ID }
    private var isSOS: Bool { convId == EMERGENCY_ID }
    private var peer: PeerView? { engine.peers.first { $0.id == convId } }
    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    @ViewBuilder
    private func statusBadge(_ s: MsgStatus) -> some View {
        HStack(spacing: 4) {
            switch s {
            case .queued:
                Image(systemName: "clock.fill").font(.caption2)
                Text("Queued")
            case .sent:
                Image(systemName: "checkmark").font(.caption2)
                Text("Sent")
            case .delivered:
                Image(systemName: "checkmark.2").font(.caption2)
                Text("Delivered")
            case .failed:
                Image(systemName: "exclamationmark.circle.fill").font(.caption2)
                Text("Failed · Tap to retry")
            case .received:
                EmptyView()
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(s == .failed ? Theme.danger : Color.white.opacity(0.65))
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    if let p = peer, !p.verified {
                        BannerCard(icon: "shield.lefthalf.filled",
                                   text: "Unverified peer. Compare cryptographic fingerprint on their Identity screen.",
                                   actionTitle: "Verify") {
                            Haptics.success()
                            engine.setVerified(p.id)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if isSOS {
                        BannerCard(icon: "exclamationmark.octagon.fill",
                                   text: "Emergency Broadcast active. Messages are signed and broadcast globally across the mesh.")
                    }
                }
                .padding(.horizontal, 14).padding(.top, 10)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: peer?.verified)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(msgs) { m in bubble(m) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 14)
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: msgs.count)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: msgs.count) { _ in scrollToEnd(proxy, animated: true) }
                    .onAppear { scrollToEnd(proxy, animated: false) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            guard isSOS else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let last = msgs.last else { return }
        DispatchQueue.main.async {
            if animated { withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(last.id, anchor: .bottom) } }
            else { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        let who = engine.peers.first { $0.id == m.senderId }?.nick ?? String(m.senderId.prefix(6))
        VStack(alignment: m.outgoing ? .trailing : .leading, spacing: 5) {
            if isGroup && !m.outgoing {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill").font(.caption2)
                    Text(who).font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Theme.accent)
            }
            if m.outgoing {
                Text(m.text).foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.outgoing, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 6)
            } else {
                Text(m.text).foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .glassCard(cornerRadius: 22)
            }
            if m.outgoing {
                statusBadge(m.status)
                    .animation(.easeInOut(duration: 0.25), value: m.status)
            }
        }
        .padding(.leading, m.outgoing ? 64 : 0).padding(.trailing, m.outgoing ? 0 : 64)
        .frame(maxWidth: .infinity, alignment: m.outgoing ? .trailing : .leading)
        .id(m.id)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8, anchor: m.outgoing ? .bottomTrailing : .bottomLeading).combined(with: .opacity),
            removal: .opacity))
        .onTapGesture { if m.status == .failed { Haptics.warning(); engine.retry(m.id) } }
    }

    private var inputBar: some View {
        GlassGroup(spacing: 12) {
            HStack(spacing: 12) {
                TextField("", text: $text, prompt: Text("Secure message...").foregroundColor(Color.white.opacity(0.4)))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .glassCard(cornerRadius: 100)

                Button(action: sendNow) {
                    if isSOS {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("SOS")
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.white).padding(.horizontal, 18).frame(height: 50)
                    } else {
                        Image(systemName: "paperplane.fill").font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color.white).frame(width: 50, height: 50)
                    }
                }
                .glassCard(cornerRadius: 100, tint: isSOS ? Theme.danger : Theme.accent.opacity(0.7), interactive: true)
                .scaleEffect(bounce ? 1.2 : 1)
                .shadow(color: isSOS ? Theme.danger.opacity(glow ? 0.8 : 0.2) : Color.clear, radius: glow ? 18 : 6)
                .disabled(isEmpty).opacity(isEmpty ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.2), value: isEmpty)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func sendNow() {
        guard !isEmpty else { return }
        engine.send(to: convId, text)
        text = ""
        if isSOS { Haptics.warning() } else { Haptics.tap() }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { bounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bounce = false }
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
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Cryptographic Fingerprint")
                        Text(Crypto.fingerprint(engine.me))
                            .font(.system(.subheadline, design: .monospaced)).foregroundStyle(Color.white)
                        Button {
                            UIPasteboard.general.string = Crypto.fingerprint(engine.me)
                            Haptics.success()
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { copied = false } }
                        } label: {
                            Label(copied ? "Copied to Clipboard" : "Copy Fingerprint", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 26)

                    VStack(spacing: 16) {
                        Image(uiImage: qrPic).interpolation(.none).resizable().scaledToFit()
                            .frame(width: 230, height: 230).padding(16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: Theme.accent.opacity(0.4), radius: 28)
                        
                        Text("Show this QR code to a friend in person to securely verify your mesh identity.")
                            .font(.subheadline).multilineTextAlignment(.center)
                            .foregroundStyle(Color.white.opacity(0.8))
                        
                        Button { scanning = true } label: {
                            Label("Scan Peer QR Code", systemImage: "qrcode.viewfinder")
                        }
                        .buttonStyle(GlassButtonStyle(tint: Theme.accent.opacity(0.7)))
                        
                        if let r = result {
                            Label(r, systemImage: "checkmark.shield.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.mint)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(20).frame(maxWidth: .infinity)
                    .glassCard(cornerRadius: 32)

                    SectionTitle("Known Peer Identities")
                    ForEach(engine.peers) { p in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(p.nick).font(.system(.headline, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
                                Spacer()
                                Label(p.verified ? "Verified" : "Unverified", systemImage: p.verified ? "checkmark.seal.fill" : "exclamationmark.shield")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(p.verified ? Theme.mint : Theme.danger)
                            }
                            Text(p.fingerprint).font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.75))
                            if !p.verified {
                                Button("Confirm Fingerprint Match") {
                                    Haptics.success()
                                    engine.setVerified(p.id)
                                }
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 32)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: result)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: engine.peers.count)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Identity & Security")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { qrPic = qrImage(engine.myQr()) }
        .sheet(isPresented: $scanning) {
            ZStack(alignment: .topTrailing) {
                QRScannerView { code in
                    scanning = false
                    if let n = engine.verifyFromQr(code) {
                        result = "Successfully verified \(n)"; Haptics.success()
                    } else {
                        result = "Invalid OffGrid QR code"; Haptics.warning()
                    }
                }
                .ignoresSafeArea()
                Button("Cancel") { scanning = false }
                    .buttonStyle(GlassButtonStyle()).padding()
            }
        }
    }
}

// MARK: - Radios & Settings

struct RadiosView: View {
    @EnvironmentObject var engine: MeshEngine

    @AppStorage("selectedTheme")
    private var selectedTheme: AppThemeStyle = .midnightBlue

    @State private var host = UserDefaults.standard.string(forKey: "lanHost") ?? ""
    @State private var confirmStop = false
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    // Theme Switcher Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Visual Theme", systemImage: "paintpalette.fill")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Color.white)
                        
                    
                        Picker("Theme", selection: $selectedTheme) {
                            ForEach(AppThemeStyle.allCases) { theme in
                                Text(theme.rawValue)
                                    .tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text("Switch between Midnight Blue and Obsidian Teal design aesthetics.")
                            .font(.subheadline).foregroundStyle(Color.white.opacity(0.7))
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 24)

                    ForEach(engine.transportInfos) { t in
                        HStack(alignment: .top, spacing: 14) {
                            StatusDot(on: t.state.active && t.state.links > 0)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(t.label): \(t.state.active ? "Active" : "Inactive") · \(t.state.links) link(s)")
                                    .font(.system(.headline, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
                                Text(t.state.detail).font(.subheadline).foregroundStyle(Color.white.opacity(0.75))
                                if let e = t.state.error {
                                    Text(e).font(.subheadline).foregroundStyle(Theme.danger)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 24)
                    }

                    SectionTitle("Android Hotspot Host (Optional)")
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("",
                                text: $host,
                                prompt: Text("Host IP (e.g. 192.168.43.1)").foregroundColor(Color.white.opacity(0.4)))
                            .font(.system(.body, design: .rounded))
                            .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .glassCard(cornerRadius: 18)
                            .onChange(of: host) { engine.lan.manualHost = $0 }
                        
                        Text("Connect to the Android hotspot Wi-Fi in iOS Settings, then open this app and enable Local Network access.")
                            .font(.subheadline).foregroundStyle(Color.white.opacity(0.75))
                    }
                    .padding(16).glassCard(cornerRadius: 26)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("iOS suspends background execution. Bluetooth maintains limited connectivity, but backgrounded iPhones may not be discoverable by Android nodes. Keep the app open for optimal mesh routing.")
                            .font(.subheadline).foregroundStyle(Color.white.opacity(0.75))
                        
                        HStack(spacing: 12) {
                            Button { Haptics.tap(); engine.start() } label: {
                                Label("Restart Node", systemImage: "arrow.clockwise")
                            }.buttonStyle(GlassButtonStyle(tint: Theme.accent.opacity(0.7)))
                            
                            Button(role: .destructive) { confirmStop = true } label: {
                                Label("Stop Mesh", systemImage: "power")
                            }.buttonStyle(GlassButtonStyle(tint: Theme.danger.opacity(0.7)))
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 26)
                }
                .padding(.horizontal, 16).padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Radios & Settings")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Stop OffGrid Chat?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Stop", role: .destructive) { engine.stop() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mesh radios will power down and you will stop receiving transmissions until restarted.")
        }
    }
}
