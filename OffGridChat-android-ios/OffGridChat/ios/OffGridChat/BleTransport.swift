import Foundation
import CoreBluetooth

/// Cross-platform link to Android (and other iPhones). Same GATT service/characteristic and the same
/// chunk framing as the Android BleTransport (1 header byte: 1 = more chunks follow, 0 = last).
/// iOS cannot put manufacturer data in its advertisement, so Android treats advertisers WITHOUT it as iPhones.
final class BleTransport: BaseTransport, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {
    static let serviceUUID = CBUUID(string: "7D1F5B1E-3C1A-4F0A-9D5E-0F6F1B6A0C01")
    static let charUUID = CBUUID(string: "7D1F5B1E-3C1A-4F0A-9D5E-0F6F1B6A0C02")
    override var name: String { "ble" }
    override var label: String { "Bluetooth LE" }

    private final class Link {
        let id: String
        let central: CBCentral?            // set when the remote is a central connected to us
        let peripheral: CBPeripheral?      // set when we connected out to the remote
        let remoteChar: CBCharacteristic?
        var queue: [Data] = []
        var inFlight = false
        var rx = Data()
        init(id: String, central: CBCentral? = nil, peripheral: CBPeripheral? = nil, remoteChar: CBCharacteristic? = nil) {
            self.id = id; self.central = central; self.peripheral = peripheral; self.remoteChar = remoteChar
        }
    }

    private var cm: CBCentralManager?
    private var pm: CBPeripheralManager?
    private var myChar: CBMutableCharacteristic?
    private var localHex = ""
    private var running = false
    private var errorText: String?
    private var links: [String: Link] = [:]
    private var connecting: [UUID: CBPeripheral] = [:]
    private var lastSig: [String: Date] = [:]

    private func publish() {
        state = TransportState(active: running, links: links.count,
                               detail: running ? "Advertising + scanning (GATT)" : "Stopped", error: errorText)
    }

    override func start(localId: String, nick: String) {
        guard !running else { return }
        running = true; errorText = nil
        localHex = String(localId.prefix(16))
        cm = CBCentralManager(delegate: self, queue: .main)
        pm = CBPeripheralManager(delegate: self, queue: .main)
        publish()
    }

    override func stop() {
        running = false
        cm?.stopScan()
        pm?.stopAdvertising()
        for p in connecting.values { cm?.cancelPeripheralConnection(p) }
        for l in links.values { if let p = l.peripheral { cm?.cancelPeripheralConnection(p) } }
        let ids = Array(links.keys)
        links.removeAll(); connecting.removeAll()
        ids.forEach { fire(.down($0)) }
        cm = nil; pm = nil
        publish()
    }

    // MARK: sending
    override func send(linkId: String, data: Data) -> Bool {
        guard let l = links[linkId] else { return false }
        let maxChunk: Int
        if let p = l.peripheral { maxChunk = max(p.maximumWriteValueLength(for: .withoutResponse), 20) - 1 }
        else if let c = l.central { maxChunk = max(c.maximumUpdateValueLength, 20) - 1 }
        else { return false }
        var off = 0
        repeat {
            let end = min(off + maxChunk, data.count)
            var chunk = Data([end < data.count ? 1 : 0])
            chunk.append(data.subdata(in: off..<end))
            l.queue.append(chunk)
            off = end
        } while off < data.count
        pump(l)
        return true
    }

    private func pump(_ l: Link) {
        if let p = l.peripheral, let ch = l.remoteChar {
            guard !l.inFlight, let first = l.queue.first else { return }
            l.inFlight = true
            p.writeValue(first, for: ch, type: .withResponse)
        } else if let c = l.central, let ch = myChar, let pm = pm {
            while let first = l.queue.first {
                if pm.updateValue(first, for: ch, onSubscribedCentrals: [c]) { l.queue.removeFirst() } else { break }
            }
        }
    }

    private func receive(_ l: Link, _ v: Data) {
        guard let flag = v.first else { return }
        l.rx.append(v.dropFirst())
        if flag == 0 { let msg = l.rx; l.rx = Data(); fire(.data(l.id, msg)) }
    }

    private func removeLink(_ id: String) {
        if links.removeValue(forKey: id) != nil { fire(.down(id)); publish() }
    }

