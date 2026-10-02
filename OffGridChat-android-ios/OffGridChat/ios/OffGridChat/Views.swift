import SwiftUI
import UIKit

// =====================================================================================
//  OffGrid Chat: Next-Gen iOS Liquid Glass UI (Inspired by iOS 26/27 Aesthetics)
//  Presentation layer only. All behavior routes through `engine` exactly as before.
// =====================================================================================

// MARK: - Theme

enum Theme {
    static let deep   = Color(red: 0.03, green: 0.02, blue: 0.14)
    static let violet = Color(red: 0.22, green: 0.09, blue: 0.44)
    static let ocean  = Color(red: 0.02, green: 0.26, blue: 0.48)
    static let pink   = Color(red: 0.55, green: 0.15, blue: 0.58)
    static let aqua   = Color(red: 0.35, green: 0.82, blue: 1.00)
    static let lilac  = Color(red: 0.68, green: 0.52, blue: 1.00)
    static let mint   = Color(red: 0.30, green: 0.92, blue: 0.65)
    static let danger = Color(red: 1.00, green: 0.30, blue: 0.40)

    static let outgoing = LinearGradient(
        colors: [Color(red: 0.15, green: 0.50, blue: 1.0), Color(red: 0.45, green: 0.28, blue: 0.95)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    
    static let title = LinearGradient(
        colors: [Color.white, aqua, lilac],
        startPoint: .leading, endPoint: .trailing)
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - Liquid Glass & Advanced Styling (with automatic fallback)

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
    /// Next-Gen Liquid Glass on iOS 26+, high-end multi-layer frosted material everywhere else.
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
            .background(shape.fill((tint ?? Color.white).opacity(tint == nil ? 0.05 : 0.20)))
            .overlay(
                // Specular top highlight & gradient border inspired by reference aesthetics
                VStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 1.2)
                    Spacer()
                }
                .mask(shape)
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.04), Color.black.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)
    }
}

/// Lets nearby glass shapes blend/morph together on iOS 26+; pass-through otherwise.
struct GlassGroup: View {
    let spacing: CGFloat
    let content: () -> Content
    init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing; self.content = content
    }
    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
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

// MARK: - Immersive Dynamic Background

struct AppBackground: View {
    var body: some View {
        Group {
            #if compiler(>=6.0)
            if #available(iOS 18.0, *) { MeshBackground() } else { GradientBackground() }
            #else
            GradientBackground()
            #endif
        }
        .ignoresSafeArea()
    }
}

#if compiler(>=6.0)
@available(iOS 18.0, *)
struct MeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0.0 : ctx.date.timeIntervalSinceReferenceDate
            let dx = Float(0.12 * sin(t * 0.25))
            let dy = Float(0.12 * cos(t * 0.20))
            let points: [SIMD2] = [
                SIMD2(0, 0), SIMD2(0.5 + dx, 0), SIMD2(1, 0),
                SIMD2(0, 0.5 - dy), SIMD2(0.5 + dy, 0.5 + dx), SIMD2(1, 0.5 + dy),
                SIMD2(0, 1), SIMD2(0.5 - dx, 1), SIMD2(1, 1)
            ]
            MeshGradient(width: 3, height: 3, points: points, colors: [
                Theme.deep, Theme.violet, Theme.deep,
                Theme.ocean, Theme.pink, Theme.violet,
                Theme.deep, Theme.ocean, Theme.deep
            ])
        }
    }
}
#endif

struct GradientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shift = false
    var body: some View {
        LinearGradient(colors: [Theme.deep, Theme.violet, Theme.ocean, Theme.pink],
                       startPoint: shift ? .topLeading : .bottomLeading,
                       endPoint: shift ? .bottomTrailing : .topTrailing)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { shift = true }
            }
    }
}

