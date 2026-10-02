import SwiftUI

struct RootView: View {
    @EnvironmentObject var engine: MeshEngine
    var body: some View {
        if engine.nickname.isEmpty { NicknameView() } else { NavigationStack { PeersView() } }
    }
}

struct NicknameView: View {
    @EnvironmentObject var engine: MeshEngine
    @State private var nick = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a nickname").font(.title2).bold()
            Text("No account. Others see this name; your cryptographic ID is what really identifies you.")
            TextField("Nickname", text: $nick).textFieldStyle(.roundedBorder)
            Button("Start") { engine.setNickname(nick) }
                .buttonStyle(.borderedProminent).disabled(nick.trimmingCharacters(in: .whitespaces).isEmpty)
        }.padding(24)
    }
}

struct PeersView: View {
    @EnvironmentObject var engine: MeshEngine
    private var summary: String {
        "Active: " + engine.transportInfos.map { "\($0.label) \($0.state.active ? "\($0.state.links) link(s)" : "off")" }.joined(separator: " · ")
    }
    var body: some View {
        List {
            ForEach(engine.transportInfos.filter { $0.state.error != nil }) { t in
                Label("\(t.label): \(t.state.error ?? "")", systemImage: "exclamationmark.triangle").foregroundColor(.red)
            }
            Text(summary).font(.footnote)
            Section {
                NavigationLink(destination: ChatView(convId: ROOM_ID, title: "Group room")) {
                    VStack(alignment: .leading) {
                        Text("Group room").bold()
                        Text("Everyone in the mesh (signed, not encrypted)").font(.caption)
                    }
                }
                NavigationLink(destination: ChatView(convId: EMERGENCY_ID, title: "Emergency")) {
                    VStack(alignment: .leading) {
                        Text("🚨 Emergency broadcast").bold().foregroundColor(.red)
                        Text("Alerts every device that can be reached").font(.caption)
                    }
                }
            }
            Section("People") {
                if engine.peers.isEmpty {
                    Text("Nobody found yet. Keep the app open on both phones, within a few metres, Bluetooth on.")
                }
                ForEach(engine.peers) { p in
                    NavigationLink(destination: ChatView(convId: p.id, title: p.nick)) {
                        VStack(alignment: .leading) {
                            Text((p.online ? "● " : "○ ") + p.nick + (p.verified ? "  ✓ verified" : "")).bold()
                            Text(p.online ? "\(p.hops) hop(s) · \(p.via) \(p.signal)" : "offline · messages will queue").font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("OffGrid Chat")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink("Identity") { IdentityView() }
                NavigationLink("Radios") { RadiosView() }
            }
        }
    }
}

struct ChatView: View {
    @EnvironmentObject var engine: MeshEngine
    let convId: String
    let title: String
    @State private var text = ""

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
        VStack(spacing: 0) {
            if let p = peer, !p.verified {
                HStack {
                    Text("Not verified. Compare \(String(p.fingerprint.prefix(19)))… with your friend's Identity screen, or scan their QR.")
                        .font(.caption)
                    Button("Mark verified") { engine.setVerified(p.id) }.font(.caption)
                }.padding(8).background(Color.red.opacity(0.15))
            }
            if convId == EMERGENCY_ID {
                Text("Emergency messages go to everyone reachable; signed but not encrypted.")
                    .font(.caption).padding(8).background(Color.red.opacity(0.15))
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(msgs) { m in
                            let who = engine.peers.first { $0.id == m.senderId }?.nick ?? String(m.senderId.prefix(6))
                            VStack(alignment: m.outgoing ? .trailing : .leading, spacing: 2) {
                                if isGroup && !m.outgoing { Text(who).font(.caption2).bold() }
                                Text(m.text).padding(10)
                                    .background(m.outgoing ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                                if m.outgoing { Text(status(m.status)).font(.caption2) }
                            }
                            .frame(maxWidth: .infinity, alignment: m.outgoing ? .trailing : .leading)
                            .id(m.id)
                            .onTapGesture { if m.status == .failed { engine.retry(m.id) } }
                        }
                    }.padding(8)
                }
                .onChange(of: msgs.count) { _ in if let l = msgs.last { proxy.scrollTo(l.id, anchor: .bottom) } }
            }
            HStack {
                TextField("Message", text: $text).textFieldStyle(.roundedBorder)
                Button(convId == EMERGENCY_ID ? "SOS" : "Send") { engine.send(to: convId, text); text = "" }
                    .buttonStyle(.borderedProminent).tint(convId == EMERGENCY_ID ? .red : .accentColor)
            }.padding(8)
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct IdentityView: View {
    @EnvironmentObject var engine: MeshEngine
    @State private var scanning = false
    @State private var result: String?

    var body: some View {
        List {
            Section("Your fingerprint") { Text(Crypto.fingerprint(engine.me)).font(.system(.body, design: .monospaced)) }
            Section {
                Image(uiImage: qrImage(engine.myQr())).interpolation(.none).resizable()
                    .frame(width: 240, height: 240).frame(maxWidth: .infinity)
                Text("Let a friend scan this in person. That proves the name and keys belong together.").font(.footnote)
                Button("Scan a friend's QR") { scanning = true }
                if let r = result { Text(r).font(.footnote) }
            }
            Section("Known people") {
                ForEach(engine.peers) { p in
                    VStack(alignment: .leading) {
                        Text(p.nick + (p.verified ? "  ✓ verified" : "  (unverified)")).bold()
                        Text(p.fingerprint).font(.system(.caption, design: .monospaced))
                        if !p.verified { Button("Fingerprints match: mark verified") { engine.setVerified(p.id) } }
                    }
                }
            }
        }
        .navigationTitle("My identity")
        .sheet(isPresented: $scanning) {
            QRScannerView { code in
                scanning = false
                if let n = engine.verifyFromQr(code) { result = "Verified \(n)" } else { result = "Not a valid OffGrid QR code" }
            }
        }
    }
}

struct RadiosView: View {
    @EnvironmentObject var engine: MeshEngine
    @State private var host = UserDefaults.standard.string(forKey: "lanHost") ?? ""

    var body: some View {
        List {
            ForEach(engine.transportInfos) { t in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(t.label): \(t.state.active ? "on" : "off") · \(t.state.links) link(s)").bold()
                    Text(t.state.detail).font(.caption)
                    if let e = t.state.error { Text(e).font(.caption).foregroundColor(.red) }
                }
            }
            Section("Android hotspot host (optional)") {
                TextField("Host IP (blank = auto, e.g. 192.168.43.1)", text: $host)
                    .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                    .onChange(of: host) { engine.lan.manualHost = $0 }
                Text("Join the Android phone's hotspot Wi-Fi in iOS Settings, then open this app. Allow Local Network access when asked.")
                    .font(.footnote)
            }
            Section {
                Text("iOS suspends apps in the background. Bluetooth keeps working in a limited way, but an iPhone that is backgrounded may not be discoverable by Android phones. Keep the app open for reliable chat.")
                    .font(.footnote)
                Button("Stop OffGrid Chat", role: .destructive) { engine.stop() }
            }
        }
        .navigationTitle("Radios")
    }
}