    // MARK: central role (we connect out)
    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn:
            errorText = nil
            c.scanForPeripherals(withServices: [Self.serviceUUID],
                                 options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        case .poweredOff: errorText = "Bluetooth is off"
        case .unauthorized: errorText = "Bluetooth permission denied (Settings > OffGrid Chat)"
        case .unsupported: errorText = "Bluetooth LE not supported"
        default: break
        }
        publish()
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = "ble:\(p.identifier.uuidString)"
        if links[id] != nil {
            let now = Date()
            if now.timeIntervalSince(lastSig[id] ?? .distantPast) > 3 {
                lastSig[id] = now; fire(.signal(id, "\(RSSI.intValue) dBm"))
            }
            return
        }
        if connecting[p.identifier] != nil { return }
        // Android peers carry manufacturer data (0xFFFF + 8 id bytes): the smaller id connects.
        // Peers without it are iPhones: connect (duplicate links are harmless, messages are de-duplicated).
        if let md = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, md.count >= 10 {
            let b = [UInt8](md)
            if b[0] == 0xFF && b[1] == 0xFF {
                let remote = b[2..<10].map { String(format: "%02x", $0) }.joined()
                if !(localHex < remote) { return }
            }
        }
        connecting[p.identifier] = p
        p.delegate = self
        c.connect(p, options: nil)
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        p.discoverServices([Self.serviceUUID])
    }
    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        connecting[p.identifier] = nil
    }
    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        connecting[p.identifier] = nil
        removeLink("ble:\(p.identifier.uuidString)")
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard let s = p.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            cm?.cancelPeripheralConnection(p); return
        }
        p.discoverCharacteristics([Self.charUUID], for: s)
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        guard let ch = s.characteristics?.first(where: { $0.uuid == Self.charUUID }) else {
            cm?.cancelPeripheralConnection(p); return
        }
        p.setNotifyValue(true, for: ch)
    }
    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor ch: CBCharacteristic, error: Error?) {
        let id = "ble:\(p.identifier.uuidString)"
        if ch.isNotifying && links[id] == nil {
            links[id] = Link(id: id, peripheral: p, remoteChar: ch)
            connecting[p.identifier] = nil
            fire(.up(id, "")); publish()
        }
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        if let v = ch.value, let l = links["ble:\(p.identifier.uuidString)"] { receive(l, v) }
    }
    func peripheral(_ p: CBPeripheral, didWriteValueFor ch: CBCharacteristic, error: Error?) {
        guard let l = links["ble:\(p.identifier.uuidString)"] else { return }
        l.inFlight = false
        if error == nil { if !l.queue.isEmpty { l.queue.removeFirst() } } else { l.queue.removeAll() }
        pump(l)
    }

    // MARK: peripheral role (others connect to us)
    func peripheralManagerDidUpdateState(_ p: CBPeripheralManager) {
        switch p.state {
        case .poweredOn:
            let ch = CBMutableCharacteristic(type: Self.charUUID, properties: [.write, .notify],
                                             value: nil, permissions: [.writeable])
            myChar = ch
            let svc = CBMutableService(type: Self.serviceUUID, primary: true)
            svc.characteristics = [ch]
            p.removeAllServices()
            p.add(svc)
        case .unauthorized: errorText = "Bluetooth permission denied (Settings > OffGrid Chat)"; publish()
        case .poweredOff: errorText = "Bluetooth is off"; publish()
        default: break
        }
    }
    func peripheralManager(_ p: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error { errorText = "GATT service failed: \(error.localizedDescription)"; publish(); return }
        p.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID]])
    }
    func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didSubscribeTo ch: CBCharacteristic) {
        let id = "ble:\(central.identifier.uuidString)"
        if links[id] == nil { links[id] = Link(id: id, central: central); fire(.up(id, "")); publish() }
    }
    func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom ch: CBCharacteristic) {
        removeLink("ble:\(central.identifier.uuidString)")
    }
    func peripheralManager(_ p: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        if let first = requests.first { p.respond(to: first, withResult: .success) }
        for r in requests {
            if let v = r.value, let l = links["ble:\(r.central.identifier.uuidString)"] { receive(l, v) }
        }
    }
    func peripheralManagerIsReady(toUpdateSubscribers p: CBPeripheralManager) {
        links.values.forEach { pump($0) }
    }
}
