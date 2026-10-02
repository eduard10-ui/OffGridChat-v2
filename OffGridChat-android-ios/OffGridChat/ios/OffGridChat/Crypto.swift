import Foundation
import CryptoKit
import Security

/// Byte-for-byte compatible with the Android Crypto.kt:
/// Ed25519 signatures, X25519 -> HKDF-SHA256 (salt = sorted pubkeys, info "offgrid-e2e-v1") -> AES-256-GCM,
/// payload = base64(iv12 || ciphertext || tag16), AAD = "senderId|receiverId".
struct Identity {
    let signKey: Curve25519.Signing.PrivateKey
    let agreeKey: Curve25519.KeyAgreement.PrivateKey
    var signPub: Data { signKey.publicKey.rawRepresentation }
    var agreePub: Data { agreeKey.publicKey.rawRepresentation }
    var userId: String { Crypto.userId(signPub, agreePub) }

    static func loadOrCreate() -> Identity {
        if let d = KeychainStore.load("identity"), d.count == 64,
           let s = try? Curve25519.Signing.PrivateKey(rawRepresentation: d.prefix(32)),
           let a = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: d.suffix(32)) {
            return Identity(signKey: s, agreeKey: a)
        }
        let id = Identity(signKey: Curve25519.Signing.PrivateKey(), agreeKey: Curve25519.KeyAgreement.PrivateKey())
        KeychainStore.save("identity", id.signKey.rawRepresentation + id.agreeKey.rawRepresentation)
        return id
    }
}

enum Crypto {
    static func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

    static func userId(_ signPub: Data, _ agreePub: Data) -> String {
        String(hex(Data(SHA256.hash(data: signPub + agreePub))).prefix(32))
    }

    static func fingerprint(_ id: String) -> String {
        let u = Array(id.uppercased())
        return stride(from: 0, to: u.count, by: 4).map { String(u[$0..<min($0 + 4, u.count)]) }.joined(separator: " ")
    }

    static func sign(_ id: Identity, _ data: Data) -> String {
        ((try? id.signKey.signature(for: data)) ?? Data()).base64EncodedString()
    }

    static func verify(pub: Data, data: Data, sig: String) -> Bool {
        guard let k = try? Curve25519.Signing.PublicKey(rawRepresentation: pub),
              let s = Data(base64Encoded: sig) else { return false }
        return k.isValidSignature(s, for: data)
    }

    static func sharedKey(me: Identity, theirAgreePub: Data) throws -> SymmetricKey {
        let their = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirAgreePub)
        let secret = try me.agreeKey.sharedSecretFromKeyAgreement(with: their)
        let sorted = [me.agreePub, theirAgreePub].sorted { hex($0) < hex($1) }
        return secret.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: sorted[0] + sorted[1],
            sharedInfo: Data("offgrid-e2e-v1".utf8), outputByteCount: 32)
    }

    static func encrypt(_ key: SymmetricKey, aad: Data, plain: Data) throws -> String {
        let box = try AES.GCM.seal(plain, using: key, authenticating: aad)
        return (box.combined ?? Data()).base64EncodedString()
    }

    static func decrypt(_ key: SymmetricKey, aad: Data, b64: String) -> Data? {
        guard let all = Data(base64Encoded: b64), let box = try? AES.GCM.SealedBox(combined: all) else { return nil }
        return try? AES.GCM.open(box, using: key, authenticating: aad)
    }
}

enum KeychainStore {
    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.offgrid.chat",
         kSecAttrAccount as String: account]
    }
    static func load(_ account: String) -> Data? {
        var q = base(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }
    static func save(_ account: String, _ data: Data) {
        SecItemDelete(base(account) as CFDictionary)
        var q = base(account)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}

struct Snapshot: Codable {
    var peers: [Peer]
    var messages: [ChatMessage]
}

enum Persistence {
    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("offgrid.json")
    }
    static func load() -> Snapshot {
        guard let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Snapshot.self, from: d) else {
            return Snapshot(peers: [], messages: [])
        }
        return s
    }
    static func save(_ s: Snapshot) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(s) {
            try? d.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }
}
