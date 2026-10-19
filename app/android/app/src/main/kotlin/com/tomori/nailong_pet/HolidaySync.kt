package com.tomori.nailong_pet

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.Calendar

/**
 * 法定节假日 / 调休的在线同步。
 *
 * 数据源：NateScarlet/holiday-cn（每年国务院公告后更新，带 gov.cn 原文链接），
 * 直接读 GitHub raw，不需要 key。缓存到 filesDir，7 天同步一次；
 * 同步失败就继续用内置的 calendar.json，不影响使用。
 */
object HolidaySync {

    private const val BASE = "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/%d.json"
    private const val PREF_LAST = "holiday.lastSync"
    private const val INTERVAL = 7L * 24 * 3600 * 1000
    private const val TIMEOUT = 8000

    data class Info(val name: String, val off: Boolean)

    private val cache = HashMap<Int, Map<String, Info>>()

    fun lookup(ctx: Context, dateKey: String): Info? {
        val year = dateKey.take(4).toIntOrNull() ?: return null
        val map = cache[year] ?: loadYear(ctx, year)?.also { cache[year] = it } ?: return null
        return map[dateKey]
    }

    /** 7 天内同步过就跳过；网络请求放到后台线程。 */
    fun syncIfStale(ctx: Context) {
        val sp = Prefs.sp(ctx)
        val last = sp.getLong(PREF_LAST, 0)
        if (System.currentTimeMillis() - last < INTERVAL) return
        val app = ctx.applicationContext
        Thread {
            val year = Calendar.getInstance().get(Calendar.YEAR)
            var ok = false
            for (y in intArrayOf(year, year + 1)) {
                if (fetchAndStore(app, y)) ok = true
            }
            if (ok) {
                sp.edit().putLong(PREF_LAST, System.currentTimeMillis()).apply()
                cache.clear()
            }
        }.apply { isDaemon = true }.start()
    }

    private fun file(ctx: Context, year: Int) = File(ctx.filesDir, "holiday-$year.json")

    private fun loadYear(ctx: Context, year: Int): Map<String, Info>? {
        val f = file(ctx, year)
        if (!f.exists()) return null
        return try {
            parse(f.readText())
        } catch (_: Exception) {
            null
        }
    }

    private fun parse(text: String): Map<String, Info> {
        val root = JSONObject(text)
        val days = root.optJSONArray("days") ?: return emptyMap()
        val out = HashMap<String, Info>()
        for (i in 0 until days.length()) {
            val d = days.optJSONObject(i) ?: continue
            val date = d.optString("date")
            val name = d.optString("name")
            if (date.isEmpty() || name.isEmpty()) continue
            out[date] = Info(name, d.optBoolean("isOffDay", true))
        }
        return out
    }

    private fun fetchAndStore(ctx: Context, year: Int): Boolean {
        return try {
            val conn = URL(String.format(BASE, year)).openConnection() as HttpURLConnection
            conn.connectTimeout = TIMEOUT
            conn.readTimeout = TIMEOUT
            conn.setRequestProperty("User-Agent", "nailong-pet")
            if (conn.responseCode != 200) return false
            val text = conn.inputStream.bufferedReader().use { it.readText() }
            val map = parse(text)
            // 2027 这种还没公布的年份会返回空 days，不覆盖缓存
            if (map.isEmpty()) return false
            file(ctx, year).writeText(text)
            true
        } catch (_: Exception) {
            false
        }
    }
}
