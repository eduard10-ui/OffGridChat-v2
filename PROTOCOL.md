# OffGrid Mesh Protocol v2

Transport-agnostic, serverless, store-and-forward mesh for phones. Same wire format on Android (Kotlin) and iOS (Swift).

## 0. What is and is not possible (read first)

| Claim | Reality |
|---|---|
| iOS Multipeer <-> Android Nearby direct | **Impossible.** Both are closed, proprietary stacks. They never interoperate. |
| Wi-Fi Direct on iPhone | **Not exposed to apps.** iOS apps cannot use Wi-Fi Direct/Aware to talk to Android. |
| iPhone-to-Android link | Only two open paths: **BLE GATT** (this spec, section 3) and **Wi-Fi LAN socket** to an Android-hosted hotspot. |
| Bridging | Done in the **routing layer**, not the radio layer: any node holding two transports relays between them (e.g. iPhone A --Multipeer-- iPhone B --BLE-- Android C --Nearby-- Android D). |
| "Sub-second latency" | Realistic: 50-300 ms per hop on Nearby/Multipeer/LAN, 200 ms-2 s per hop on BLE. Not guaranteed; BLE connection setup can take several seconds. |
| "Bulletproof" | No. Radios drop, iOS suspends background apps, OEMs kill services. The protocol therefore assumes loss and uses queue + retry + ACK. |

## 1. Layers

```
App (chat UI)
Routing/Session engine   <- identical logic on both OS (flood + TTL + dedupe + queue + E2E crypto)
Transport adapters       <- Nearby | Multipeer | BLE GATT | LAN WebSocket
Radios
```
A transport only moves opaque byte arrays over *links* (one per directly connected neighbour). All protocol logic lives above it.

## 2. Identity and handshake

* Each node: Ed25519 signing key + X25519 agreement key. `userId = hex(SHA-256(signPub || agreePub))[0:32]` (self-certifying; cannot be claimed without the keys).
* **Handshake = one HELLO per link, both directions, on link-up** (no round trips, no pairing, no server):
  1. Link up -> each side immediately sends signed HELLO `{nick, sign, agree}`.
  2. Receiver checks `userId == hash(keys)` and the Ed25519 signature, stores the peer.
  3. Both sides can now derive the same AES-256-GCM key (X25519 -> HKDF-SHA256) with no further messages.
* HELLO is re-flooded every 20 s (ttl 7) so multi-hop peers learn keys and liveness.
* Trust: first-contact is TOFU; QR / fingerprint comparison marks a peer **verified**.

## 3. Cross-platform link rules (the part that removes fragmentation)

| Pair | Link | Initiator rule |
|---|---|---|
| Android-Android | Nearby (P2P_CLUSTER) | smaller userId requests the connection |
| iOS-iOS | Multipeer | smaller userId invites |
| iOS-Android | BLE GATT | Android connects to adverts that carry **no** manufacturer data (= iPhone). iPhone connects to Android adverts only if its id is smaller. Duplicate links are harmless (dedupe). |
| any | LAN WebSocket | joiners connect to host IP:8765 (Android hosts; iOS is client only) |

GATT: service `7d1f5b1e-3c1a-4f0a-9d5e-0f6f1b6a0c01`, one characteristic `...02` (write + notify). Android adverts add manufacturer data `0xFFFF + first 8 bytes of userId`.
Framing on BLE: 1 header byte (`1` = more chunks follow, `0` = last) + payload, chunk <= MTU-4.

## 4. Envelope (JSON, UTF-8)

```
{ id, senderId, receiverId ("*" = broadcast), timestamp(ms), ttl, type, payload, signature }
```
* `signature` = Ed25519 over `id|senderId|receiverId|timestamp|type|payload` (ttl excluded, relays decrement it).
* Types: HELLO, CHAT (E2E encrypted, payload = b64(iv12||ct||tag16), AAD = `sender|receiver`), ROOM, EMERGENCY (signed, not encrypted), ACK (payload = acked id).
* **Forward-compat:** unknown JSON keys and unknown `type` values MUST be ignored (but still relayed).

## 5. Routing

* Flood with TTL (max 7) + time-based dedupe (30 s; time-based so queued retries can cross relays again).
* Directed messages go only to the direct link(s) of the destination if one exists, else flood.
* Relays do not decrypt (CHAT is end-to-end).
* **v2 hardening:** relays verify the signature when they know the sender's key and drop forgeries; per-sender token bucket (40 envelopes / 10 s) limits flooding.

## 6. Reliability

* Sender stores every CHAT as QUEUED, floods, marks SENT if >= 1 link accepted it, DELIVERED on ACK.
* Retry every 45 s and immediately when the destination's HELLO is seen; FAILED after 50 attempts, user can retry.
* Receiver re-ACKs duplicates (idempotent insert).

## 7. Security summary

E2E: X25519 + HKDF + AES-256-GCM (1:1). Authenticity: Ed25519 on every envelope. Identity: self-certifying IDs + QR verification. Known gaps: no forward secrecy (add a double ratchet), group/emergency not encrypted, no replay window (clocks are unreliable offline), identity keys stored in Keychain (iOS) but plain app-private prefs (Android).
