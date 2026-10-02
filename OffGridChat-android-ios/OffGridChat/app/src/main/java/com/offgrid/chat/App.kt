package com.offgrid.chat

import android.app.Application
import com.offgrid.chat.mesh.MeshEngine

class App : Application() {
    val engine: MeshEngine by lazy { MeshEngine(applicationContext) }
}
