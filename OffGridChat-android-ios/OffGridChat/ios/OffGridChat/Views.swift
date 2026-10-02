import SwiftUI

// MARK: - Aesthetic Glassmorphism & Background Helpers
struct LiquidBackground: View {
    @State private var animate = false
    var body: some View {
        LinearGradient(
            colors: [.indigo, .purple.opacity(0.8), .cyan.opacity(0.6)],
            startPoint: animate ? .topLeading : .bottomTrailing,
            endPoint: animate ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

struct GlassmorphismModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassmorphismModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var engine: MeshEngine
    var body: some View {
        ZStack {
            LiquidBackground()
            
            if engine.nickname.isEmpty {
                NicknameView()
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .scale.combined(with: .opacity)))
            } else {
                NavigationStack {
                    PeersView()
                        .toolbarBackground(.hidden, for: .navigationBar)
                }
                .tint(.white)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: engine.nickname.isEmpty)
    }
}

// MARK: - Nickname View
struct NicknameView: View {
    @EnvironmentObject var engine: MeshEngine
    @State private var nick = ""
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("OffGrid Chat")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                
                Text("Choose a nickname")
                    .font(.title3.bold())
                    .foregroundColor(.white.opacity(0.9))
                
                Text("No account. Others see this name; your cryptographic ID is what really identifies you.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 10)
            
            TextField("Enter nickname", text: $nick)
                .font(.headline)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
                .shadow(color: .black.opacity(0.1), radius: 5)
                .padding(.horizontal, 10)
            
            Button(action: {
                withAnimation { engine.setNickname(nick) }
            }) {
                Text("Start")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .cyan.opacity(0.5), radius: 10, y: 5)
            }
            .disabled(nick.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(nick.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .padding(.horizontal, 10)
        }
        .padding(30)
        .glassCard(cornerRadius: 30)
        .padding(24)
        .scaleEffect(isAnimating ? 1 : 0.9)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Peers View
struct PeersView: View {
    @EnvironmentObject var engine: MeshEngine
    
    private var summary: String {
        "Active: " + engine.transportInfos.map { "\($0.label) \($0.state.active ? "\($0.state.links) link(s)" : "off")" }.joined(separator: " · ")
    }
    
    var body: some View {
        ZStack {
            LiquidBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Status Banners
                    ForEach(engine.transportInfos.filter { $0.state.error != nil }) { t in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("\(t.label): \(t.state.error ?? "")")
                        }
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                    }
                    
                    Text(summary)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal)
                    
                    // Group & Emergency Rooms
                    VStack(spacing: 12) {
                        NavigationLink(destination: ChatView(convId: ROOM_ID, title: "Group room")) {
                            RoomCard(icon: "person.3.fill", title: "Group room", desc: "Everyone in the mesh (signed, not encrypted)", color: .blue)
                        }
                        
                        NavigationLink(destination: ChatView(convId: EMERGENCY_ID, title: "Emergency")) {
                            RoomCard(icon: "exclamationmark.shield.fill", title: "🚨 Emergency broadcast", desc: "Alerts every device that can be reached", color: .red)
                        }
                    }
                    
                    // People Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("People")
                            .font(.title2.bold().rounded())
                            .foregroundColor(.white)
                            .padding(.leading, 8)
                        
                        if engine.peers.isEmpty {
                            Text("Nobody found yet. Keep the app open on both phones, within a few metres, Bluetooth on.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding()
                                .frame(maxWidth: .infinity)
                                .glassCard()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(engine.peers) { p in
                                    NavigationLink(destination: ChatView(convId: p.id, title: p.nick)) {
                                        PeerCard(peer: p)
                                    }
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.peers.count)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("OffGrid Chat")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink(destination: IdentityView()) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.title3)
                }
                NavigationLink(destination: RadiosView()) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3)
                }
            }
        }
    }
}

// MARK: - Subcomponents for PeersView
struct RoomCard: View {
    let icon: String
    let title: String
    let desc: String
    let color: Color
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 50, height: 50)
                Image(systemName: icon).foregroundColor(color).font(.title2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundColor(.white)
                Text(desc).font(.caption).foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .glassCard()
    }
}

struct PeerCard: View {
    let peer: PeerView
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(peer.online ? Color.green.opacity(0.2) : Color.gray.opacity(0.2)).frame(width: 50, height: 50)
                Text(String(peer.nick.prefix(1).uppercased()))
                    .font(.title2.bold())
                    .foregroundColor(peer.online ? .green : .gray)
                
