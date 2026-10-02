package com.offgrid.chat.mesh

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.ParcelUuid
import com.offgrid.chat.crypto.hex
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Transport #4 (last resort). Every phone is both a GATT server (peripheral) and a scanner/GATT client
 * (central). The phone whose ID is smaller connects to the other, so each pair gets exactly one link.
 * Messages are fragmented into MTU-sized chunks (1 header byte: 1 = more follows, 0 = last).
 * Slow (a few KB/s at best) and only meant for short text.
 */
@SuppressLint("MissingPermission")
@Suppress("DEPRECATION")
class BleTransport(private val ctx: Context, private val scope: CoroutineScope) : BaseTransport() {
    override val name = "ble"
    override val label = "Bluetooth LE"

    companion object {
        val SERVICE: UUID = UUID.fromString("7d1f5b1e-3c1a-4f0a-9d5e-0f6f1b6a0c01")
        val CHAR: UUID = UUID.fromString("7d1f5b1e-3c1a-4f0a-9d5e-0f6f1b6a0c02")
        val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        const val MFG = 0xFFFF
    }

    private val mgr = ctx.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val adapter: BluetoothAdapter? = mgr.adapter
    private var server: BluetoothGattServer? = null
    private var serverChar: BluetoothGattCharacteristic? = null
    private var localHex = ""
    @Volatile private var running = false
    @Volatile private var error: String? = null

    private val links = ConcurrentHashMap<String, BleLink>()
    private val connecting = ConcurrentHashMap.newKeySet<String>()
    private val gatts = ConcurrentHashMap<String, BluetoothGatt>()
    private val mtus = ConcurrentHashMap<String, Int>()
    private val pending = ConcurrentHashMap<String, CompletableDeferred<Boolean>>()
    private val lastSig = ConcurrentHashMap<String, Long>()
    private val noMf = ConcurrentHashMap<String, Int>()
    private val notifyLock = Mutex()

    private fun publish() {
        _state.value = TransportState(
            active = running, links = links.size,
            detail = if (running) "Advertising + scanning (GATT)" else "Stopped",
            error = error
        )
    }

    private fun err(msg: String) { error = msg; publish() }

    private inner class BleLink(val id: String, val addr: String, val write: suspend (ByteArray) -> Boolean) {
        val q = Channel<ByteArray>(Channel.UNLIMITED)
        val rx = ByteArrayOutputStream()
        val job: Job = scope.launch {
            for (msg in q) {
                val max = ((mtus[addr] ?: 23) - 4).coerceAtLeast(19)
                var off = 0
                do {
                    val end = minOf(off + max, msg.size)
                    val chunk = ByteArray(end - off + 1)
                    chunk[0] = if (end < msg.size) 1 else 0
                    System.arraycopy(msg, off, chunk, 1, end - off)
                    if (!write(chunk)) break
                    off = end
                } while (off < msg.size)
            }
        }
        fun onChunk(b: ByteArray) {
            if (b.isEmpty()) return
            rx.write(b, 1, b.size - 1)
            if (b[0].toInt() == 0) { fire(LinkEvent.Data(id, rx.toByteArray())); rx.reset() }
        }
    }

    private suspend fun awaitWrite(addr: String, action: () -> Boolean): Boolean {
        val d = CompletableDeferred<Boolean>()
        pending[addr] = d
        if (!action()) { pending.remove(addr); return false }
        return withTimeoutOrNull(4_000) { d.await() } ?: false
    }

    private fun addLink(l: BleLink) {
        links[l.id] = l
        fire(LinkEvent.Up(l.id)); publish()
    }

    private fun removeLink(id: String) {
        links.remove(id)?.let { it.job.cancel(); it.q.close(); fire(LinkEvent.Down(id)); publish() }
    }

