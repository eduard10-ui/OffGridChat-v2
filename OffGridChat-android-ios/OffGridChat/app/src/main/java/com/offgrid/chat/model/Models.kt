package com.offgrid.chat.model

import kotlinx.serialization.Serializable

object MsgType {
    const val HELLO = "HELLO"
    const val CHAT = "CHAT"
    const val ROOM = "ROOM"
    const val EMERGENCY = "EMERGENCY"
    const val ACK = "ACK"
}

const val BROADCAST = "*"
const val ROOM_ID = "room"
const val EMERGENCY_ID = "emergency"

/** Wire format. `ttl` is NOT covered by the signature (relays decrement it). */
@Serializable
data class Envelope(
    val id: String,
    val senderId: String,
    val receiverId: String,
    val timestamp: Long,
    val ttl: Int,
    val type: String,
    val payload: String,
    val signature: String
)

@Serializable
data class HelloPayload(val nick: String, val sign: String, val agree: String)
