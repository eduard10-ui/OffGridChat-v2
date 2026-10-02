import Foundation
import Combine
import UserNotifications

struct PeerView: Identifiable {
    let id: String
    let nick: String
    let verified: Bool
    let online: Bool
    let hops: Int
    let via: String
    let signal: String
    let fingerprint: String
}

struct TransportInfo: Identifiable {
    let id: String
    let label: String
    let state: TransportState
}

/// Same routing/crypto/queue logic as the Android MeshEngine. Everything runs on the main thread
/// (transports deliver events on main, the UI is on main), so no locking is needed.
final class MeshEngine: ObservableObject {
    @Published var nickname: String
    @Published private(set) var peers: [PeerView] = []
    @Published private(set) var messages: [ChatMessage] = []

    let identity = Identity.loadOrCreate()
    var me: String { identity.userId }

    let ble = BleTransport()
    let lan = LanTransport()
    let mpc = MultipeerTransport()
    var transports: [BaseTransport] { [mpc, lan, ble] }
    var transportInfos: [TransportInfo] {
        transports.map { TransportInfo(id: $0.name, label: $0.label, state: $0.state) }
    }

    private final class Link {
        let id: String
        let t: BaseTransport
        var peerId: String?
        var signal: String
        init(id: String, t: BaseTransport, signal: String) { self.id = id; self.t = t; self.signal = signal }
    }

    private var links: [String: Link] = [:]
    private var seen: [String: Date] = [:]
    private var live: [String: (hops: Int, ts: Date)] = [:]
    private var known: [String: Peer] = [:]
    private var timers: [Timer] = []
    private var bag = Set<AnyCancellable>()
    private var started = false
    private var saveWork: DispatchWorkItem?

