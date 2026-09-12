package com.kzv.kz_video

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.MoreExecutors
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

@OptIn(UnstableApi::class)
class ExoPlayerController(context: Context, textureEntry: TextureRegistry.SurfaceTextureEntry) {
    val textureId: Long = textureEntry.id()
    private var controller: MediaController? = null
    private var pendingItem: MediaItem? = null
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var ticking = false
    private var videoWidth = 0
    private var videoHeight = 0

    private val listener = object : Player.Listener {
        override fun onVideoSizeChanged(videoSize: VideoSize) {
            videoWidth = videoSize.width
            videoHeight = videoSize.height
            emitState()
        }

        override fun onPlayerError(error: PlaybackException) {
            sink?.success(mapOf("event" to "error", "message" to (error.message ?: "playback error")))
        }

        override fun onPlaybackStateChanged(state: Int) {
            emitState()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emitState()
        }
    }

    private val ticker = object : Runnable {
        override fun run() {
            emitState()
            if (ticking) handler.postDelayed(this, 250)
        }
    }

    init {
        PlayerHolder.surfaceTexture = textureEntry.surfaceTexture()
        val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
        val future = MediaController.Builder(context, token).buildAsync()
        future.addListener({
            try {
                controller = future.get()
                controller?.addListener(listener)
                pendingItem?.let { item ->
                    pendingItem = null
                    applyItem(item)
                }
            } catch (_: Exception) {
            }
        }, MoreExecutors.directExecutor())
    }

    fun attachSink(s: EventChannel.EventSink?) {
        sink = s
        if (s == null) {
            ticking = false
            handler.removeCallbacks(ticker)
        } else if (!ticking) {
            ticking = true
            handler.post(ticker)
        }
    }

    private fun emitState() {
        val c = controller ?: return
        val pos = c.currentPosition
        val dur = c.duration
        sink?.success(
            mapOf(
                "event" to "state",
                "position" to pos,
                "duration" to if (dur < 0) 0L else dur,
                "playing" to c.isPlaying,
                "buffering" to (c.playbackState == Player.STATE_BUFFERING),
                "ended" to (c.playbackState == Player.STATE_ENDED),
                "videoWidth" to videoWidth,
                "videoHeight" to videoHeight,
            )
        )
    }

    private fun applyItem(item: MediaItem) {
        val c = controller ?: return
        c.setMediaItem(item)
        c.prepare()
        c.playWhenReady = true
    }

    fun setUrl(url: String, headers: Map<String, String>, title: String?, artist: String?, artwork: String?) {
        PlayerHolder.headers = headers
        val metadata = MediaMetadata.Builder()
            .setTitle(title)
            .setArtist(artist)
            .apply { artwork?.takeIf { it.isNotEmpty() }?.let { setArtworkUri(Uri.parse(it)) } }
            .build()
        val item = MediaItem.Builder()
            .setUri(Uri.parse(url))
            .setMediaMetadata(metadata)
            .build()
        if (controller == null) {
            pendingItem = item
        } else {
            applyItem(item)
        }
    }

    fun play() { controller?.play() }
    fun pause() { controller?.pause() }
    fun stop() { controller?.stop() }
    fun seek(ms: Long) { controller?.seekTo(ms) }
    fun setRate(rate: Float) { controller?.setPlaybackSpeed(rate) }

    fun release() {
        ticking = false
        handler.removeCallbacks(ticker)
        controller?.removeListener(listener)
        controller = null
    }
}

class ExoPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var controller: ExoPlayerController? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null

    companion object {
        private const val METHOD = "kz/exoplayer"
        private const val EVENTS = "kz/exoplayer/events"
        fun registerWith(engine: FlutterEngine) {
            engine.plugins.add(ExoPlayerPlugin())
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val entry = binding.textureRegistry.createSurfaceTexture()
        textureEntry = entry
        val c = ExoPlayerController(binding.applicationContext, entry)
        controller = c
        MethodChannel(binding.binaryMessenger, METHOD).setMethodCallHandler(this)
        EventChannel(binding.binaryMessenger, EVENTS).setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        controller?.release()
        controller = null
        textureEntry?.release()
        textureEntry = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val c = controller
        if (c == null) {
            result.error("no_controller", "player not attached", null)
            return
        }
        when (call.method) {
            "textureId" -> result.success(c.textureId)
            "setUrl" -> {
                val url = call.argument<String>("url") ?: ""
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                c.setUrl(url, headers, call.argument<String>("title"), call.argument<String>("artist"), call.argument<String>("artwork"))
                result.success(null)
            }
            "play" -> { c.play(); result.success(null) }
            "pause" -> { c.pause(); result.success(null) }
            "stop" -> { c.stop(); result.success(null) }
            "seek" -> { c.seek(call.argument<Number>("position")?.toLong() ?: 0L); result.success(null) }
            "setRate" -> { c.setRate(call.argument<Number>("rate")?.toFloat() ?: 1f); result.success(null) }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        controller?.attachSink(events)
    }

    override fun onCancel(arguments: Any?) {
        controller?.attachSink(null)
    }
}
