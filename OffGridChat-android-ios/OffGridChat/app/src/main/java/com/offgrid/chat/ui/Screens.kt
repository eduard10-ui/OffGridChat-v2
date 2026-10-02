package com.offgrid.chat.ui

import android.Manifest
import android.graphics.Bitmap
import android.graphics.Color as AColor
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import com.offgrid.chat.crypto.Crypto
import com.offgrid.chat.data.MessageEntity
import com.offgrid.chat.mesh.TransportInfo
import com.offgrid.chat.model.EMERGENCY_ID
import com.offgrid.chat.model.ROOM_ID

class Actions(
    val requestPerms: () -> Unit, val enableBt: () -> Unit, val scanQr: () -> Unit,
    val battery: () -> Unit, val startMesh: () -> Unit, val stopMesh: () -> Unit
)

sealed interface Screen {
    data object Peers : Screen
    data class Chat(val id: String, val title: String) : Screen
    data object Identity : Screen
    data object Radios : Screen
}

@Composable
fun AppRoot(vm: ChatViewModel, missing: List<String>, btOn: Boolean, act: Actions) {
    MaterialTheme {
        Surface(Modifier.fillMaxSize()) {
            val nick by vm.nickname.collectAsState()
            when {
                missing.any { it != Manifest.permission.POST_NOTIFICATIONS } -> PermissionScreen(act.requestPerms)
                nick.isBlank() -> NicknameScreen { vm.setNick(it); act.startMesh() }
                else -> MainNav(vm, btOn, act)
            }
        }
    }
}

@Composable
private fun PermissionScreen(onGrant: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
        Text("Permissions needed", style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(12.dp))
        Text(
            "OffGrid Chat uses Bluetooth and nearby Wi-Fi to find phones around you " +
                "(plus location on Android 12 and older, which Android requires for scanning). " +
                "Nothing is ever sent to the internet."
        )
        Spacer(Modifier.height(16.dp))
        Button(onClick = onGrant) { Text("Grant permissions") }
    }
}

@Composable
private fun NicknameScreen(onDone: (String) -> Unit) {
    var n by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
        Text("Choose a nickname", style = MaterialTheme.typography.headlineSmall)
        Text("No account. Others see this name; your cryptographic ID is what really identifies you.")
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(n, { n = it.take(32) }, singleLine = true, label = { Text("Nickname") })
        Spacer(Modifier.height(12.dp))
        Button(onClick = { onDone(n) }, enabled = n.isNotBlank()) { Text("Start") }
    }
}

@Composable
private fun MainNav(vm: ChatViewModel, btOn: Boolean, act: Actions) {
    var screen by remember { mutableStateOf<Screen>(Screen.Peers) }
    BackHandler(screen != Screen.Peers) { screen = Screen.Peers }
    when (val s = screen) {
        Screen.Peers -> PeersScreen(vm, btOn, act) { screen = it }
        is Screen.Chat -> ChatScreen(vm, s) { screen = Screen.Peers }
        Screen.Identity -> IdentityScreen(vm, act) { screen = Screen.Peers }
        Screen.Radios -> RadiosScreen(vm, act) { screen = Screen.Peers }
    }
}

@Composable
private fun Banner(text: String, action: String?, onAction: () -> Unit) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(text, Modifier.weight(1f))
            if (action != null) TextButton(onAction) { Text(action) }
        }
    }
}

@Composable
private fun RowCard(title: String, sub: String, danger: Boolean = false, onClick: () -> Unit) {
    Card(
        Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = if (danger) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(title, fontWeight = FontWeight.Bold)
            Text(sub, style = MaterialTheme.typography.bodySmall)
        }
    }
}

