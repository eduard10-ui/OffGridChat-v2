import SwiftUI
import UIKit

// =====================================================================================
//  OffGrid Chat: modern UI (animated gradient + Liquid Glass)
//  Only presentation lives here. All behaviour still goes through `engine` exactly as before.
//  Liquid Glass (iOS 26+) is used when the app is built with Xcode 26+; otherwise (or on older
//  iPhones) a frosted-material look is used automatically. Nothing else needs to change.
// =====================================================================================

// MARK: - Theme

enum Theme {
    static let deep   = Color(red: 0.05, green: 0.04, blue: 0.18)
    static let violet = Color(red: 0.27, green: 0.12, blue: 0.50)
    static let ocean  = Color(red: 0.04, green: 0.32, blue: 0.55)
    static let pink   = Color(red: 0.62, green: 0.20, blue: 0.62)
    static let aqua   = Color(red: 0.42, green: 0.86, blue: 1.00)
    static let lilac  = Color(red: 0.74, green: 0.58, blue: 1.00)
    static let mint   = Color(red: 0.40, green: 0.95, blue: 0.70)
    static let danger = Color(red: 1.00, green: 0.36, blue: 0.42)

    static let outgoing = LinearGradient(
        colors: [Color(red: 0.20, green: 0.55, blue: 1.0), Color(red: 0.52, green: 0.34, blue: 0.98)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let title = LinearGradient(colors: [aqua, lilac], startPoint: .leading, endPoint: .trailing)
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - Liquid Glass (with automatic fallback)

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
    /// Liquid Glass on iOS 26+ (built with Xcode 26+), frosted material everywhere else.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 22, tint: Color? = nil, interactive: Bool = false) -> some View {
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
            .background(shape.fill((tint ?? Color.white).opacity(tint == nil ? 0.04 : 0.22)))
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }
}

/// Lets nearby glass shapes blend/morph together on iOS 26+; plain pass-through otherwise.
struct GlassGroup<Content: View>: View {
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
            .padding(.horizontal, 20).padding(.vertical, 13)
            .glassCard(cornerRadius: 100, tint: tint, interactive: true)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Animated background

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
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0.0 : ctx.date.timeIntervalSinceReferenceDate
            let dx = Float(0.10 * sin(t * 0.30))
            let dy = Float(0.10 * cos(t * 0.25))
            let points: [SIMD2<Float>] = [
                SIMD2<Float>(0, 0), SIMD2<Float>(0.5 + dx, 0), SIMD2<Float>(1, 0),
                SIMD2<Float>(0, 0.5 - dy), SIMD2<Float>(0.5 + dy, 0.5 + dx), SIMD2<Float>(1, 0.5 + dy),
                SIMD2<Float>(0, 1), SIMD2<Float>(0.5 - dx, 1), SIMD2<Float>(1, 1)
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
        LinearGradient(colors: [Theme.deep, Theme.violet, Theme.ocean],
                       startPoint: shift ? .topLeading : .bottomLeading,
                       endPoint: shift ? .bottomTrailing : .topTrailing)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { shift = true }
            }
    }
}

// MARK: - Small components

struct StatusDot: View {
    let on: Bool
    var size: CGFloat = 10
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            if on {
                Circle().fill(Theme.mint.opacity(0.5)).frame(width: size, height: size)
                    .scaleEffect(pulse ? 2.4 : 1).opacity(pulse ? 0 : 0.9)
            }
            Circle().fill(on ? Theme.mint : Color.white.opacity(0.3)).frame(width: size, height: size)
        }
        .frame(width: size * 2.4, height: size * 2.4)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
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
                Circle().stroke(Theme.aqua.opacity(0.55), lineWidth: 1.5)
                    .scaleEffect(go ? 1.0 : 0.2).opacity(go ? 0 : 0.9)
                    .animation(reduceMotion ? nil :
                        .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.8), value: go)
            }
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.title)
        }
        .frame(width: 140, height: 140)
        .onAppear { go = true }
    }
}

struct Avatar: View {
    let name: String
    let online: Bool
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Theme.aqua.opacity(0.9), Theme.lilac.opacity(0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(Color.white)
        }
        .frame(width: 46, height: 46)
        .overlay(alignment: .bottomTrailing) {
            Circle().fill(online ? Theme.mint : Color.gray).frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 2))
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold)).tracking(1.2)
            .foregroundStyle(Color.white.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6).padding(.leading, 4)
    }
}

struct RowCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = Theme.aqua
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(Color.white)
                .frame(width: 46, height: 46).background(Circle().fill(tint.opacity(0.35)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                Text(subtitle).font(.caption).foregroundStyle(Color.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24, tint: tint.opacity(0.12))
    }
}

