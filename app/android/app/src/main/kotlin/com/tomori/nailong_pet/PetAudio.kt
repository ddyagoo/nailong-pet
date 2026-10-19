package com.tomori.nailong_pet

import android.content.Context
import android.media.MediaPlayer
import java.io.File

/** 悬浮窗用的音频：笑声两段 + 点击「啵」。 */
class PetAudio(private val ctx: Context) {

    private var laugh: MediaPlayer? = null
    private var laughFull: MediaPlayer? = null
    private var tap: MediaPlayer? = null
    private var volume = 0.7f

    fun setVolume(v: Float) {
        volume = v.coerceIn(0f, 1f)
        laugh?.setVolume(volume, volume)
        laughFull?.setVolume(volume, volume)
        tap?.setVolume(volume, volume)
    }

    fun playLaugh(full: Boolean) {
        if (volume <= 0f) return
        try {
            val p = if (full) laughFull ?: create("flutter_assets/assets/audio/laugh_full.mp3")
                .also { laughFull = it }
            else laugh ?: create("flutter_assets/assets/audio/laugh.mp3").also { laugh = it }
            if (p.isPlaying) p.seekTo(0) else p.start()
            p.setVolume(volume, volume)
        } catch (_: Exception) {
        }
    }

    fun playTap() {
        if (volume <= 0f) return
        try {
            val p = tap ?: create("flutter_assets/assets/audio/tap.wav").also { tap = it }
            if (p.isPlaying) p.seekTo(0) else p.start()
            p.setVolume(volume, volume)
        } catch (_: Exception) {
        }
    }

    fun stop() {
        try {
            laugh?.pause()
            laughFull?.pause()
        } catch (_: Exception) {
        }
    }

    fun release() {
        listOf(laugh, laughFull, tap).forEach {
            try {
                it?.release()
            } catch (_: Exception) {
            }
        }
        laugh = null; laughFull = null; tap = null
    }

    private fun create(assetPath: String): MediaPlayer {
        val file = assetFile(ctx, assetPath)
        return MediaPlayer().apply {
            setDataSource(file.absolutePath)
            prepare()
            setVolume(volume, volume)
        }
    }

    companion object {
        /** MediaPlayer 需要真实文件路径，把 asset 复制到 cache 里一次。 */
        fun assetFile(ctx: Context, assetPath: String): File {
            val out = File(ctx.cacheDir, assetPath.substringAfterLast('/'))
            if (!out.exists() || out.length() == 0L) {
                ctx.assets.open(assetPath).use { input ->
                    out.outputStream().use { output -> input.copyTo(output) }
                }
            }
            return out
        }
    }
}
