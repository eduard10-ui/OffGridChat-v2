package com.offgrid.chat.mesh

import android.content.Context
import androidx.room.Room
import com.offgrid.chat.crypto.*
import com.offgrid.chat.data.*
import com.offgrid.chat.model.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

const val MAX_TTL = 7
private const val DEDUPE_MS = 30_000L      // time-based so queued retries can pass relays again
private const val HELLO_EVERY_MS = 20_000L
private const val RETRY_EVERY_MS = 45_000L
private const val MAX_ATTEMPTS = 50

data class PeerView(
    val id: String, val nick: String, val verified: Boolean, val online: Boolean,
    val hops: Int, val via: String, val signal: String, val fingerprint: String
)

data class TransportInfo(val name: String, val label: String, val state: TransportState)

/**
 * Core: identity, routing (flood with TTL + dedupe), E2E crypto, queue/retry, persistence.
 * Transports only move bytes.
 */
class MeshEngine(private val ctx: Context) {
    private val json = Json { ignoreUnknownKeys = true }
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val prefs = ctx.getSharedPreferences("offgrid", Context.MODE_PRIVATE)
    private val dao = Room.databaseBuilder(ctx, AppDb::class.java, "offgrid.db").build().dao()

    val identity: Identity = loadIdentity()
    val me: String get() = identity.userId
    val nickname = MutableStateFlow(prefs.getString("nick", "") ?: "")
    /** iPhones are only reachable over BLE (or the hotspot LAN), so this keeps BLE running permanently. */
    val bleAlways = MutableStateFlow(prefs.getBoolean("ble_always", false))
    fun setBleAlways(on: Boolean) { prefs.edit().putBoolean("ble_always", on).apply(); bleAlways.value = on }

    val nearby = NearbyTransport(ctx, scope)
    val hotspot = HotspotSocketTransport(ctx, scope)
    val ble = BleTransport(ctx, scope)
    private val transports: List<Transport> = listOf(nearby, hotspot, ble)

    private class Link(val id: String, val t: Transport, @Volatile var peerId: String? = null, @Volatile var signal: String = "")
    private class Live(val hops: Int, val ts: Long)

    private val links = ConcurrentHashMap<String, Link>()
    private val seen = ConcurrentHashMap<String, Long>()
    private val live = MutableStateFlow<Map<String, Live>>(emptyMap())
    private val linkTick = MutableStateFlow(0)
    private val clock = flow { while (true) { emit(System.currentTimeMillis()); delay(5_000) } }

    val incoming = MutableSharedFlow<MessageEntity>(extraBufferCapacity = 64)

    val transportInfo: StateFlow<List<TransportInfo>> =
        combine(transports.map { it.state }) { arr ->
            transports.mapIndexed { i, t -> TransportInfo(t.name, t.label, arr[i]) }
        }.stateIn(scope, SharingStarted.Eagerly, emptyList())

    val peers: StateFlow<List<PeerView>> =
        combine(dao.peers(), live, linkTick, clock) { list, lv, _, now ->
            list.map { p ->
                val direct = links.values.filter { it.peerId == p.id }
                val l = lv[p.id]
                val online = direct.isNotEmpty() || (l != null && now - l.ts < 60_000)
                PeerView(
                    p.id, p.nick, p.verified, online,
                    if (direct.isNotEmpty()) 1 else (l?.hops ?: 0),
                    if (direct.isNotEmpty()) direct.map { it.t.label }.distinct().joinToString("+") else if (online) "relay" else "",
                    direct.map { it.signal }.firstOrNull { it.isNotEmpty() } ?: "",
                    Crypto.fingerprint(p.id)
                )
            }.sortedWith(compareByDescending<PeerView> { it.online }.thenBy { it.nick.lowercase() })
        }.stateIn(scope, SharingStarted.Eagerly, emptyList())

    // ------------------------------------------------------------ lifecycle
    private var started = false
    private val jobs = mutableListOf<Job>()

