package com.offgrid.chat.mesh

import android.annotation.SuppressLint
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.ktor.server.application.install
import io.ktor.server.cio.CIO
import io.ktor.server.engine.ApplicationEngine
import io.ktor.server.engine.embeddedServer
import io.ktor.server.routing.routing
import io.ktor.server.websocket.DefaultWebSocketServerSession
import io.ktor.server.websocket.WebSockets
import io.ktor.server.websocket.pingPeriodMillis
import io.ktor.server.websocket.timeoutMillis
import io.ktor.server.websocket.webSocket
import io.ktor.websocket.Frame
import io.ktor.websocket.readBytes
import kotlinx.coroutines.*
import okhttp3.*
import okio.ByteString
import okio.ByteString.Companion.toByteString
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Transport #3. One phone is the HOST: it runs a Ktor WebSocket server on 0.0.0.0:8765 and (if the OS
 * allows) starts a Local-Only Hotspot (no SIM/data needed). Other phones join that Wi-Fi network; this
 * transport automatically connects to the Wi-Fi gateway IP (= the host) when it sees one.
 * The user may also switch on the normal system hotspot manually; the server works either way.
 */
class HotspotSocketTransport(private val ctx: Context, private val scope: CoroutineScope) : BaseTransport() {
    override val name = "hotspot"
    override val label = "Hotspot/LAN"

    private val port = 8765
    private val clientLink = "hotspot:host"
    private var server: ApplicationEngine? = null
    private val sessions = ConcurrentHashMap<String, DefaultWebSocketServerSession>()
    private val counter = AtomicInteger()
    private val http = OkHttpClient.Builder()
        .pingInterval(15, TimeUnit.SECONDS).connectTimeout(4, TimeUnit.SECONDS).build()
    @Volatile private var ws: WebSocket? = null
    @Volatile private var connecting = false
    @Volatile private var hostMode = false
    @Volatile private var info = ""
    @Volatile private var error: String? = null
    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var loop: Job? = null

    val hosting: Boolean get() = hostMode

    private fun publish() {
        _state.value = TransportState(
            active = hostMode || loop?.isActive == true,
            links = sessions.size + if (ws != null) 1 else 0,
            detail = if (hostMode) "Hosting. $info" else "Joining: looks for a host on the current Wi-Fi",
            error = error
        )
    }

    @Suppress("DEPRECATION")
    private fun gateway(): String? {
        val wm = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val gw = wm.dhcpInfo?.gateway ?: 0
        if (gw == 0) return null
        return "${gw and 0xff}.${gw shr 8 and 0xff}.${gw shr 16 and 0xff}.${gw shr 24 and 0xff}"
    }

    override fun start(localId: String, nick: String) {
        loop?.cancel()
        loop = scope.launch(Dispatchers.IO) {
            while (isActive) {
                if (!hostMode && ws == null && !connecting) gateway()?.let { connect(it) }
                delay(8_000)
            }
        }
        publish()
    }

    private fun connect(ip: String) {
        connecting = true
        http.newWebSocket(Request.Builder().url("ws://$ip:$port/chat").build(), object : WebSocketListener() {
            override fun onOpen(w: WebSocket, r: Response) {
                ws = w; connecting = false
                fire(LinkEvent.Up(clientLink, "LAN $ip")); publish()
            }
            override fun onMessage(w: WebSocket, bytes: ByteString) {
                fire(LinkEvent.Data(clientLink, bytes.toByteArray()))
            }
            override fun onClosed(w: WebSocket, code: Int, reason: String) = dropClient(w)
            override fun onFailure(w: WebSocket, t: Throwable, r: Response?) = dropClient(w)
        })
    }

    private fun dropClient(w: WebSocket) {
        connecting = false
        if (ws === w) { ws = null; fire(LinkEvent.Down(clientLink)) }
        publish()
    }

    fun setHost(on: Boolean) {
        if (on == hostMode) return
        hostMode = on
        error = null
        if (on) {
            ws?.close(1000, null)
            scope.launch(Dispatchers.IO) {
                try {
                    server = embeddedServer(CIO, port = port, host = "0.0.0.0") {
                        install(WebSockets) { pingPeriodMillis = 15_000; timeoutMillis = 30_000 }
                        routing {
                            webSocket("/chat") {
                                val id = "hotspot:c${counter.incrementAndGet()}"
                                sessions[id] = this
                                fire(LinkEvent.Up(id, "LAN client")); publish()
                                try {
                                    for (f in incoming) if (f is Frame.Binary) fire(LinkEvent.Data(id, f.readBytes()))
                                } finally {
                                    sessions.remove(id); fire(LinkEvent.Down(id)); publish()
                                }
                            }
                        }
                    }.also { it.start(wait = false) }
                    info = "Server on :$port."
                } catch (e: Exception) {
                    error = "Server failed: ${e.message}"
                }
                publish()
            }
            startLocalHotspot()
        } else {
            reservation?.close(); reservation = null
            server?.stop(300, 1_000); server = null
            sessions.keys.forEach { fire(LinkEvent.Down(it)) }
            sessions.clear()
            info = ""
        }
        publish()
    }

    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    private fun startLocalHotspot() {
        val wm = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        try {
            wm.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(r: WifiManager.LocalOnlyHotspotReservation) {
                    reservation = r
                    var ssid = "?"; var pass = ""
                    if (Build.VERSION.SDK_INT >= 30) {
                        r.softApConfiguration.let { ssid = it.ssid ?: "?"; pass = it.passphrase ?: "" }
                    } else {
                        r.wifiConfiguration?.let { ssid = it.SSID ?: "?"; pass = it.preSharedKey ?: "" }
                    }
                    info = "Other phones: join Wi-Fi \"$ssid\" / password \"$pass\", then open this app."
                    publish()
                }
                override fun onFailed(reason: Int) {
                    info = "Local hotspot failed (code $reason). Turn on the normal hotspot in Settings; the chat server is already running."
                    publish()
                }
            }, Handler(Looper.getMainLooper()))
        } catch (e: Exception) {
            info = "Couldn't start hotspot (${e.message}). Turn on the normal hotspot manually."
        }
    }

    override fun stop() {
        loop?.cancel()
        setHost(false)
        ws?.close(1000, null); ws = null
        _state.value = TransportState()
    }

    override fun send(linkId: String, bytes: ByteArray): Boolean {
        sessions[linkId]?.let { return it.outgoing.trySend(Frame.Binary(true, bytes)).isSuccess }
        if (linkId == clientLink) return ws?.send(bytes.toByteString()) ?: false
        return false
    }
}