private fun activeSummary(ts: List<TransportInfo>) =
    "Active transports: " + ts.joinToString(" · ") { "${it.label} ${if (it.state.active) "${it.state.links} link(s)" else "off"}" }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PeersScreen(vm: ChatViewModel, btOn: Boolean, act: Actions, go: (Screen) -> Unit) {
    val peers by vm.peers.collectAsState()
    val ts by vm.transports.collectAsState()
    Scaffold(topBar = {
        TopAppBar(title = { Text("OffGrid Chat") }, actions = {
            TextButton({ go(Screen.Identity) }) { Text("Identity") }
            TextButton({ go(Screen.Radios) }) { Text("Radios") }
        })
    }) { pad ->
        LazyColumn(
            Modifier.padding(pad).fillMaxSize(),
            contentPadding = PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (!btOn) item { Banner("Bluetooth is off. Nearby discovery needs it.", "Turn on", act.enableBt) }
            ts.filter { it.state.error != null }.forEach { t ->
                item(key = "err-${t.name}") { Banner("${t.label}: ${t.state.error}", null) {} }
            }
            item { Text(activeSummary(ts), style = MaterialTheme.typography.labelLarge) }
            item { RowCard("Group room", "Everyone in the mesh (signed, not encrypted)") { go(Screen.Chat(ROOM_ID, "Group room")) } }
            item {
                RowCard("🚨 Emergency broadcast", "Alerts every device that can be reached", danger = true) {
                    go(Screen.Chat(EMERGENCY_ID, "Emergency"))
                }
            }
            item { Text("People", style = MaterialTheme.typography.titleMedium) }
            if (peers.isEmpty()) item {
                Text("Nobody found yet. Keep the app open on both phones, within a few metres, Bluetooth on.")
            }
            items(peers, key = { it.id }) { p ->
                RowCard(
                    (if (p.online) "● " else "○ ") + p.nick + if (p.verified) "  ✓ verified" else "",
                    if (p.online) "${p.hops} hop(s) · ${p.via} ${p.signal}".trim() else "offline · messages will queue",
                ) { go(Screen.Chat(p.id, p.nick)) }
            }
        }
    }
}

