package com.offgrid.chat.service

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.offgrid.chat.App
import com.offgrid.chat.MainActivity
import com.offgrid.chat.mesh.MeshEngine
import com.offgrid.chat.model.EMERGENCY_ID
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collect

/** Foreground service: keeps the mesh engine (and its radios) alive while the app is in the background. */
class MeshService : Service() {
    private lateinit var engine: MeshEngine
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var collecting = false
    private var online = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("mesh", "Mesh connection", NotificationManager.IMPORTANCE_LOW))
        nm.createNotificationChannel(NotificationChannel("msg", "Messages", NotificationManager.IMPORTANCE_DEFAULT))
        nm.createNotificationChannel(NotificationChannel("sos", "Emergency", NotificationManager.IMPORTANCE_HIGH))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ServiceCompat.startForeground(
            this, 1, ongoing(),
            if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE else 0
        )
        engine = (application as App).engine
        engine.start()
        if (!collecting) {
            collecting = true
            val nm = getSystemService(NotificationManager::class.java)
            scope.launch {
                engine.peers.collect { list ->
                    online = list.count { it.online }
                    nm.notify(1, ongoing())
                }
            }
            scope.launch {
                engine.incoming.collect { m ->
                    val sos = m.convId == EMERGENCY_ID
                    val n = NotificationCompat.Builder(this@MeshService, if (sos) "sos" else "msg")
                        .setSmallIcon(android.R.drawable.stat_notify_chat)
                        .setContentTitle((if (sos) "🚨 EMERGENCY from " else "") + engine.nickOf(m.senderId))
                        .setContentText(m.text)
                        .setAutoCancel(true)
                        .setPriority(if (sos) NotificationCompat.PRIORITY_MAX else NotificationCompat.PRIORITY_DEFAULT)
                        .setContentIntent(openApp())
                        .build()
                    nm.notify(m.id.hashCode(), n)
                }
            }
        }
        return START_STICKY
    }

    private fun openApp() = PendingIntent.getActivity(
        this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
    )

    private fun ongoing(): Notification = NotificationCompat.Builder(this, "mesh")
        .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
        .setContentTitle("OffGrid Chat is running")
        .setContentText("$online peer(s) reachable")
        .setOngoing(true)
        .setContentIntent(openApp())
        .build()

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
