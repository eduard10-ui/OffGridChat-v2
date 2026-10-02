import Foundation

/// Client side of the hotspot/LAN transport. Joins the WebSocket server that an Android phone hosts
/// (ws://<gateway>:8765/chat). iOS cannot create a hotspot programmatically, so iPhones only act as clients.
/// The gateway is guessed as x.x.x.1 of the Wi-Fi subnet; override it in Radios if your host uses another IP.
final class LanTransport: BaseTransport, URLSessionWebSocketDelegate {
    override var name: String { "hotspot" }
    override var label: String { "Hotspot/LAN" }

    private let port = 8765
    private let linkId = "hotspot:host"
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var connecting = false
    private var timer: Timer?
    private var errorText: String?

    var manualHost: String {
        get { UserDefaults.standard.string(forKey: "lanHost") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lanHost") }
    }

    private func publish() {
        state = TransportState(active: timer != nil, links: task != nil ? 1 : 0,
                               detail: task != nil ? "Connected to host" : "Joining: looks for an Android host on this Wi-Fi",
                               error: errorText)
    }

    override func start(localId: String, nick: String) {
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in self?.tick() }
        tick(); publish()
    }

    override func stop() {
        timer?.invalidate(); timer = nil
        task?.cancel(with: .goingAway, reason: nil); task = nil
        connecting = false
        publish()
    }

    private func tick() {
        guard task == nil, !connecting, let session else { return }
        let manual = manualHost.trimmingCharacters(in: .whitespaces)
        guard let ip = manual.isEmpty ? guessGateway() : manual,
              let url = URL(string: "ws://\(ip):\(port)/chat") else { return }
        connecting = true
        session.webSocketTask(with: url).resume()
    }

    private func guessGateway() -> String? {
        guard let ip = wifiIPv4() else { return nil }
        var parts = ip.split(separator: ".").map(String.init)
        guard parts.count == 4, parts[3] != "1" else { return nil }
        parts[3] = "1"
        return parts.joined(separator: ".")
    }

    private func wifiIPv4() -> String? {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return nil }
        defer { freeifaddrs(addrs) }
        var p: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = p {
            let i = cur.pointee
            if let a = i.ifa_addr, a.pointee.sa_family == UInt8(AF_INET), String(cString: i.ifa_name) == "en0" {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(a, socklen_t(a.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                return String(cString: host)
            }
            p = i.ifa_next
        }
        return nil
    }

    private func receiveLoop(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let m):
                if case .data(let d) = m { self.fire(.data(self.linkId, d)) }
                self.receiveLoop(t)
            case .failure:
                self.drop(t)
            }
        }
    }

    private func drop(_ t: URLSessionWebSocketTask) {
        connecting = false
        if task === t { task = nil; fire(.down(linkId)) }
        publish()
    }

    override func send(linkId: String, data: Data) -> Bool {
        guard linkId == self.linkId, let t = task else { return false }
        t.send(.data(data)) { [weak self] err in if err != nil { self?.drop(t) } }
        return true
    }

    // MARK: URLSessionWebSocketDelegate
    func urlSession(_ s: URLSession, webSocketTask t: URLSessionWebSocketTask, didOpenWithProtocol p: String?) {
        task = t; connecting = false; errorText = nil
        fire(.up(linkId, "LAN")); publish()
        receiveLoop(t)
    }
    func urlSession(_ s: URLSession, webSocketTask t: URLSessionWebSocketTask,
                    didCloseWith code: URLSessionWebSocketTask.CloseCode, reason: Data?) { drop(t) }
    func urlSession(_ s: URLSession, task t: URLSessionTask, didCompleteWithError error: Error?) {
        if let wt = t as? URLSessionWebSocketTask { drop(wt) }
    }
}
