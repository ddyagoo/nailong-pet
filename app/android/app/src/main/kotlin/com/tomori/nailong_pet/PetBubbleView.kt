package com.tomori.nailong_pet

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.text.TextPaint
import android.text.TextUtils
import android.view.View

/** 悬浮窗里的「近日播报」卡片，纯 native 绘制。 */
class PetBubbleView(context: Context) : View(context) {

    var data: Broadcast? = null
        set(value) {
            field = value
            requestLayout()
            invalidate()
        }

    /** 尾巴在卡片底部的位置 0..1 */
    var tailAlign: Float = 0.5f

    /** 卡片宽度（像素），由服务按屏幕宽度设置 */
    var widthPx: Int = 0

    private val density = resources.displayMetrics.density
    private fun dp(v: Float) = v * density

    private val cardPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#FFFCF5")
        style = Paint.Style.FILL
    }
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#3E2A1C")
        style = Paint.Style.STROKE
        strokeWidth = dp(2.0f)
    }
    private val dividerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#E8D5BC")
        strokeWidth = dp(1f)
    }

    private val typeface: Typeface = try {
        Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/ZCOOLKuaiLe-Regular.ttf")
    } catch (e: Exception) {
        Typeface.DEFAULT
    }

    private val titlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = this@PetBubbleView.typeface
        textSize = dp(19f)
        color = Color.parseColor("#3E2A1C")
    }
    private val captionPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = this@PetBubbleView.typeface
        textSize = dp(12f)
        color = Color.parseColor("#8A6A50")
    }
    private val labelPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = this@PetBubbleView.typeface
        textSize = dp(14.5f)
        color = Color.parseColor("#3E2A1C")
    }
    private val bodyPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = this@PetBubbleView.typeface
        textSize = dp(13f)
        color = Color.parseColor("#3E2A1C")
    }
    private val tagPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = this@PetBubbleView.typeface
        textSize = dp(12.5f)
        color = Color.parseColor("#D2743A")
    }

    private val pad = dp(17f)
    private val cardWidth = dp(300f)
    private val tailH = dp(11f)
    private val tailW = dp(20f)
    private val dayW = dp(38f)
    private val timeW = dp(42f)

    private fun lineH(p: TextPaint) = p.fontSpacing

    private fun rows(d: Broadcast) = d.todos.take(9)

    private fun contentHeight(d: Broadcast?): Float {
        if (d == null) return pad * 2 + dp(40f) + tailH
        var h = pad
        h += lineH(titlePaint)
        if (d.lunarLine.isNotEmpty()) h += lineH(captionPaint)
        if (d.tags.isNotEmpty()) h += lineH(tagPaint) + dp(2f)
        h += dp(10f) + dp(1f) + dp(12f)
        h += lineH(labelPaint)
        if (d.todos.isEmpty()) {
            h += lineH(captionPaint)
        } else {
            for (i in rows(d).indices) h += lineH(bodyPaint) + dp(7f)
            if (d.todos.size > 9) h += lineH(captionPaint)
        }
        if (d.next != null) h += lineH(captionPaint) + dp(4f)
        h += pad
        h += tailH
        return h
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val w = if (widthPx > 0) widthPx else cardWidth.toInt()
        setMeasuredDimension(w, contentHeight(data).toInt())
    }

    override fun onDraw(canvas: Canvas) {
        val d = data ?: return
        val cardBottom = height - tailH
        val rect = RectF(dp(1.2f), dp(1.2f), width - dp(1.2f), cardBottom - dp(1.2f))
        val radius = dp(20f)

        canvas.drawRoundRect(rect, radius, radius, cardPaint)
        canvas.drawRoundRect(rect, radius, radius, borderPaint)

        // 尾巴：盖住卡片底边
        val tx = (width * tailAlign).coerceIn(dp(30f), width - dp(30f))
        val tailFill = Path().apply {
            moveTo(tx - tailW / 2, cardBottom - dp(2f))
            lineTo(tx, height - dp(1.5f))
            lineTo(tx + tailW / 2, cardBottom - dp(2f))
            close()
        }
        canvas.drawPath(tailFill, cardPaint)
        val tailBorder = Path().apply {
            moveTo(tx - tailW / 2, cardBottom - dp(2f))
            lineTo(tx, height - dp(1.5f))
            lineTo(tx + tailW / 2, cardBottom - dp(2f))
        }
        canvas.drawPath(tailBorder, borderPaint)

        val maxW = width - pad * 2
        var top = pad

        fun line(text: String, paint: TextPaint, x: Float = pad, width: Float = maxW) {
            if (text.isEmpty()) return
            val out = TextUtils.ellipsize(text, paint, width, TextUtils.TruncateAt.END)
            canvas.drawText(out, 0, out.length, x, top + paint.textSize, paint)
            top += lineH(paint)
        }

        line(d.dateLine, titlePaint)
        if (d.lunarLine.isNotEmpty()) line(d.lunarLine, captionPaint)
        if (d.tags.isNotEmpty()) {
            line(d.tags.joinToString(" · "), tagPaint)
            top += dp(2f)
        }

        top += dp(10f)
        canvas.drawLine(pad, top, width - pad, top, dividerPaint)
        top += dp(1f) + dp(12f)

        val header = if (d.todos.isEmpty()) "· 接下来 ${d.days} 天没有日程"
        else "· 接下来 ${d.days} 天 · ${d.todos.size} 项"
        line(header, labelPaint)

        if (d.todos.isEmpty()) {
            line("可以放心玩啦", captionPaint, pad + dp(6f), maxW - dp(6f))
        } else {
            for (t in rows(d)) {
                val baseline = top + bodyPaint.textSize
                val x0 = pad + dp(4f)
                canvas.drawText(t.day, x0, baseline, captionPaint)
                canvas.drawText(t.time, x0 + dayW, baseline, captionPaint)
                val titleX = x0 + dayW + timeW
                val out = TextUtils.ellipsize(
                    t.title, bodyPaint, width - pad - titleX, TextUtils.TruncateAt.END,
                )
                canvas.drawText(out, 0, out.length, titleX, baseline, bodyPaint)
                top += lineH(bodyPaint) + dp(7f)
            }
            if (d.todos.size > 9) {
                line("还有 ${d.todos.size - 9} 项…", captionPaint, pad + dp(6f), maxW - dp(6f))
            }
        }

        if (d.next != null) {
            top += dp(4f)
            line("· ${d.next}", captionPaint)
        }
    }
}
