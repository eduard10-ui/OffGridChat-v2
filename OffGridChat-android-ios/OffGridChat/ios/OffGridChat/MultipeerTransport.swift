import Foundation
import MultipeerConnectivity

/// iPhone <-> iPhone only (Apple's equivalent of Nearby Connections: BLE + peer-to-peer Wi-Fi).
/// It cannot talk to Android; Android reaches iPhones through BLE or the LAN transport.
final class MultipeerTransport: BaseTransport, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    override var name: String { "multipeer" }
    override var label: String { "Multipeer (iPhone)" }

    private let serviceType = "offgrid-chat"
    private var localId = ""
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var linked: [String: MCPeerID] = [:]
    private var running = false

    private func publish() {
        state = TransportState(active: running, links: linked.count,
                               detail: running ? "Advertising + browsing (iPhone to iPhone)" : "Stopped", error: nil)
    }

    override func start(localId: String, nick: String) {
        guard !running else { return }
        running = true; self.localId = localId
        let pid = MCPeerID(displayName: localId)
        let s = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        let a = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: nil, serviceType: serviceType)
        a.delegate = self; a.startAdvertisingPeer()
        let b = MCNearbyServiceBrowser(peer: pid, serviceType: serviceType)
        b.delegate = self; b.startBrowsingForPeers()
        session = s; advertiser = a; browser = b
        publish()
    }

    override func stop() {
        running = false
        advertiser?.stopAdvertisingPeer(); browser?.stopBrowsingForPeers(); session?.disconnect()
        let ids = Array(linked.keys)
        linked.removeAll()
        ids.forEach { fire(.down($0)) }
        session = nil; advertiser = nil; browser = nil
        publish()
    }

    override func send(linkId: String, data: Data) -> Bool {
        guard let s = session, let p = linked[linkId] else { return false }
        do { try s.send(data, toPeers: [p], with: .reliable); return true } catch { return false }
    }

    // Only the smaller id invites, so a pair never connects twice.
    func browser(_ b: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            guard let s = self.session, self.localId < peerID.displayName,
                  self.linked["mpc:\(peerID.displayName)"] == nil else { return }
            b.invitePeer(peerID, to: s, withContext: nil, timeout: 20)
        }
    }
    func browser(_ b: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func session(_ s: MCSession, peer peerID: MCPeerID, didChange st: MCSessionState) {
        DispatchQueue.main.async {
            let id = "mpc:\(peerID.displayName)"
            switch st {
            case .connected:
                if self.linked[id] == nil { self.linked[id] = peerID; self.fire(.up(id, "")); self.publish() }
            case .notConnected:
                if self.linked.removeValue(forKey: id) != nil { self.fire(.down(id)); self.publish() }
            default: break
            }
        }
    }
    func session(_ s: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        fire(.data("mpc:\(peerID.displayName)", data))
    }
    func session(_ s: MCSession, didReceive stream: InputStream, withName name: String, fromPeer peerID: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer p: MCPeerID, with pr: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer p: MCPeerID, at u: URL?, withError e: Error?) {}
}