// MARK: - Polished Micro-Components

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
                    .stroke(LinearGradient(colors: [Theme.aqua, Theme.lilac], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                    .scaleEffect(go ? 1.1 : 0.15).opacity(go ? 0 : 0.85)
                    .animation(reduceMotion ? nil :
                        .easeOut(duration: 2.6).repeatForever(autoreverses: false).delay(Double(i) * 0.9), value: go)
            }
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.title)
                .shadow(color: Theme.aqua.opacity(0.5), radius: 10)
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
            Circle().fill(LinearGradient(colors: [Theme.aqua, Theme.violet],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(Color.white)
        }
        .frame(width: 48, height: 48)
        .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
        .overlay(alignment: .bottomTrailing) {
            Circle().fill(online ? Theme.mint : Color.gray).frame(width: 13, height: 13)
                .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 2.5))
                .shadow(color: online ? Theme.mint.opacity(0.7) : Color.clear, radius: 4)
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption, design: .rounded).weight(.bold)).tracking(1.4)
            .foregroundStyle(Color.white.opacity(0.65))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8).padding(.leading, 6)
    }
}

struct RowCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = Theme.aqua
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.white)
                .frame(width: 50, height: 50)
                .background(Circle().fill(tint.opacity(0.3)).shadow(color: tint.opacity(0.4), radius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.headline, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
                Text(subtitle).font(.subheadline).foregroundStyle(Color.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 26, tint: tint.opacity(0.1))
    }
}