struct PeerRow: View {
    let p: PeerView
    var body: some View {
        HStack(spacing: 14) {
            Avatar(name: p.nick, online: p.online)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(p.nick).font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                    if p.verified {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.aqua).font(.subheadline)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(p.online ? "\(p.hops) hop(s) · \(p.via) \(p.signal)" : "offline · messages will queue")
                    .font(.caption).foregroundStyle(Color.white.opacity(0.7))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
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
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(.caption).foregroundStyle(Color.white).frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.aqua)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 18, tint: tint.opacity(0.25))
    }
}

struct TransportChip: View {
    let info: TransportInfo
    var body: some View {
        HStack(spacing: 4) {
            StatusDot(on: info.state.active && info.state.links > 0, size: 7)
            Text(info.label).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(Color.white)
            Text(info.state.active ? "\(info.state.links)" : "off")
                .font(.caption2).foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .glassCard(cornerRadius: 100)
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var engine: MeshEngine
    var body: some View {
        Group {
            if engine.nickname.isEmpty {
                NicknameView().transition(.opacity.combined(with: .scale(scale: 1.04)))
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
            VStack(spacing: 22) {
                Spacer()
                RadarView().scaleEffect(appeared ? 1 : 0.6).opacity(appeared ? 1 : 0)
                VStack(spacing: 8) {
                    Text("OffGrid Chat")
                        .font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(Theme.title)
                    Text("Chat without internet. Works over Bluetooth and nearby Wi-Fi.")
                        .multilineTextAlignment(.center).foregroundStyle(Color.white.opacity(0.75))
                }
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a nickname").font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                    TextField("", text: $nick, prompt: Text("Nickname").foregroundStyle(Color.white.opacity(0.5)))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .glassCard(cornerRadius: 16)
                    Text("No account. Others see this name; your cryptographic ID is what really identifies you.")
                        .font(.caption).foregroundStyle(Color.white.opacity(0.65))
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
                .padding(20).glassCard(cornerRadius: 28)
                .offset(y: appeared ? 0 : 40).opacity(appeared ? 1 : 0)
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) { appeared = true } }
    }
}

// MARK: - People

struct PeersView: View {
    @EnvironmentObject var engine: MeshEngine

    private var peerKey: [String] { engine.peers.map { $0.id + ($0.online ? "1" : "0") } }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    GlassGroup(spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(engine.transportInfos) { TransportChip(info: $0) }
                            }.padding(.horizontal, 2).padding(.vertical, 4)
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
                        VStack(spacing: 8) {
                            RadarView()
                            Text("Searching nearby…").font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                            Text("Nobody found yet. Keep the app open on both phones, within a few metres, Bluetooth on.")
                                .font(.caption).multilineTextAlignment(.center)
                                .foregroundStyle(Color.white.opacity(0.7)).padding(.horizontal, 12)
                        }
                        .padding(.vertical, 20).frame(maxWidth: .infinity)
                        .glassCard(cornerRadius: 28)
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
                .padding(.horizontal, 16).padding(.bottom, 24)
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
                VStack(spacing: 8) {
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
                .padding(.horizontal, 12).padding(.top, 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: peer?.verified)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(msgs) { m in bubble(m) }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
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
        VStack(alignment: m.outgoing ? .trailing : .leading, spacing: 3) {
            if isGroup && !m.outgoing {
                Text(who).font(.caption2.weight(.bold)).foregroundStyle(Theme.aqua)
            }
            if m.outgoing {
                Text(m.text).foregroundStyle(Color.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.outgoing, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.blue.opacity(0.35), radius: 10, y: 5)
            } else {
                Text(m.text).foregroundStyle(Color.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .glassCard(cornerRadius: 20)
            }
            if m.outgoing {
                Text(status(m.status)).font(.caption2)
                    .foregroundStyle(m.status == .failed ? Theme.danger : Color.white.opacity(0.6))
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: m.status)
            }
        }
        .padding(.leading, m.outgoing ? 56 : 0).padding(.trailing, m.outgoing ? 0 : 56)
        .frame(maxWidth: .infinity, alignment: m.outgoing ? .trailing : .leading)
        .id(m.id)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8, anchor: m.outgoing ? .bottomTrailing : .bottomLeading).combined(with: .opacity),
            removal: .opacity))
        .onTapGesture { if m.status == .failed { Haptics.warning(); engine.retry(m.id) } }
    }

    private var inputBar: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                TextField("", text: $text, prompt: Text("Message").foregroundStyle(Color.white.opacity(0.5)))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .glassCard(cornerRadius: 100)