                if peer.online {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        .offset(x: 18, y: 18)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(peer.nick).font(.headline).foregroundColor(.white)
                    if peer.verified {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.blue).font(.caption)
                    }
                }
                Text(peer.online ? "\(peer.hops) hop(s) · \(peer.via) \(peer.signal)" : "offline · messages will queue")
                    .font(.caption)
                    .foregroundColor(peer.online ? .white.opacity(0.9) : .white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Chat View
struct ChatView: View {
    @EnvironmentObject var engine: MeshEngine
    let convId: String
    let title: String
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var msgs: [ChatMessage] { engine.messages.filter { $0.convId == convId }.sorted { $0.ts < $1.ts } }
    private var isGroup: Bool { convId == ROOM_ID || convId == EMERGENCY_ID }
    private var peer: PeerView? { engine.peers.first { $0.id == convId } }

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
            LiquidBackground()
            
            VStack(spacing: 0) {
                // Info Banners
                if let p = peer, !p.verified {
                    HStack {
                        Image(systemName: "exclamationmark.shield")
                        Text("Verify: \(String(p.fingerprint.prefix(19)))…")
                            .font(.caption)
                        Spacer()
                        Button("Verify") { withAnimation { engine.setVerified(p.id) } }
                            .font(.caption.bold())
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .foregroundColor(.white)
                }
                if convId == EMERGENCY_ID {
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                        Text("Broadcast goes to everyone; signed but not encrypted.")
                            .font(.caption.bold())
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.6))
                    .foregroundColor(.white)
                }

                // Chat ScrollView
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(msgs) { m in
                                let who = engine.peers.first { $0.id == m.senderId }?.nick ?? String(m.senderId.prefix(6))
                                ChatBubble(message: m, senderName: who, isGroup: isGroup, statusText: status(m.status))
                                    .id(m.id)
                                    .onTapGesture {
                                        if m.status == .failed { withAnimation { engine.retry(m.id) } }
                                    }
                                    .transition(.scale(scale: 0.8, anchor: m.outgoing ? .bottomTrailing : .bottomLeading).combined(with: .opacity))
                            }
                        }
                        .padding()
                    }
                    .onChange(of: msgs.count) { _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let l = msgs.last { proxy.scrollTo(l.id, anchor: .bottom) }
                        }
                    }
                }
                
                // Input Bar
                HStack(spacing: 12) {
                    TextField("Message...", text: $text)
                        .focused($isFocused)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                    
                    Button(action: {
                        withAnimation {
                            engine.send(to: convId, text)
                            text = ""
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(text.isEmpty ? .white.opacity(0.4) : (convId == EMERGENCY_ID ? .red : .cyan))
                            .shadow(color: text.isEmpty ? .clear : (convId == EMERGENCY_ID ? .red : .cyan).opacity(0.5), radius: 5)
                    }
                    .disabled(text.isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let senderName: String
    let isGroup: Bool
    let statusText: String
    
    var body: some View {
        VStack(alignment: message.outgoing ? .trailing : .leading, spacing: 4) {
            if isGroup && !message.outgoing {
                Text(senderName)
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 4)
            }
            
            Text(message.text)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if message.outgoing {
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        } else {
                            Color.white.opacity(0.15)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
            
            if message.outgoing {
                Text(statusText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(message.status == .failed ? .red : .white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: message.outgoing ? .trailing : .leading)
    }
}

// MARK: - Identity View
struct IdentityView: View {
    @EnvironmentObject var engine: MeshEngine
    @State private var scanning = false
    @State private var result: String?

    var body: some View {
        ZStack {
            LiquidBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Fingerprint")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        Text(Crypto.fingerprint(engine.me))
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .padding()
                    .glassCard()
                    
                    VStack(spacing: 16) {
                        Image(uiImage: qrImage(engine.myQr()))
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                        
                        Text("Let a friend scan this in person. That proves the name and keys belong together.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        Button(action: { scanning = true }) {
                            HStack {
                                Image(systemName: "qrcode.viewfinder")
                                Text("Scan a friend's QR")
                            }
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                        }
                        
                        if let r = result {
                            Text(r).font(.footnote.bold()).foregroundColor(.white)
                        }
                    }
                    .padding()
                    .glassCard()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Known People")
                            .font(.title2.bold().rounded())
                            .foregroundColor(.white)
                        
                        ForEach(engine.peers) { p in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(p.nick).font(.headline).foregroundColor(.white)
                                    Spacer()
                                    if p.verified {
                                        Label("Verified", systemImage: "checkmark.seal.fill").foregroundColor(.blue).font(.caption.bold())
                                    } else {
                                        Text("Unverified").font(.caption).foregroundColor(.orange)
                                    }
                                }
                                Text(p.fingerprint)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if !p.verified {
                                    Button("Fingerprints match: mark verified") {
                                        withAnimation { engine.setVerified(p.id) }
                                    }
                                    .font(.caption.bold())
                                    .padding(.top, 4)
                                    .tint(.cyan)
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .glassCard()
                }
                .padding()
            }
        }
        .navigationTitle("My Identity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .sheet(isPresented: $scanning) {
            QRScannerView { code in
                scanning = false
                if let n = engine.verifyFromQr(code) { result = "Verified \(n)" } else { result = "Not a valid OffGrid QR code" }
            }
        }
    }
}

// MARK: - Radios View
struct RadiosView: View {
    @EnvironmentObject var engine: MeshEngine
    @State private var host = UserDefaults.standard.string(forKey: "lanHost") ?? ""

    var body: some View {
        ZStack {
            LiquidBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Transports Status
                    VStack(spacing: 12) {
                        ForEach(engine.transportInfos) { t in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t.label)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(t.state.detail)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    if let e = t.state.error {
                                        Text(e).font(.caption.bold()).foregroundColor(.red)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Circle()
                                        .fill(t.state.active ? Color.green : Color.red)
                                        .frame(width: 12, height: 12)
                                        .shadow(color: t.state.active ? .green : .red, radius: 5)
                                    Text("\(t.state.links) link(s)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .glassCard()
                    
                    // Host configuration
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Android Hotspot Host (Optional)")
                            .font(.headline).foregroundColor(.white)
                        
                        TextField("Host IP (e.g. 192.168.43.1)", text: $host)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .onChange(of: host) { engine.lan.manualHost = $0 }
                        
                        Text("Join the Android phone's hotspot Wi-Fi in iOS Settings, then open this app. Allow Local Network access when asked.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .glassCard()
                    
                    // App Controls
                    VStack(spacing: 16) {
                        Text("iOS suspends apps in the background. Bluetooth keeps working in a limited way, but an iPhone that is backgrounded may not be discoverable by Android phones. Keep the app open for reliable chat.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            withAnimation { engine.stop() }
                        }) {
                            Text("Stop OffGrid Chat")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .clipShape(Capsule())
                                .shadow(color: .red.opacity(0.5), radius: 10)
                        }
                    }
                    .padding()
                    .glassCard()
                }
                .padding()
            }
        }
        .navigationTitle("Radios")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
