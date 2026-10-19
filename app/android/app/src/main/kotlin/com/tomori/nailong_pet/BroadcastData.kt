package com.tomori.nailong_pet

import android.content.Context
import android.provider.CalendarContract
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** 气泡里要显示的一整屏内容。 */
data class Broadcast(
    val dateLine: String,
    val lunarLine: String,
    val tags: List<String>,
    val next: String?,
    val todos: List<TodoItem>,
    val days: Int,
)

data class TodoItem(val day: String, val time: String, val title: String)

/**
 * 日期/农历/节日来自构建期生成好的 assets/calendar.json，
 * 法定节假日优先用在线同步下来的 holiday-cn 数据覆盖，
 * 待办来自系统日历（今天 + 未来 3 天）。
 */
class BroadcastProvider(private val ctx: Context) {

    private var table: JSONObject? = null
    private var tableDay: String? = null

    private fun key(d: Date): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(d)

    private fun load(dayKey: String): JSONObject? {
        if (tableDay == dayKey) return table
        return try {
            val text = ctx.assets.open("calendar.json").bufferedReader().use { it.readText() }
            table = JSONObject(text)
            tableDay = dayKey
            table
        } catch (e: Exception) {
            null
        }
    }

    fun today(): Broadcast {
        val now = Date()
        val dayKey = key(now)
        val entry = load(dayKey)?.optJSONObject(dayKey)

        val md = entry?.optString("md").takeUnless { it.isNullOrEmpty() } ?: ""
        val wk = entry?.optString("wk").takeUnless { it.isNullOrEmpty() } ?: ""
        val lunar = entry?.optString("l").takeUnless { it.isNullOrEmpty() } ?: ""

        val tags = mutableListOf<String>()
        entry?.optJSONArray("f")?.let { arr ->
            val names = (0 until arr.length()).map { arr.optString(it) }.filter { it.isNotEmpty() }
            if (names.isNotEmpty()) tags.add(names.joinToString(" · "))
        }
        entry?.optString("j")?.takeIf { it.isNotEmpty() }?.let { tags.add(it) }

        // 法定节假日/调休：在线数据优先，没有就退回内置表
        val online = HolidaySync.lookup(ctx, dayKey)
        if (online != null) {
            tags.add(if (online.off) "${online.name} · 假期" else "${online.name} · 调休上班")
        } else {
            entry?.optString("h")?.takeIf { it.isNotEmpty() }?.let { name ->
                val rest = entry.optBoolean("rest", false)
                tags.add(if (rest) "$name · 假期" else name)
            }
            entry?.optString("adj")?.takeIf { it.isNotEmpty() }?.let { tags.add(it) }
        }

        val todos = readCalendar()
        return Broadcast(
            dateLine = listOf(md, wk).filter { it.isNotEmpty() }.joinToString(" "),
            lunarLine = lunar,
            tags = tags,
            next = entry?.optString("n")?.takeIf { it.isNotEmpty() },
            todos = todos,
            days = SPAN_DAYS,
        )
    }

    /** 从今天 0 点开始，往后查 4 天，最多 9 条。 */
    private fun readCalendar(): List<TodoItem> {
        if (SAMPLE) {
            return listOf(
                TodoItem("今天", "10:00", "把周报发给组长"),
                TodoItem("今天", "15:30", "取快递（驿站 18:00 关门）"),
                TodoItem("明天", "全天", "部门团建"),
                TodoItem("后天", "09:30", "体检"),
                TodoItem("10/23", "14:00", "牙医复诊"),
            )
        }
        val out = mutableListOf<TodoItem>()
        try {
            val begin = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            val todayStart = begin.timeInMillis
            val end = begin.clone() as Calendar
            end.add(Calendar.DAY_OF_YEAR, SPAN_DAYS)

            val uri = CalendarContract.Instances.CONTENT_URI.buildUpon()
                .appendPath(todayStart.toString())
                .appendPath(end.timeInMillis.toString())
                .build()

            val projection = arrayOf(
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.ALL_DAY,
                CalendarContract.Instances.EVENT_ID,
            )

            val seenTitles = HashMap<String, Long>()
            ctx.contentResolver.query(
                uri, projection, null, null,
                "${CalendarContract.Instances.BEGIN} ASC",
            )?.use { c ->
                val titleIdx = c.getColumnIndexOrThrow(CalendarContract.Instances.TITLE)
                val beginIdx = c.getColumnIndexOrThrow(CalendarContract.Instances.BEGIN)
                val allDayIdx = c.getColumnIndexOrThrow(CalendarContract.Instances.ALL_DAY)
                while (c.moveToNext() && out.size < 9) {
                    val title = c.getString(titleIdx)?.trim().orEmpty()
                    if (title.isEmpty()) continue
                    val start = c.getLong(beginIdx)
                    // 多天日程在 Instances 里每天一条，这里只留第一次出现的
                    val last = seenTitles[title]
                    if (last != null && start - last <= 36 * 3600_000L) continue
                    seenTitles[title] = start

                    val allDay = c.getInt(allDayIdx) == 1
                    val time = if (allDay) "全天"
                    else SimpleDateFormat("HH:mm", Locale.US).format(Date(start))
                    out.add(TodoItem(dayLabel(start, todayStart), time, title))
                }
            }
        } catch (_: SecurityException) {
            // 没给日历权限就只是没有待办
        } catch (_: Exception) {
        }
        return out
    }

    private fun dayLabel(startMillis: Long, todayStart: Long): String {
        val day = ((startMillis - todayStart) / 86_400_000L).toInt()
        return when (day) {
            0 -> "今天"
            1 -> "明天"
            2 -> "后天"
            else -> SimpleDateFormat("M/d", Locale.US).format(Date(startMillis))
        }
    }

    companion object {
        const val SPAN_DAYS = 4
        // 调试排版时可以临时改成 true，用假数据看气泡
        private const val SAMPLE = false
    }
}