private fun statusLabel(s: String) = when (s) {
    "QUEUED" -> "⏳ queued"
    "SENT" -> "✓ sent"
    "DELIVERED" -> "✓✓ delivered"
    "FAILED" -> "✗ failed · tap to retry"
    else -> ""
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChatScreen(vm: ChatViewModel, s: Screen.Chat, back: () -> Unit) {
    val flow = remember(s.id) { vm.messages(s.id) }
    val msgs by flow.collectAsState(emptyList())
    val peers by vm.peers.collectAsState()
    val peer = peers.find { it.id == s.id }
    val isGroup = s.id == ROOM_ID || s.id == EMERGENCY_ID
    var text by remember { mutableStateOf("") }
    val list = rememberLazyListState()
    LaunchedEffect(msgs.size) { if (msgs.isNotEmpty()) list.animateScrollToItem(msgs.size - 1) }

    Scaffold(topBar = {
        TopAppBar(title = { Text(s.title) }, navigationIcon = { TextButton(back) { Text("‹ Back") } })
    }) { pad ->
        Column(Modifier.padding(pad).fillMaxSize()) {
            if (peer != null && !peer.verified) {
                Banner("Not verified. Compare ${peer.fingerprint.take(19)}… with your friend's Identity screen, or scan their QR.",
                    "Mark verified") { vm.verify(peer.id) }
            }
            if (s.id == EMERGENCY_ID) Banner("Emergency messages go to everyone reachable, are signed but not encrypted.", null) {}
            LazyColumn(Modifier.weight(1f).fillMaxWidth(), state = list,
                contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                items(msgs, key = { it.id }) { m ->
                    Bubble(m, peers.find { it.id == m.senderId }?.nick ?: m.senderId.take(6), isGroup) { vm.retry(m.id) }
                }
            }
            Row(Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(text, { text = it }, Modifier.weight(1f), placeholder = { Text("Message") })
                Spacer(Modifier.width(8.dp))
                Button(
                    onClick = { vm.send(s.id, text); text = "" },
                    colors = if (s.id == EMERGENCY_ID) ButtonDefaults.buttonColors(containerColor = Color.Red) else ButtonDefaults.buttonColors()
                ) { Text(if (s.id == EMERGENCY_ID) "SOS" else "Send") }
            }
        }
    }
}

@Composable
private fun Bubble(m: MessageEntity, who: String, group: Boolean, onRetry: () -> Unit) {
    val mine = m.outgoing
    Column(Modifier.fillMaxWidth(), horizontalAlignment = if (mine) Alignment.End else Alignment.Start) {
        Surface(
            color = if (mine) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
            shape = MaterialTheme.shapes.medium,
            modifier = if (m.status == "FAILED") Modifier.clickable { onRetry() } else Modifier
        ) {
            Column(Modifier.padding(10.dp)) {
                if (group && !mine) Text(who, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                Text(m.text)
                if (mine) Text(statusLabel(m.status), style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

private fun qrBitmap(text: String, size: Int = 600): Bitmap {
    val m = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size)
    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.RGB_565)
    for (x in 0 until size) for (y in 0 until size) bmp.setPixel(x, y, if (m.get(x, y)) AColor.BLACK else AColor.WHITE)
    return bmp
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun IdentityScreen(vm: ChatViewModel, act: Actions, back: () -> Unit) {
    val peers by vm.peers.collectAsState()
    val qr = remember { qrBitmap(vm.engine.myQr()) }
    Scaffold(topBar = {
        TopAppBar(title = { Text("My identity") }, navigationIcon = { TextButton(back) { Text("‹ Back") } })
    }) { pad ->
        LazyColumn(Modifier.padding(pad).fillMaxSize(), contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { Text("Your fingerprint", style = MaterialTheme.typography.titleMedium) }
            item { Text(Crypto.fingerprint(vm.engine.me)) }
            item { Image(qr.asImageBitmap(), "My QR code", Modifier.size(240.dp)) }
            item { Text("Let a friend scan this QR in person. That proves the name and keys belong together.") }
            item { Button(onClick = act.scanQr) { Text("Scan a friend's QR") } }
            item { Text("Known people", style = MaterialTheme.typography.titleMedium) }
            items(peers, key = { it.id }) { p ->
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp)) {
                        Text(p.nick + if (p.verified) "  ✓ verified" else "  (unverified)", fontWeight = FontWeight.Bold)
                        Text(p.fingerprint, style = MaterialTheme.typography.bodySmall)
                        if (!p.verified) TextButton({ vm.verify(p.id) }) { Text("Fingerprints match: mark verified") }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RadiosScreen(vm: ChatViewModel, act: Actions, back: () -> Unit) {
    val ts by vm.transports.collectAsState()
    var host by remember { mutableStateOf(vm.hosting) }
    val bleAlways by vm.engine.bleAlways.collectAsState()
    Scaffold(topBar = {
        TopAppBar(title = { Text("Radios") }, navigationIcon = { TextButton(back) { Text("‹ Back") } })
    }) { pad ->
        LazyColumn(Modifier.padding(pad).fillMaxSize(), contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(ts, key = { it.name }) { t ->
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp)) {
                        Text("${t.label}: ${if (t.state.active) "on" else "off"} · ${t.state.links} link(s)", fontWeight = FontWeight.Bold)
                        Text(t.state.detail, style = MaterialTheme.typography.bodySmall)
                        t.state.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                    }
                }
            }
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Switch(host, { host = it; vm.setHost(it) })
                    Spacer(Modifier.width(8.dp))
                    Text("Host a hotspot chat server (use when Nearby can't connect)")
                }
            }
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Switch(bleAlways, { vm.engine.setBleAlways(it) })
                    Spacer(Modifier.width(8.dp))
                    Text("Keep Bluetooth LE always on (required to chat with iPhones)")
                }
            }
            item { Text("Hotspot mode: turn this on for ONE phone; the others just join its Wi-Fi network (no internet needed). Credentials appear in the Hotspot/LAN card above.", style = MaterialTheme.typography.bodySmall) }
            item { Button(onClick = act.battery) { Text("Allow background running (battery)") } }
            item { OutlinedButton(onClick = act.stopMesh) { Text("Stop OffGrid Chat") } }
        }
    }
}
