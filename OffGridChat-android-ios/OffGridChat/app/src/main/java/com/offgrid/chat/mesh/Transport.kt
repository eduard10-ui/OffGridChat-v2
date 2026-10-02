package com.offgrid.chat.mesh

import kotlinx.coroutines.flow.*

sealed interface LinkEvent {
    data class Up(val linkId: String, val signal: String = "") : LinkEvent
    data class Down(val linkId: String) : LinkEvent
    data class Signal(val linkId: String, val text: String) : LinkEvent
    class Data(val linkId: String, val bytes: ByteArray) : LinkEvent
}

data class TransportState(
    val active: Boolean = false,
    val links: Int = 0,
    val detail: String = "Stopped",
    val error: String? = null
)

/** A transport moves opaque byte arrays over "links" (one per directly connected neighbour). */
interface Transport {
    val name: String
    val label: String
    val state: StateFlow<TransportState>
    val events: SharedFlow<LinkEvent>
    fun start(localId: String, nick: String)
    fun stop()
    fun send(linkId: String, bytes: ByteArray): Boolean
}

abstract class BaseTransport : Transport {
    protected val _state = MutableStateFlow(TransportState())
    protected val _events = MutableSharedFlow<LinkEvent>(extraBufferCapacity = 512)
    override val state: StateFlow<TransportState> = _state.asStateFlow()
    override val events: SharedFlow<LinkEvent> = _events.asSharedFlow()
    protected fun fire(e: LinkEvent) { _events.tryEmit(e) }
}
