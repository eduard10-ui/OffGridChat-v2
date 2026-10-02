package com.offgrid.chat.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import com.offgrid.chat.App
import com.offgrid.chat.model.EMERGENCY_ID
import com.offgrid.chat.model.ROOM_ID
import kotlinx.coroutines.launch

class ChatViewModel(app: Application) : AndroidViewModel(app) {
    val engine = (app as App).engine
    val peers = engine.peers
    val transports = engine.transportInfo
    val nickname = engine.nickname

    fun messages(conv: String) = engine.messages(conv)
    fun setNick(n: String) = engine.setNickname(n)
    fun send(conv: String, text: String) {
        if (text.isBlank()) return
        engine.scope.launch {
            when (conv) {
                ROOM_ID -> engine.sendRoom(text.trim())
                EMERGENCY_ID -> engine.sendEmergency(text.trim())
                else -> engine.sendChat(conv, text.trim())
            }
        }
    }
    fun retry(id: String) { engine.scope.launch { engine.retry(id) } }
    fun verify(id: String) { engine.scope.launch { engine.setVerified(id) } }
    suspend fun verifyQr(s: String) = engine.verifyFromQr(s)
    fun setHost(on: Boolean) = engine.hotspot.setHost(on)
    val hosting get() = engine.hotspot.hosting
}
