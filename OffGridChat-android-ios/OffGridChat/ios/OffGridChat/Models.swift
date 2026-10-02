import Foundation

enum MsgType {
    static let hello = "HELLO"
    static let chat = "CHAT"
    static let room = "ROOM"
    static let emergency = "EMERGENCY"
    static let ack = "ACK"
}

let BROADCAST = "*"
let ROOM_ID = "room"
let EMERGENCY_ID = "emergency"
let MAX_TTL = 7

/// Identical wire format to the Android app (JSON). `ttl` is not covered by the signature.
struct Envelope: Codable {
    var id: String
    var senderId: String
    var receiverId: String
    var timestamp: Int64
    var ttl: Int
    var type: String
    var payload: String
    var signature: String
}

struct HelloPayload: Codable {
    let nick: String
    let sign: String
    let agree: String
}

struct Peer: Codable {
    var id: String
    var nick: String
    var signPub: String
    var agreePub: String
    var verified: Bool
    var lastSeen: Date
}

enum MsgStatus: String, Codable { case queued, sent, delivered, failed, received }

struct ChatMessage: Codable, Identifiable {
    var id: String
    var convId: String
    var senderId: String
    var receiverId: String
    var text: String
    var ts: Date
    var status: MsgStatus
    var outgoing: Bool
    var type: String
    var attempts: Int
}
