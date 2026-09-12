package com.kzv.kz_video

import android.graphics.SurfaceTexture

object PlayerHolder {
    @Volatile
    var surfaceTexture: SurfaceTexture? = null

    @Volatile
    var headers: Map<String, String> = emptyMap()
}