struct PeerRow: View {
    let p: PeerView
    var body: some View {
        HStack(spacing: 16) {
            Avatar(name: p.nick, online: p.online)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(p.nick).font(.system(.headline, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
                    if p.verified {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.aqua).font(.subheadline)
                            .shadow(color: Theme.aqua.opacity(0.6), radius: 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(p.online ? "\(p.hops) hop(s) · \(p.via) \(p.signal)" : "offline · messages will queue")
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
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
            Text(text).font(.subheadline).foregroundStyle(Color.white).frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.aqua)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 20, tint: tint.opacity(0.25))
    }
}

struct TransportChip: View {
    let info: TransportInfo
    var body: some View {
        HStack(spacing: 6) {
            StatusDot(on: info.state.active && info.state.links > 0, size: 6)
            Text(info.label).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
            Text(info.state.active ? "\(info.state.links)" : "off")
                .font(.caption).foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .glassCard(cornerRadius: 100)
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var engine: MeshEngine
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
        .tint(Theme.aqua)
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
            VStack(spacing: 26) {
                Spacer()
                RadarView().scaleEffect(appeared ? 1 : 0.6).opacity(appeared ? 1 : 0)
                VStack(spacing: 10) {
                    Text("OffGrid Chat")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.title)
                        .shadow(color: Theme.aqua.opacity(0.3), radius: 12)
                    Text("Chat without internet. Works securely over Bluetooth and nearby Wi-Fi.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center).foregroundStyle(Color.white.opacity(0.8))
                }
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose a nickname").font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                    TextField("", text: $nick, prompt: Text("Nickname").foregroundColor(Color.white.opacity(0.4)))
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .glassCard(cornerRadius: 18)
                    Text("No account needed. Others see this name; your cryptographic ID uniquely identifies you.")
                        .font(.subheadline).foregroundStyle(Color.white.opacity(0.65))
                    Button {
                        Haptics.success()
                        engine.setNickname(nick)
                    } label: {
                        Text("Start").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Theme.aqua.opacity(0.7)))
                    .disabled(isEmpty).opacity(isEmpty ? 0.5 : 1)
                    .animation(.easeInOut(duration: 0.25), value: isEmpty)
                }
                .padding(22).glassCard(cornerRadius: 32)
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
                VStack(spacing: 16) {
                    GlassGroup(spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(engine.transportInfos) { TransportChip(info: $0) }
                            }.padding(.horizontal, 4).padding(.vertical, 6)
                        }
                    }

                    ForEach(engine.transportInfos.filter { $0.state.error != nil }) { t in
                        BannerCard(icon: "exclamationmark.triangle.fill", text: "\(t.label): \(t.state.error ?? "")")
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    NavigationLink(destination: ChatView(convId: ROOM_ID, title: "Group room")) {
                        RowCard(icon: "person.3.fill", title: "Group room",
                                subtitle: "Everyone in the mesh (signed, not encrypted)")
                    }.buttonStyle(PressableStyle())

                    NavigationLink(destination: ChatView(convId: EMERGENCY_ID, title: "Emergency")) {
                        RowCard(icon: "exclamationmark.octagon.fill", title: "Emergency broadcast",
                                subtitle: "Alerts every device that can be reached", tint: Theme.danger)
                    }.buttonStyle(PressableStyle())

                    SectionTitle("People")

                    if engine.peers.isEmpty {
                        VStack(spacing: 12) {
                            RadarView()
                            Text("Searching nearby…").font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                            Text("Nobody found yet. Keep the app open on both phones, within a few metres, Bluetooth enabled.")
                                .font(.subheadline).multilineTextAlignment(.center)
                                .foregroundStyle(Color.white.opacity(0.75)).padding(.horizontal, 16)
                        }
                        .padding(.vertical, 28).frame(maxWidth: .infinity)
                        .glassCard(cornerRadius: 30)
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
                .padding(.horizontal, 16).padding(.bottom, 28)
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: peerKey)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("OffGrid Chat")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink { IdentityView() } label: { Image(systemName: "qrcode") }
                    .accessibilityLabel("Identity")
                NavigationLink { RadiosView() } label: { Image(systemName: "antenna.radiowaves.left.and.right") }
                    .accessibilityLabel("Radios")
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

    private func status(_ s: MsgStatus) -> String {
        switch s {
        case .queued: return "⏳ queued"
        case .sent: return "✓ sent"
        case .delivered: return "✓✓ delivered"
        case .failed: return "✗ failed · tap to retry"
        case .received: return ""
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    if let p = peer, !p.verified {
                        BannerCard(icon: "shield.lefthalf.filled",
                                   text: "Not verified. Compare \(String(p.fingerprint.prefix(19)))… with your friend's Identity screen, or scan their QR.",
                                   actionTitle: "Mark verified") {
                            Haptics.success()
                            engine.setVerified(p.id)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if isSOS {
                        BannerCard(icon: "exclamationmark.octagon.fill",
                                   text: "Emergency messages go to everyone reachable; signed but not encrypted.")
                    }
                }
                .padding(.horizontal, 14).padding(.top, 10)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: peer?.verified)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(msgs) { m in bubble(m) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
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
        VStack(alignment: m.outgoing ? .trailing : .leading, spacing: 4) {
            if isGroup && !m.outgoing {
                Text(who).font(.subheadline.weight(.bold)).foregroundStyle(Theme.aqua)
            }
            if m.outgoing {
                Text(m.text).foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.outgoing, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.blue.opacity(0.4), radius: 12, y: 6)
            } else {
                Text(m.text).foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .glassCard(cornerRadius: 22)
            }
            if m.outgoing {
                Text(status(m.status)).font(.caption)
                    .foregroundStyle(m.status == .failed ? Theme.danger : Color.white.opacity(0.65))
                    .contentTransition(.opacity)
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
                TextField("", text: $text, prompt: Text("Message").foregroundColor(Color.white.opacity(0.4)))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .glassCard(cornerRadius: 100)

                Button(action: sendNow) {
                    if isSOS {
                        Text("SOS").font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.white).padding(.horizontal, 18).frame(height: 50)
                    } else {
                        Image(systemName: "paperplane.fill").font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color.white).frame(width: 50, height: 50)
                    }
                }
                .glassCard(cornerRadius: 100, tint: isSOS ? Theme.danger : Theme.aqua.opacity(0.6), interactive: true)
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
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Your fingerprint")
                        Text(Crypto.fingerprint(engine.me))
                            .font(.system(.subheadline, design: .monospaced)).foregroundStyle(Color.white)
                        Button {
                            UIPasteboard.general.string = Crypto.fingerprint(engine.me)
                            Haptics.success()
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { copied = false } }
                        } label: {
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Theme.aqua)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 26)

                    VStack(spacing: 16) {
                        Image(uiImage: qrPic).interpolation(.none).resizable().scaledToFit()
                            .frame(width: 230, height: 230).padding(16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: Theme.aqua.opacity(0.4), radius: 28)
                        Text("Let a friend scan this in person. That proves the name and keys belong together.")
                            .font(.subheadline).multilineTextAlignment(.center)
                            .foregroundStyle(Color.white.opacity(0.8))
                        Button { scanning = true } label: {
                            Label("Scan a friend's QR", systemImage: "qrcode.viewfinder")
                        }
                        .buttonStyle(GlassButtonStyle(tint: Theme.aqua.opacity(0.6)))
                        if let r = result {
                            Text(r).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.mint)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(20).frame(maxWidth: .infinity)
                    .glassCard(cornerRadius: 32)

                    SectionTitle("Known people")
                    ForEach(engine.peers) { p in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(p.nick).font(.system(.headline, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
                                Spacer()
                                Text(p.verified ? "✓ verified" : "unverified").font(.subheadline.weight(.semibold))
                                    .foregroundStyle(p.verified ? Theme.mint : Theme.danger)
                            }
                            Text(p.fingerprint).font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.75))
                            if !p.verified {
                                Button("Fingerprints match: mark verified") {
                                    Haptics.success()
                                    engine.setVerified(p.id)
                                }
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.aqua)
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: result)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: engine.peers.count)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("My identity")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { qrPic = qrImage(engine.myQr()) }
        .sheet(isPresented: $scanning) {
            ZStack(alignment: .topTrailing) {
                QRScannerView { code in
                    scanning = false
                    if let n = engine.verifyFromQr(code) {
                        result = "Verified \(n)"; Haptics.success()
                    } else {
                        result = "Not a valid OffGrid QR code"; Haptics.warning()
                    }
                }
                .ignoresSafeArea()
                Button("Cancel") { scanning = false }
                    .buttonStyle(GlassButtonStyle()).padding()
            }
        }
    }
}

// MARK: - Radios

struct RadiosView: View {
    @EnvironmentObject var engine: MeshEngine
    @State private var host = UserDefaults.standard.string(forKey: "lanHost") ?? ""
    @State private var confirmStop = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(engine.transportInfos) { t in
                        HStack(alignment: .top, spacing: 14) {
                            StatusDot(on: t.state.active && t.state.links > 0)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(t.label): \(t.state.active ? "on" : "off") · \(t.state.links) link(s)")
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

                    SectionTitle("Android hotspot host (optional)")
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("",
                                text: $host,
                                prompt: Text("Host IP (blank = auto, e.g. 192.168.43.1)").foregroundColor(Color.white.opacity(0.4)))
                            .font(.system(.body, design: .rounded))
                            .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .glassCard(cornerRadius: 18)
                            .onChange(of: host) { engine.lan.manualHost = $0 }
                        Text("Join the Android phone's hotspot Wi-Fi in iOS Settings, then open this app. Allow Local Network access when prompted.")
                            .font(.subheadline).foregroundStyle(Color.white.opacity(0.75))
                    }
                    .padding(16).glassCard(cornerRadius: 26)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("iOS suspends apps in the background. Bluetooth keeps working in a limited way, but backgrounded iPhones may not be discoverable by Android phones. Keep the app open for reliable chat.")
                            .font(.subheadline).foregroundStyle(Color.white.opacity(0.75))
                        HStack(spacing: 12) {
                            Button { Haptics.tap(); engine.start() } label: {
                                Label("Restart", systemImage: "arrow.clockwise")
                            }.buttonStyle(GlassButtonStyle(tint: Theme.aqua.opacity(0.6)))
                            Button(role: .destructive) { confirmStop = true } label: {
                                Label("Stop OffGrid Chat", systemImage: "power")
                            }.buttonStyle(GlassButtonStyle(tint: Theme.danger.opacity(0.7)))
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 26)
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Radios")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Stop OffGrid Chat?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Stop", role: .destructive) { engine.stop() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will stop receiving messages until you tap Restart or reopen the app.")
        }
    }
}
