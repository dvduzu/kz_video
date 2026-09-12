package com.kzv.kz_video

import android.graphics.SurfaceTexture
import androidx.media3.exoplayer.ExoPlayer

object PlayerHolder {
    @Volatile
    var surfaceTexture: SurfaceTexture? = null

    @Volatile
    var headers: Map<String, String> = emptyMap()

    @Volatile
    var player: ExoPlayer? = null
}
