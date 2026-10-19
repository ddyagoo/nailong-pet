package com.tomori.nailong_pet

import android.content.Context
import android.content.SharedPreferences

/**
 * Flutter 的 shared_preferences 在 Android 上写的是 "FlutterSharedPreferences"，
 * double 会被存成带前缀的字符串（不是 float），所以这里要按同样的格式读。
 */
object Prefs {
    private const val NAME = "FlutterSharedPreferences"
    private const val DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

    fun sp(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    private fun readDouble(sp: SharedPreferences, key: String, def: Double): Double {
        val raw = sp.getString(key, null) ?: return def
        if (!raw.startsWith(DOUBLE_PREFIX)) return def
        return raw.removePrefix(DOUBLE_PREFIX).toDoubleOrNull() ?: def
    }

    fun volume(ctx: Context): Float {
        val sp = sp(ctx)
        if (sp.getBoolean("flutter.muted", false)) return 0f
        return readDouble(sp, "flutter.volume", 0.7).toFloat().coerceIn(0f, 1f)
    }

    fun scale(ctx: Context): Float =
        readDouble(sp(ctx), "flutter.pet_scale", 1.0).toFloat().coerceIn(0.6f, 1.6f)

    fun laughOn(ctx: Context): Boolean = sp(ctx).getBoolean("flutter.laugh_on", true)

    fun hapticOn(ctx: Context): Boolean = sp(ctx).getBoolean("flutter.haptic", true)

    /** 静置多久会笑：在这个区间里随机取一秒（单位：秒） */
    fun idleMin(ctx: Context): Int =
        readDouble(sp(ctx), "flutter.idle_min", 30.0).toInt().coerceIn(5, 600)

    fun idleMax(ctx: Context): Int =
        readDouble(sp(ctx), "flutter.idle_max", 90.0).toInt().coerceIn(5, 600)

    // 悬浮窗自己的位置（与 App 内桌宠的位置分开存）
    fun overlayPos(ctx: Context): Pair<Int, Int>? {
        val sp = sp(ctx)
        if (!sp.contains("overlay.x")) return null
        return sp.getInt("overlay.x", 0) to sp.getInt("overlay.y", 0)
    }

    fun saveOverlayPos(ctx: Context, x: Int, y: Int) {
        sp(ctx).edit().putInt("overlay.x", x).putInt("overlay.y", y).apply()
    }
}