                Button(action: sendNow) {
                    if isSOS {
                        Text("SOS").font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.white).padding(.horizontal, 16).frame(height: 46)
                    } else {
                        Image(systemName: "paperplane.fill").font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.white).frame(width: 46, height: 46)
                    }
                }
                .glassCard(cornerRadius: 100, tint: isSOS ? Theme.danger : Theme.aqua.opacity(0.6), interactive: true)
                .scaleEffect(bounce ? 1.25 : 1)
                .shadow(color: isSOS ? Theme.danger.opacity(glow ? 0.7 : 0.15) : Color.clear, radius: glow ? 16 : 4)
                .disabled(isEmpty).opacity(isEmpty ? 0.55 : 1)
                .animation(.easeInOut(duration: 0.2), value: isEmpty)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
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
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("Your fingerprint")
                        Text(Crypto.fingerprint(engine.me))
                            .font(.system(.body, design: .monospaced)).foregroundStyle(Color.white)
                        Button {
                            UIPasteboard.general.string = Crypto.fingerprint(engine.me)
                            Haptics.success()
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { copied = false } }
                        } label: {
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.aqua)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 24)

                    VStack(spacing: 14) {
                        Image(uiImage: qrPic).interpolation(.none).resizable().scaledToFit()
                            .frame(width: 220, height: 220).padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: Theme.aqua.opacity(0.35), radius: 24)
                        Text("Let a friend scan this in person. That proves the name and keys belong together.")
                            .font(.footnote).multilineTextAlignment(.center)
                            .foregroundStyle(Color.white.opacity(0.75))
                        Button { scanning = true } label: {
                            Label("Scan a friend's QR", systemImage: "qrcode.viewfinder")
                        }
                        .buttonStyle(GlassButtonStyle(tint: Theme.aqua.opacity(0.6)))
                        if let r = result {
                            Text(r).font(.footnote.weight(.semibold)).foregroundStyle(Theme.mint)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(18).frame(maxWidth: .infinity)
                    .glassCard(cornerRadius: 28)

                    SectionTitle("Known people")
                    ForEach(engine.peers) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(p.nick).font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                                Spacer()
                                Text(p.verified ? "✓ verified" : "unverified").font(.caption.weight(.semibold))
                                    .foregroundStyle(p.verified ? Theme.mint : Theme.danger)
                            }
                            Text(p.fingerprint).font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.7))
                            if !p.verified {
                                Button("Fingerprints match: mark verified") {
                                    Haptics.success()
                                    engine.setVerified(p.id)
                                }
                                .font(.caption.weight(.semibold)).foregroundStyle(Theme.aqua)
                            }
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 22)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
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
                VStack(spacing: 14) {
                    ForEach(engine.transportInfos) { t in
                        HStack(alignment: .top, spacing: 12) {
                            StatusDot(on: t.state.active && t.state.links > 0)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(t.label): \(t.state.active ? "on" : "off") · \(t.state.links) link(s)")
                                    .font(.system(.headline, design: .rounded)).foregroundStyle(Color.white)
                                Text(t.state.detail).font(.caption).foregroundStyle(Color.white.opacity(0.7))
                                if let e = t.state.error {
                                    Text(e).font(.caption).foregroundStyle(Theme.danger)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 22)
                    }

                    SectionTitle("Android hotspot host (optional)")
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("", text: $host,
                                  prompt: Text("Host IP (blank = auto, e.g. 192.168.43.1)").foregroundStyle(Color.white.opacity(0.5)))
                            .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .glassCard(cornerRadius: 16)
                            .onChange(of: host) { engine.lan.manualHost = $0 }
                        Text("Join the Android phone's hotspot Wi-Fi in iOS Settings, then open this app. Allow Local Network access when asked.")
                            .font(.footnote).foregroundStyle(Color.white.opacity(0.7))
                    }
                    .padding(14).glassCard(cornerRadius: 24)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("iOS suspends apps in the background. Bluetooth keeps working in a limited way, but an iPhone that is backgrounded may not be discoverable by Android phones. Keep the app open for reliable chat.")
                            .font(.footnote).foregroundStyle(Color.white.opacity(0.7))
                        HStack(spacing: 10) {
                            Button { Haptics.tap(); engine.start() } label: {
                                Label("Restart", systemImage: "arrow.clockwise")
                            }.buttonStyle(GlassButtonStyle(tint: Theme.aqua.opacity(0.6)))
                            Button(role: .destructive) { confirmStop = true } label: {
                                Label("Stop OffGrid Chat", systemImage: "power")
                            }.buttonStyle(GlassButtonStyle(tint: Theme.danger.opacity(0.7)))
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 24)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
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
