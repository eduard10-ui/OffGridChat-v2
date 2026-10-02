import Foundation
import Combine

enum LinkEvent {
    case up(String, String)      // linkId, signal text
    case down(String)
    case signal(String, String)
    case data(String, Data)
}

struct TransportState {
    var active = false
    var links = 0
    var detail = "Stopped"
    var error: String? = nil
}

/// Base class for transports. `onEvent` is always invoked on the main thread.
class BaseTransport: NSObject, ObservableObject {
    @Published var state = TransportState()
    var onEvent: ((LinkEvent) -> Void)?
    var name: String { "" }
    var label: String { "" }
    func start(localId: String, nick: String) {}
    func stop() {}
    @discardableResult func send(linkId: String, data: Data) -> Bool { false }

    func fire(_ e: LinkEvent) {
        if Thread.isMainThread { onEvent?(e) } else { DispatchQueue.main.async { self.onEvent?(e) } }
    }
}