    init() {
        nickname = UserDefaults.standard.string(forKey: "nick") ?? ""
        let snap = Persistence.load()
        known = Dictionary(snap.peers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        messages = snap.messages
        refreshPeers()
    }

    // MARK: lifecycle
    func start() {
        guard !started, !nickname.isEmpty else { return }
        started = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        for t in transports {
            t.onEvent = { [weak self, weak t] e in if let t { self?.onEvent(t, e) } }
            t.$state.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
            t.start(localId: me, nick: nickname)
        }
        timers = [
            Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.helloTick() },
            Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in self?.retryTick() },
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refreshPeers() }
        ]
    }

    func stop() {
        timers.forEach { $0.invalidate() }; timers = []
        bag.removeAll()
        transports.forEach { $0.stop() }
        links.removeAll(); started = false
        refreshPeers()
    }

    func setNickname(_ n: String) {
        let nick = String(n.trimmingCharacters(in: .whitespaces).prefix(32))
        UserDefaults.standard.set(nick, forKey: "nick")
        nickname = nick
        if !started { start() } else { flood(helloEnv(), except: nil) }
    }

    // MARK: helpers
    private func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    private func aad(_ from: String, _ to: String) -> Data { Data("\(from)|\(to)".utf8) }
    private func sigInput(_ e: Envelope) -> Data {
        Data("\(e.id)|\(e.senderId)|\(e.receiverId)|\(e.timestamp)|\(e.type)|\(e.payload)".utf8)
    }

    private func buildEnv(id: String, to: String, type: String, payload: String) -> Envelope {
        var e = Envelope(id: id, senderId: me, receiverId: to, timestamp: now(), ttl: MAX_TTL,
                         type: type, payload: payload, signature: "")
        e.signature = Crypto.sign(identity, sigInput(e))
        return e
    }

    private func helloEnv() -> Envelope {
        let hp = HelloPayload(nick: nickname, sign: identity.signPub.base64EncodedString(),
                              agree: identity.agreePub.base64EncodedString())
        let json = String(data: (try? JSONEncoder().encode(hp)) ?? Data(), encoding: .utf8) ?? "{}"
        return buildEnv(id: UUID().uuidString, to: BROADCAST, type: MsgType.hello, payload: json)
    }

    @discardableResult
    private func flood(_ env: Envelope, except: String?) -> Int {
        guard let data = try? JSONEncoder().encode(env) else { return 0 }
        var targets: [Link] = []
        if env.receiverId != BROADCAST {
            targets = links.values.filter { $0.peerId == env.receiverId && $0.id != except }
        }
        if targets.isEmpty { targets = links.values.filter { $0.id != except } }
        return targets.filter { $0.t.send(linkId: $0.id, data: data) }.count
    }

    // MARK: timers
    private func helloTick() {
        flood(helloEnv(), except: nil)
        let cutoff = Date().addingTimeInterval(-30)
        seen = seen.filter { $0.value > cutoff }
        buckets = buckets.filter { Date().timeIntervalSince($0.value.start) < 60 }
        refreshPeers()
    }

    private func retryTick() {
        let pending = messages.filter { $0.outgoing && $0.type == MsgType.chat && ($0.status == .queued || $0.status == .sent) }
        for m in pending {
            if m.attempts >= 50 { mutate(m.id) { $0.status = .failed } } else { transmit(m) }
        }
    }

    // MARK: events
    private func onEvent(_ t: BaseTransport, _ e: LinkEvent) {
        switch e {
        case .up(let id, let sig):
            links[id] = Link(id: id, t: t, signal: sig)
            if let data = try? JSONEncoder().encode(helloEnv()) { _ = t.send(linkId: id, data: data) }
            refreshPeers()
        case .down(let id):
            links[id] = nil
            refreshPeers()
        case .signal(let id, let s):
            links[id]?.signal = s
        case .data(let id, let d):
            onData(id, d)
        }
    }

    private func onData(_ linkId: String, _ bytes: Data) {
        guard let env = try? JSONDecoder().decode(Envelope.self, from: bytes) else { return }
        if env.senderId == me { return }
        if seen[env.id] != nil { return }
        seen[env.id] = Date()
        if !allow(env.senderId) { return }        // per-sender flood limit
        if !relayOk(env) { return }               // drop forgeries before relaying
        let forMe = env.receiverId == me
        if !forMe && env.ttl > 1 { var c = env; c.ttl -= 1; flood(c, except: linkId) }   // relay
        if forMe || env.receiverId == BROADCAST { process(env, linkId) }
    }

    // MARK: relay hardening (protocol v2)
    private var buckets: [String: (start: Date, count: Int)] = [:]

    /// Token bucket: at most 40 envelopes per sender per 10 s.
    private func allow(_ sender: String) -> Bool {
        let now = Date()
        var b = buckets[sender] ?? (now, 0)
        if now.timeIntervalSince(b.start) > 10 { b = (now, 0) }
        b.count += 1
        buckets[sender] = b
        return b.count <= 40
    }

    /// HELLO is self-certifying; other types are checked when we already know the sender's key.
    private func relayOk(_ env: Envelope) -> Bool {
        if env.type == MsgType.hello {
            guard let hp = try? JSONDecoder().decode(HelloPayload.self, from: Data(env.payload.utf8)),
                  let sp = Data(base64Encoded: hp.sign), let ap = Data(base64Encoded: hp.agree) else { return false }
            return Crypto.userId(sp, ap) == env.senderId && Crypto.verify(pub: sp, data: sigInput(env), sig: env.signature)
        }
        guard let peer = known[env.senderId], let sp = Data(base64Encoded: peer.signPub) else { return true }
        return Crypto.verify(pub: sp, data: sigInput(env), sig: env.signature)
    }

    private func process(_ env: Envelope, _ linkId: String) {
        if env.type == MsgType.hello {
            guard let hp = try? JSONDecoder().decode(HelloPayload.self, from: Data(env.payload.utf8)),
                  let sp = Data(base64Encoded: hp.sign), let ap = Data(base64Encoded: hp.agree),
                  Crypto.userId(sp, ap) == env.senderId,
                  Crypto.verify(pub: sp, data: sigInput(env), sig: env.signature) else { return }
            let old = known[env.senderId]
            let nick = String(hp.nick.prefix(32))
            known[env.senderId] = Peer(id: env.senderId, nick: nick.isEmpty ? "anon" : nick, signPub: hp.sign,
                                       agreePub: hp.agree, verified: old?.verified ?? false, lastSeen: Date())
            let hops = MAX_TTL - env.ttl + 1
            live[env.senderId] = (hops, Date())
            if hops == 1 { links[linkId]?.peerId = env.senderId }
            scheduleSave(); refreshPeers()
            let pending = messages.filter {
                $0.outgoing && $0.type == MsgType.chat && $0.receiverId == env.senderId
                    && ($0.status == .queued || $0.status == .sent)
            }
            pending.forEach { transmit($0) }                       // queue flush on (re)appearance
            return
        }
        guard let peer = known[env.senderId], let signPub = Data(base64Encoded: peer.signPub),
              Crypto.verify(pub: signPub, data: sigInput(env), sig: env.signature) else { return }
        switch env.type {
        case MsgType.chat:
            guard let theirPub = Data(base64Encoded: peer.agreePub),
                  let key = try? Crypto.sharedKey(me: identity, theirAgreePub: theirPub),
                  let plain = Crypto.decrypt(key, aad: aad(env.senderId, env.receiverId), b64: env.payload),
                  let text = String(data: plain, encoding: .utf8) else { return }
            let m = ChatMessage(id: env.id, convId: env.senderId, senderId: env.senderId, receiverId: me,
                                text: text, ts: Date(), status: .received, outgoing: false, type: MsgType.chat, attempts: 0)
            if insert(m) { notify(m) }
            flood(buildEnv(id: UUID().uuidString, to: env.senderId, type: MsgType.ack, payload: env.id), except: nil)
        case MsgType.room, MsgType.emergency:
            let conv = env.type == MsgType.room ? ROOM_ID : EMERGENCY_ID
            let m = ChatMessage(id: env.id, convId: conv, senderId: env.senderId, receiverId: BROADCAST,
                                text: env.payload, ts: Date(), status: .received, outgoing: false, type: env.type, attempts: 0)
            if insert(m) { notify(m) }
        case MsgType.ack:
            mutate(env.payload) { if $0.status != .delivered { $0.status = .delivered } }
        default: break
        }
    }

    // MARK: sending
    private func transmit(_ m: ChatMessage) {
        guard let peer = known[m.receiverId], let theirPub = Data(base64Encoded: peer.agreePub),
              let key = try? Crypto.sharedKey(me: identity, theirAgreePub: theirPub),
              let payload = try? Crypto.encrypt(key, aad: aad(m.senderId, m.receiverId), plain: Data(m.text.utf8)) else { return }
        let n = flood(buildEnv(id: m.id, to: m.receiverId, type: MsgType.chat, payload: payload), except: nil)
        mutate(m.id) { $0.attempts += 1; if n > 0 && $0.status != .delivered { $0.status = .sent } }
    }

    func sendChat(_ peerId: String, _ text: String) {
        let m = ChatMessage(id: UUID().uuidString.lowercased(), convId: peerId, senderId: me, receiverId: peerId,
                            text: String(text.prefix(2000)), ts: Date(), status: .queued, outgoing: true,
                            type: MsgType.chat, attempts: 0)
        _ = insert(m)
        transmit(m)
    }

    func sendRoom(_ text: String) { sendBroadcast(ROOM_ID, MsgType.room, text) }
    func sendEmergency(_ text: String) { sendBroadcast(EMERGENCY_ID, MsgType.emergency, text) }

    private func sendBroadcast(_ conv: String, _ type: String, _ text: String) {
        let t = String(text.prefix(2000))
        let id = UUID().uuidString.lowercased()
        let n = flood(buildEnv(id: id, to: BROADCAST, type: type, payload: t), except: nil)
        _ = insert(ChatMessage(id: id, convId: conv, senderId: me, receiverId: BROADCAST, text: t, ts: Date(),
                               status: n > 0 ? .sent : .failed, outgoing: true, type: type, attempts: 0))
    }

    func send(to conv: String, _ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return }
        switch conv {
        case ROOM_ID: sendRoom(t)
        case EMERGENCY_ID: sendEmergency(t)
        default: sendChat(conv, t)
        }
    }

    func retry(_ id: String) {
        mutate(id) { if $0.status == .failed { $0.status = .queued; $0.attempts = 0 } }
        if let m = messages.first(where: { $0.id == id }), m.type == MsgType.chat { transmit(m) }
    }

    // MARK: identity / verification
    func setVerified(_ id: String) { known[id]?.verified = true; scheduleSave(); refreshPeers() }
    func myQr() -> String { "offgrid1:\(identity.signPub.base64EncodedString()):\(identity.agreePub.base64EncodedString()):\(nickname)" }

    /// Returns the peer's nickname on success.
    func verifyFromQr(_ s: String) -> String? {
        let p = s.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
        guard p.count == 4, p[0] == "offgrid1", let sp = Data(base64Encoded: p[1]), let ap = Data(base64Encoded: p[2]),
              sp.count == 32, ap.count == 32 else { return nil }
        let id = Crypto.userId(sp, ap)
        let old = known[id]
        let nick = old?.nick ?? (p[3].isEmpty ? "anon" : String(p[3].prefix(32)))
        known[id] = Peer(id: id, nick: nick, signPub: p[1], agreePub: p[2], verified: true, lastSeen: old?.lastSeen ?? Date())
        scheduleSave(); refreshPeers()
        return nick
    }

    // MARK: state
    private func insert(_ m: ChatMessage) -> Bool {
        if messages.contains(where: { $0.id == m.id }) { return false }
        messages.append(m); scheduleSave()
        return true
    }

    private func mutate(_ id: String, _ f: (inout ChatMessage) -> Void) {
        guard let i = messages.firstIndex(where: { $0.id == id }) else { return }
        var m = messages[i]; f(&m); messages[i] = m
        scheduleSave()
    }

    private func notify(_ m: ChatMessage) {
        let c = UNMutableNotificationContent()
        let who = known[m.senderId]?.nick ?? String(m.senderId.prefix(6))
        c.title = (m.convId == EMERGENCY_ID ? "🚨 EMERGENCY from " : "") + who
        c.body = m.text; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: m.id, content: c, trigger: nil))
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Persistence.save(Snapshot(peers: Array(self.known.values), messages: self.messages))
        }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: w)
    }

    func refreshPeers() {
        let now = Date()
        peers = known.values.map { p in
            let direct = links.values.filter { $0.peerId == p.id }
            let l = live[p.id]
            let online = !direct.isEmpty || (l.map { now.timeIntervalSince($0.ts) < 60 } ?? false)
            return PeerView(
                id: p.id, nick: p.nick, verified: p.verified, online: online,
                hops: direct.isEmpty ? (l?.hops ?? 0) : 1,
                via: direct.isEmpty ? (online ? "relay" : "") : Set(direct.map { $0.t.label }).sorted().joined(separator: "+"),
                signal: direct.map { $0.signal }.first { !$0.isEmpty } ?? "",
                fingerprint: Crypto.fingerprint(p.id))
        }.sorted { ($0.online ? 0 : 1, $0.nick.lowercased()) < ($1.online ? 0 : 1, $1.nick.lowercased()) }
    }
}