    @Synchronized
    fun start() {
        if (started || nickname.value.isBlank()) return
        started = true
        transports.forEach { t ->
            jobs += scope.launch(start = CoroutineStart.UNDISPATCHED) { t.events.collect { onEvent(t, it) } }
        }
        nearby.start(me, nickname.value)
        hotspot.start(me, nickname.value)
        jobs += scope.launch { helloLoop() }
        jobs += scope.launch { retryLoop() }
        jobs += scope.launch { fallbackLoop() }
    }

    @Synchronized
    fun stop() {
        jobs.forEach { it.cancel() }; jobs.clear()
        transports.forEach { it.stop() }
        links.clear(); started = false
    }

    fun setNickname(n: String) {
        val nick = n.trim().take(32)
        prefs.edit().putString("nick", nick).apply()
        nickname.value = nick
        if (!started) start() else scope.launch { flood(helloEnv(), null) }
    }

    private fun loadIdentity(): Identity {
        prefs.getString("ident", null)?.let { s ->
            val p = s.split(",")
            return Identity(p[0].unb64(), p[1].unb64(), p[2].unb64(), p[3].unb64())
        }
        val id = Crypto.newIdentity()
        prefs.edit().putString("ident",
            listOf(id.signSeed, id.signPub, id.agreePriv, id.agreePub).joinToString(",") { it.b64() }).apply()
        return id
    }

    // ------------------------------------------------------------ background loops
    private suspend fun helloLoop() {
        while (true) {
            flood(helloEnv(), null)
            val now = System.currentTimeMillis()
            seen.entries.removeIf { now - it.value > DEDUPE_MS }
            buckets.entries.removeIf { now - it.value[0] > 60_000 }
            delay(HELLO_EVERY_MS)
        }
    }

    private suspend fun retryLoop() {
        while (true) {
            delay(RETRY_EVERY_MS)
            for (m in dao.allPending()) {
                if (m.attempts >= MAX_ATTEMPTS) dao.updateStatus(m.id, "FAILED") else transmit(m)
            }
        }
    }

    /** BLE is the last resort: start only when the other transports have had no links for a while. */
    private suspend fun fallbackLoop() {
        var noPrimarySince: Long? = null
        var primarySince: Long? = null
        while (true) {
            delay(5_000)
            if (bleAlways.value) {
                if (!ble.state.value.active) ble.start(me, nickname.value)
                continue
            }
            val now = System.currentTimeMillis()
            val primary = nearby.state.value.links + hotspot.state.value.links
            if (primary == 0) {
                primarySince = null
                val since = noPrimarySince ?: now.also { noPrimarySince = it }
                if (!ble.state.value.active && now - since > 15_000) ble.start(me, nickname.value)
            } else {
                noPrimarySince = null
                val since = primarySince ?: now.also { primarySince = it }
                if (ble.state.value.active && ble.state.value.links == 0 && now - since > 30_000) ble.stop()
            }
        }
    }

    // ------------------------------------------------------------ transport events
    private suspend fun onEvent(t: Transport, e: LinkEvent) {
        when (e) {
            is LinkEvent.Up -> {
                links[e.linkId] = Link(e.linkId, t, signal = e.signal)
                linkTick.update { it + 1 }
                links[e.linkId]?.let { t.send(it.id, encode(helloEnv())) }
            }
            is LinkEvent.Down -> { links.remove(e.linkId); linkTick.update { it + 1 } }
            is LinkEvent.Signal -> { links[e.linkId]?.signal = e.text; linkTick.update { it + 1 } }
            is LinkEvent.Data -> onData(e.linkId, e.bytes)
        }
    }

    private suspend fun onData(linkId: String, bytes: ByteArray) {
        val env = try { json.decodeFromString<Envelope>(String(bytes, Charsets.UTF_8)) } catch (e: Exception) { return }
        if (env.senderId == me) return
        if (seen.putIfAbsent(env.id, System.currentTimeMillis()) != null) return   // duplicate
        if (!allow(env.senderId)) return          // per-sender flood limit
        if (!relayOk(env)) return                 // drop forgeries before relaying
        val forMe = env.receiverId == me
        if (!forMe && env.ttl > 1) flood(env.copy(ttl = env.ttl - 1), except = linkId)   // relay
        if (forMe || env.receiverId == BROADCAST) process(env, linkId)
    }

