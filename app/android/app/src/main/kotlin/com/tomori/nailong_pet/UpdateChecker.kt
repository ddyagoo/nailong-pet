package com.tomori.nailong_pet

import android.content.Context
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * 从 GitHub Releases 查最新版本。
 *
 * 仓库地址改这里就行；App 里只在用户点「检查更新」时联网，
 * 不会后台偷偷查。
 */
object UpdateChecker {

    const val REPO = "tomori/nailong-pet"
    const val RELEASES_PAGE = "https://github.com/$REPO/releases"

    data class Result(
        val ok: Boolean,
        val newer: Boolean,
        val tag: String,
        val url: String,
        val notes: String,
        val message: String,
    )

    fun check(currentVersion: String): Result {
        return try {
            val conn = URL("https://api.github.com/repos/$REPO/releases/latest")
                .openConnection() as HttpURLConnection
            conn.connectTimeout = 8000
            conn.readTimeout = 8000
            conn.setRequestProperty("User-Agent", "nailong-pet")
            conn.setRequestProperty("Accept", "application/vnd.github+json")
            val code = conn.responseCode
            if (code != 200) {
                return Result(
                    false, false, "", RELEASES_PAGE, "",
                    if (code == 404) "还没发布过版本（或仓库地址不对）" else "检查失败（HTTP $code）",
                )
            }
            val text = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(text)
            val tag = json.optString("tag_name").ifEmpty { json.optString("name") }
            val url = json.optString("html_url").ifEmpty { RELEASES_PAGE }
            val notes = json.optString("body")
            val newer = isNewer(tag, currentVersion)
            Result(
                true, newer, tag, url, notes,
                if (newer) "发现新版本 $tag" else "已经是最新版本（$currentVersion）",
            )
        } catch (_: Exception) {
            Result(false, false, "", RELEASES_PAGE, "", "网络异常，稍后再试")
        }
    }

    private fun isNewer(remote: String, local: String): Boolean {
        val r = parse(remote) ?: return false
        val l = parse(local) ?: return false
        for (i in 0 until maxOf(r.size, l.size)) {
            val a = r.getOrElse(i) { 0 }
            val b = l.getOrElse(i) { 0 }
            if (a != b) return a > b
        }
        return false
    }

    private fun parse(v: String): List<Int>? {
        val clean = v.trim().removePrefix("v").removePrefix("V").substringBefore('-')
        if (clean.isEmpty()) return null
        val out = mutableListOf<Int>()
        for (part in clean.split('.')) {
            val n = part.toIntOrNull() ?: return null
            out.add(n)
        }
        return out
    }
}