    // ---------- central role (we connect out) ----------
    private inner class CentralCb(val addr: String) : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                gatts[addr] = g
                g.requestMtu(247)
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                g.close(); gatts.remove(addr); mtus.remove(addr); connecting.remove(addr)
                removeLink("ble:$addr")
            }
        }
        override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) {
            mtus[addr] = mtu; g.discoverServices()
        }
        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            val ch = g.getService(SERVICE)?.getCharacteristic(CHAR)
            if (ch == null) { g.disconnect(); return }
            g.setCharacteristicNotification(ch, true)
            val d = ch.getDescriptor(CCCD)
            d.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            g.writeDescriptor(d)
        }
        override fun onDescriptorWrite(g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int) {
            val ch = d.characteristic
            if (status != BluetoothGatt.GATT_SUCCESS) { g.disconnect(); return }
            addLink(BleLink("ble:$addr", addr) { chunk ->
                awaitWrite(addr) {
                    ch.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                    ch.value = chunk
                    g.writeCharacteristic(ch)
                }
            })
            connecting.remove(addr)
        }
        override fun onCharacteristicChanged(g: BluetoothGatt, ch: BluetoothGattCharacteristic) {
            links["ble:$addr"]?.onChunk(ch.value ?: return)
        }
        override fun onCharacteristicWrite(g: BluetoothGatt, ch: BluetoothGattCharacteristic, status: Int) {
            pending[addr]?.complete(status == BluetoothGatt.GATT_SUCCESS)
        }
    }

    // ---------- peripheral role (others connect to us) ----------
    private val serverCb = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService) { startAdvertising() }
        override fun onConnectionStateChange(dev: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                mtus.remove(dev.address); removeLink("ble:${dev.address}")
            }
        }
        override fun onMtuChanged(dev: BluetoothDevice, mtu: Int) { mtus[dev.address] = mtu }
        override fun onDescriptorWriteRequest(
            dev: BluetoothDevice, reqId: Int, d: BluetoothGattDescriptor,
            prepared: Boolean, respond: Boolean, offset: Int, value: ByteArray
        ) {
            if (respond) server?.sendResponse(dev, reqId, BluetoothGatt.GATT_SUCCESS, 0, null)
            if (d.uuid == CCCD && value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) {
                val addr = dev.address
                addLink(BleLink("ble:$addr", addr) { chunk ->
                    notifyLock.withLock {
                        awaitWrite(addr) {
                            val c = serverChar ?: return@awaitWrite false
                            c.value = chunk
                            server?.notifyCharacteristicChanged(dev, c, false) ?: false
                        }
                    }
                })
            }
        }
        override fun onCharacteristicWriteRequest(
            dev: BluetoothDevice, reqId: Int, c: BluetoothGattCharacteristic,
            prepared: Boolean, respond: Boolean, offset: Int, value: ByteArray
        ) {
            if (respond) server?.sendResponse(dev, reqId, BluetoothGatt.GATT_SUCCESS, offset, value)
            links["ble:${dev.address}"]?.onChunk(value)
        }
        override fun onNotificationSent(dev: BluetoothDevice, status: Int) {
            pending[dev.address]?.complete(status == BluetoothGatt.GATT_SUCCESS)
        }
    }

    private val advCb = object : AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) { err("BLE advertising failed ($errorCode)") }
    }

    private fun startAdvertising() {
        val adv = adapter?.bluetoothLeAdvertiser ?: run { err("BLE advertising not supported"); return }
        val idBytes = localHex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        adv.startAdvertising(
            AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setConnectable(true).setTimeout(0).setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH).build(),
            AdvertiseData.Builder().setIncludeDeviceName(false).addServiceUuid(ParcelUuid(SERVICE)).build(),
            AdvertiseData.Builder().setIncludeDeviceName(false).addManufacturerData(MFG, idBytes).build(),
            advCb
        )
    }

    private val scanCb = object : ScanCallback() {
        override fun onScanResult(type: Int, r: ScanResult) {
            val addr = r.device.address
            val id = "ble:$addr"
            if (links.containsKey(id)) {
                val now = System.currentTimeMillis()
                if (now - (lastSig[id] ?: 0L) > 3_000) {
                    lastSig[id] = now; fire(LinkEvent.Signal(id, "${r.rssi} dBm"))
                }
                return
            }
            val mf = r.scanRecord?.getManufacturerSpecificData(MFG)
            val connectNow = if (mf != null && mf.size >= 8) {
                localHex < mf.copyOf(8).hex()              // Android peer: smaller id connects
            } else {
                // iPhones cannot advertise manufacturer data. Treat a device that repeatedly shows
                // our service UUID without it as an iPhone and connect (we always initiate to iOS).
                (noMf.merge(addr, 1) { a, b -> a + b } ?: 0) >= 4
            }
            if (connectNow && connecting.add(addr)) {
                r.device.connectGatt(ctx, false, CentralCb(addr), BluetoothDevice.TRANSPORT_LE)
            }
        }
        override fun onScanFailed(errorCode: Int) { err("BLE scan failed ($errorCode)") }
    }

    override fun start(localId: String, nick: String) {
        if (running) return
        val a = adapter
        if (a == null || !ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            err("Bluetooth LE not supported"); return
        }
        if (!a.isEnabled) { err("Bluetooth is off"); return }
        running = true; error = null
        localHex = localId.take(16)
        try {
            server = mgr.openGattServer(ctx, serverCb)
            val ch = BluetoothGattCharacteristic(
                CHAR,
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_WRITE
            )
            ch.addDescriptor(
                BluetoothGattDescriptor(
                    CCCD, BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
                )
            )
            val svc = BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY)
            svc.addCharacteristic(ch)
            serverChar = ch
            server?.addService(svc)  // advertising starts in onServiceAdded
            a.bluetoothLeScanner?.startScan(
                listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE)).build()),
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build(),
                scanCb
            )
        } catch (e: Exception) {
            err("BLE start failed: ${e.message}")
            stop()
            return
        }
        publish()
    }

    override fun stop() {
        running = false
        try { adapter?.bluetoothLeScanner?.stopScan(scanCb) } catch (_: Exception) {}
        try { adapter?.bluetoothLeAdvertiser?.stopAdvertising(advCb) } catch (_: Exception) {}
        gatts.values.forEach { try { it.disconnect(); it.close() } catch (_: Exception) {} }
        gatts.clear(); connecting.clear(); mtus.clear()
        links.keys.toList().forEach { removeLink(it) }
        try { server?.close() } catch (_: Exception) {}
        server = null
        publish()
    }

    override fun send(linkId: String, bytes: ByteArray): Boolean =
        links[linkId]?.q?.trySend(bytes)?.isSuccess ?: false
}