    // ------------------------------------------------------------ relay hardening (protocol v2)
    private val buckets = ConcurrentHashMap<String, LongArray>()

    /** Token bucket: at most 40 envelopes per sender per 10 s. */
    private fun allow(sender: String): Boolean {
        val now = System.currentTimeMillis()
        val b = buckets.getOrPut(sender) { longArrayOf(now, 0) }
        synchronized(b) {
            if (now - b[0] > 10_000) { b[0] = now; b[1] = 0 }
            b[1]++
            return b[1] <= 40
        }
    }

    /** HELLO is self-certifying; other types are checked when we already know the sender's key. */
    private suspend fun relayOk(env: Envelope): Boolean {
        if (env.type == MsgType.HELLO) {
            val hp = try { json.decodeFromString<HelloPayload>(env.payload) } catch (e: Exception) { return false }
            val sp = try { hp.sign.unb64() } catch (e: Exception) { return false }
            val ap = try { hp.agree.unb64() } catch (e: Exception) { return false }
            return Crypto.userId(sp, ap) == env.senderId && Crypto.verify(sp, sigInput(env), env.signature)
        }
        val peer = dao.peer(env.senderId) ?: return true   // key not known yet: relay, cannot verify
        return Crypto.verify(peer.signPub.unb64(), sigInput(env), env.signature)
    }

    private suspend fun process(env: Envelope, linkId: String) {
        val now = System.currentTimeMillis()
        if (env.type == MsgType.HELLO) {
            val hp = try { json.decodeFromString<HelloPayload>(env.payload) } catch (e: Exception) { return }
            val sp = hp.sign.unb64(); val ap = hp.agree.unb64()
            if (Crypto.userId(sp, ap) != env.senderId) return
            if (!Crypto.verify(sp, sigInput(env), env.signature)) return
            val old = dao.peer(env.senderId)
            dao.upsertPeer(PeerEntity(env.senderId, hp.nick.take(32).ifBlank { "anon" }, hp.sign, hp.agree, old?.verified ?: false, now))
            val hops = MAX_TTL - env.ttl + 1
            live.update { it + (env.senderId to Live(hops, now)) }
            if (hops == 1) { links[linkId]?.peerId = env.senderId; linkTick.update { it + 1 } }
            dao.pendingFor(env.senderId).forEach { transmit(it) }   // queue flush when peer (re)appears
            return
        }
        val peer = dao.peer(env.senderId) ?: return                 // unknown sender: ignore
        if (!Crypto.verify(peer.signPub.unb64(), sigInput(env), env.signature)) return
        when (env.type) {
            MsgType.CHAT -> {
                val key = Crypto.sharedKey(identity, peer.agreePub.unb64())
                val plain = Crypto.decrypt(key, aad(env.senderId, env.receiverId), env.payload) ?: return
                val m = MessageEntity(env.id, env.senderId, env.senderId, me, String(plain), now, "RECEIVED", false, MsgType.CHAT)
                if (dao.insertMsg(m) != -1L) incoming.tryEmit(m)
                flood(buildEnv(UUID.randomUUID().toString(), env.senderId, MsgType.ACK, env.id), null)
            }
            MsgType.ROOM, MsgType.EMERGENCY -> {
                val conv = if (env.type == MsgType.ROOM) ROOM_ID else EMERGENCY_ID
                val m = MessageEntity(env.id, conv, env.senderId, BROADCAST, env.payload, now, "RECEIVED", false, env.type)
                if (dao.insertMsg(m) != -1L) incoming.tryEmit(m)
            }
            MsgType.ACK -> dao.updateStatus(env.payload, "DELIVERED")
        }
    }

    // ------------------------------------------------------------ sending
    private fun aad(from: String, to: String) = "$from|$to".toByteArray()
    private fun sigInput(e: Envelope) =
        "${e.id}|${e.senderId}|${e.receiverId}|${e.timestamp}|${e.type}|${e.payload}".toByteArray()
    private fun encode(e: Envelope) = json.encodeToString(e).toByteArray()

