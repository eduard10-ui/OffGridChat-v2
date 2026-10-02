package com.offgrid.chat.mesh

import android.content.Context
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap

/**
 * Transport #1. Nearby Connections with P2P_CLUSTER (M-to-N). Google's library picks and upgrades
 * between BLE, Bluetooth Classic and Wi-Fi (Direct/hotspot) by itself; no internet is required.
 * Requires Google Play services on the phone.
 */
class NearbyTransport(private val ctx: Context, private val scope: CoroutineScope) : BaseTransport() {
    override val name = "nearby"
    override val label = "Nearby"

    private val client = Nearby.getConnectionsClient(ctx)
    private val serviceId = "com.offgrid.chat.v1"
    private val strategy = Strategy.P2P_CLUSTER
    private val connected = ConcurrentHashMap.newKeySet<String>()
    private val found = ConcurrentHashMap<String, String>() // endpointId -> remote userId
    @Volatile private var localId = ""
    @Volatile private var advOk = false
    @Volatile private var discOk = false
    @Volatile private var error: String? = null

    private fun publish() {
        _state.value = TransportState(
            active = advOk || discOk,
            links = connected.size,
            detail = when {
                advOk && discOk -> "Advertising + discovering"
                advOk || discOk -> "Partially active"
                else -> "Starting…"
            },
            error = error
        )
    }

    private val payloadCb = object : PayloadCallback() {
        override fun onPayloadReceived(id: String, p: Payload) {
            p.asBytes()?.let { fire(LinkEvent.Data("nearby:$id", it)) }
        }
        override fun onPayloadTransferUpdate(id: String, u: PayloadTransferUpdate) {}
    }

    private val lifecycle = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(id: String, info: ConnectionInfo) {
            // Auto-accept; real authentication happens at app level (Ed25519 signatures + fingerprints).
            client.acceptConnection(id, payloadCb)
        }
        override fun onConnectionResult(id: String, result: ConnectionResolution) {
            if (result.status.isSuccess) {
                connected.add(id)
                fire(LinkEvent.Up("nearby:$id"))
                publish()
            } else retryLater(id)
        }
        override fun onDisconnected(id: String) {
            connected.remove(id)
            fire(LinkEvent.Down("nearby:$id"))
            publish()
            retryLater(id)
        }
        override fun onBandwidthChanged(id: String, info: BandwidthInfo) {
            val q = when (info.quality) {
                BandwidthInfo.Quality.HIGH -> "link: high"
                BandwidthInfo.Quality.MEDIUM -> "link: medium"
                else -> "link: low"
            }
            fire(LinkEvent.Signal("nearby:$id", q))
        }
    }

    private val discovery = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(id: String, info: DiscoveredEndpointInfo) {
            found[id] = info.endpointName
            maybeConnect(id)
        }
        override fun onEndpointLost(id: String) { found.remove(id) }
    }

    /** Both phones advertise+discover; only the one with the smaller ID initiates (avoids collisions). */
    private fun maybeConnect(id: String) {
        val remote = found[id] ?: return
        if (connected.contains(id) || localId >= remote) return
        client.requestConnection(localId, id, lifecycle).addOnFailureListener { e ->
            val code = (e as? ApiException)?.statusCode
            if (code != ConnectionsStatusCodes.STATUS_ALREADY_CONNECTED_TO_ENDPOINT) retryLater(id)
        }
    }

    private fun retryLater(id: String) {
        scope.launch { delay(5_000); maybeConnect(id) }
    }

    private fun fail(prefix: String, e: Exception) {
        error = "$prefix: ${e.message}"
        publish()
    }

    override fun start(localId: String, nick: String) {
        this.localId = localId
        error = null
        client.startAdvertising(
            localId, serviceId, lifecycle,
            AdvertisingOptions.Builder().setStrategy(strategy).build()
        ).addOnSuccessListener { advOk = true; publish() }
            .addOnFailureListener {
                if ((it as? ApiException)?.statusCode == ConnectionsStatusCodes.STATUS_ALREADY_ADVERTISING) {
                    advOk = true; publish()
                } else fail("Advertising failed", it)
            }
        client.startDiscovery(
            serviceId, discovery,
            DiscoveryOptions.Builder().setStrategy(strategy).build()
        ).addOnSuccessListener { discOk = true; publish() }
            .addOnFailureListener {
                if ((it as? ApiException)?.statusCode == ConnectionsStatusCodes.STATUS_ALREADY_DISCOVERING) {
                    discOk = true; publish()
                } else fail("Discovery failed", it)
            }
    }

    override fun stop() {
        client.stopAdvertising()
        client.stopDiscovery()
        client.stopAllEndpoints()
        connected.forEach { fire(LinkEvent.Down("nearby:$it")) }
        connected.clear(); found.clear()
        advOk = false; discOk = false
        _state.value = TransportState()
    }

    override fun send(linkId: String, bytes: ByteArray): Boolean {
        val ep = linkId.removePrefix("nearby:")
        if (!connected.contains(ep)) return false
        client.sendPayload(ep, Payload.fromBytes(bytes))
        return true
    }
}
