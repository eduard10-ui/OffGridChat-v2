package com.offgrid.chat

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import com.offgrid.chat.service.MeshService
import com.offgrid.chat.ui.Actions
import com.offgrid.chat.ui.AppRoot
import com.offgrid.chat.ui.ChatViewModel
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val vm: ChatViewModel by viewModels()
    private var missing by mutableStateOf<List<String>>(emptyList())
    private var btOn by mutableStateOf(true)

    private val permLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { refresh() }
    private val btLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { refresh() }
    private val scanLauncher = registerForActivityResult(ScanContract()) { r ->
        val c = r.contents ?: return@registerForActivityResult
        lifecycleScope.launch {
            val n = vm.verifyQr(c)
            Toast.makeText(this@MainActivity,
                if (n != null) "Verified $n" else "Not a valid OffGrid QR code", Toast.LENGTH_LONG).show()
        }
    }

    private val actions by lazy {
        Actions(
            requestPerms = { permLauncher.launch(required().toTypedArray()) },
            enableBt = { btLauncher.launch(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)) },
            scanQr = {
                scanLauncher.launch(ScanOptions().setPrompt("Scan your friend's OffGrid QR")
                    .setBeepEnabled(false).setOrientationLocked(false)
                    .setDesiredBarcodeFormats(ScanOptions.QR_CODE))
            },
            battery = {
                startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName")))
            },
            startMesh = { startMesh() },
            stopMesh = { stopService(Intent(this, MeshService::class.java)); vm.engine.stop() }
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        refresh()
        setContent { AppRoot(vm, missing, btOn, actions) }
    }

    override fun onResume() { super.onResume(); refresh() }

    private fun required(): List<String> = buildList {
        if (Build.VERSION.SDK_INT >= 31) {
            add(Manifest.permission.BLUETOOTH_SCAN)
            add(Manifest.permission.BLUETOOTH_ADVERTISE)
            add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            add(Manifest.permission.NEARBY_WIFI_DEVICES)
            add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (Build.VERSION.SDK_INT <= 32) add(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    private fun refresh() {
        missing = required().filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        btOn = getSystemService(BluetoothManager::class.java)?.adapter?.isEnabled ?: false
        if (missing.none { it != Manifest.permission.POST_NOTIFICATIONS }) startMesh()
    }

    private fun startMesh() {
        if (vm.nickname.value.isNotBlank())
            ContextCompat.startForegroundService(this, Intent(this, MeshService::class.java))
    }
}