    private fun buildEnv(id: String, to: String, type: String, payload: String): Envelope {
        val base = Envelope(id, me, to, System.currentTimeMillis(), MAX_TTL, type, payload, "")
        return base.copy(signature = Crypto.sign(identity, sigInput(base)))
    }

    private fun helloEnv(): Envelope = buildEnv(
        UUID.randomUUID().toString(), BROADCAST, MsgType.HELLO,
        json.encodeToString(HelloPayload(nickname.value, identity.signPub.b64(), identity.agreePub.b64()))
    )

    /** Sends on the direct link(s) to the receiver if we have one; otherwise floods all links. */
    private fun flood(env: Envelope, except: String?): Int {
        val bytes = encode(env)
        val direct = if (env.receiverId != BROADCAST)
            links.values.filter { it.peerId == env.receiverId && it.id != except } else emptyList()
        val targets = direct.ifEmpty { links.values.filter { it.id != except } }
        return targets.count { it.t.send(it.id, bytes) }
    }

    private suspend fun transmit(m: MessageEntity) {
        val peer = dao.peer(m.receiverId) ?: return
        val key = Crypto.sharedKey(identity, peer.agreePub.unb64())
        val payload = Crypto.encrypt(key, aad(m.senderId, m.receiverId), m.text.toByteArray())
        val n = flood(buildEnv(m.id, m.receiverId, MsgType.CHAT, payload), null)
        dao.bump(m.id)
        if (n > 0) dao.updateStatus(m.id, "SENT")
    }

    suspend fun sendChat(peerId: String, text: String) {
        val m = MessageEntity(UUID.randomUUID().toString(), peerId, me, peerId, text.take(2000),
            System.currentTimeMillis(), "QUEUED", true, MsgType.CHAT)
        dao.insertMsg(m)
        transmit(m)
    }

    suspend fun sendRoom(text: String) = sendBroadcast(ROOM_ID, MsgType.ROOM, text)
    suspend fun sendEmergency(text: String) = sendBroadcast(EMERGENCY_ID, MsgType.EMERGENCY, text)

    private suspend fun sendBroadcast(conv: String, type: String, text: String) {
        val t = text.take(2000)
        val id = UUID.randomUUID().toString()
        val n = flood(buildEnv(id, BROADCAST, type, t), null)
        dao.insertMsg(MessageEntity(id, conv, me, BROADCAST, t, System.currentTimeMillis(),
            if (n > 0) "SENT" else "FAILED", true, type))
    }

    suspend fun retry(id: String) {
        dao.resetFailed(id)
        dao.msg(id)?.takeIf { it.type == MsgType.CHAT }?.let { transmit(it) }
    }

    // ------------------------------------------------------------ UI helpers
    fun messages(conv: String): Flow<List<MessageEntity>> = dao.conv(conv)
    suspend fun nickOf(id: String): String = dao.peer(id)?.nick ?: id.take(6)
    suspend fun setVerified(id: String) = dao.setVerified(id)

    fun myQr(): String = "offgrid1:${identity.signPub.b64()}:${identity.agreePub.b64()}:${nickname.value}"

    /** Returns the peer's nickname on success. Scanning the QR in person proves who owns the keys. */
    suspend fun verifyFromQr(s: String): String? {
        val p = s.split(":", limit = 4)
        if (p.size < 4 || p[0] != "offgrid1") return null
        val sp: ByteArray; val ap: ByteArray
        try { sp = p[1].unb64(); ap = p[2].unb64() } catch (e: Exception) { return null }
        if (sp.size != 32 || ap.size != 32) return null
        val id = Crypto.userId(sp, ap)
        val old = dao.peer(id)
        val nick = old?.nick ?: p[3].take(32).ifBlank { "anon" }
        dao.upsertPeer(PeerEntity(id, nick, p[1], p[2], true, old?.lastSeen ?: 0))
        return nick
    }
}
