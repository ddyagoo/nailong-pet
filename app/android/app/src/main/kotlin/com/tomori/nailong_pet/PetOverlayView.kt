package com.tomori.nailong_pet

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.drawable.AnimatedImageDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import kotlin.math.abs
import kotlin.math.min

/**
 * 悬浮窗里画奶龙的那个 View。
 *
 * 精灵是透明动画 WebP：API 28+ 用 AnimatedImageDrawable 原生播，
 * 26/27 退化成静态首帧。
 */
class PetOverlayView(context: Context) : View(context) {

    interface Listener {
        fun onPetTap()
        fun onPetLongPress()
        fun onPetDrag(dx: Float, dy: Float)
        fun onPetDragEnd()
    }

    enum class State { IDLE, LAUGH }

    companion object {
        /**
         * 窗口比奶龙本身大一圈：Q 弹/压扁时它会往外长，窗口不留余量就会被裁掉
         * 头顶。1.22 能容下最大 1.18 的放大倍数。
         */
        const val SCALE_PADDING = 1.22f
    }

    var listener: Listener? = null

    private val idleDuration = 2933L
    private val laughDuration = 6000L
    private val eggDuration = 15850L

    private var idleDrawable: Drawable? = null
    private var laughDrawable: Drawable? = null
    private var eggDrawable: Drawable? = null

    private var current: Drawable? = null
    private var state = State.IDLE

    private val handler = Handler(Looper.getMainLooper())
    private val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG)

    private var bounce = 0f
    private var squash = 0f
    private var bounceAnimator: ValueAnimator? = null
    private var squashAnimator: ValueAnimator? = null
    private var endRunnable: Runnable? = null

    private var downRawX = 0f
    private var downRawY = 0f
    private var lastRawX = 0f
    private var lastRawY = 0f
    private var dragging = false
    private var longPressed = false
    private var touchSlop = 24f

    private val longPressRunnable = Runnable {
        if (!dragging) {
            longPressed = true
            listener?.onPetLongPress()
        }
    }

    init {
        touchSlop = 12f * resources.displayMetrics.density
        loadDrawables()
        showIdle()
    }

    private fun drawableFrom(path: String): Drawable? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val src = ImageDecoder.createSource(context.assets, path)
                val d = ImageDecoder.decodeDrawable(src)
                if (d is AnimatedImageDrawable) d.repeatCount = AnimatedImageDrawable.REPEAT_INFINITE
                d
            } else {
                context.assets.open(path).use { BitmapFactory.decodeStream(it) }
                    ?.let { android.graphics.drawable.BitmapDrawable(resources, it) }
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun loadDrawables() {
        val base = "flutter_assets/assets/pet/"
        idleDrawable = drawableFrom(base + "idle.webp")
        laughDrawable = drawableFrom(base + "laugh.webp")
        eggDrawable = drawableFrom(base + "egg.webp")
        listOfNotNull(idleDrawable, laughDrawable, eggDrawable).forEach {
            if (it is AnimatedImageDrawable) {
                it.callback = object : Drawable.Callback {
                    override fun invalidateDrawable(who: Drawable) = invalidate()
                    override fun scheduleDrawable(who: Drawable, what: Runnable, whenMillis: Long) {
                        handler.postAtTime(what, whenMillis)
                    }

                    override fun unscheduleDrawable(who: Drawable, what: Runnable) {
                        handler.removeCallbacks(what)
                    }
                }
            }
        }
    }

    private fun startDrawable(d: Drawable?) {
        if (d is AnimatedImageDrawable) {
            d.stop()
            d.start()
        }
        current = d
        invalidate()
    }

    fun showIdle() {
        endRunnable?.let { handler.removeCallbacks(it) }
        endRunnable = null
        state = State.IDLE
        startDrawable(idleDrawable)
    }

    /** 笑一次；egg=true 播完整版（笑到躺下）。结束后自动回到 idle。 */
    fun playLaugh(egg: Boolean, onDone: (() -> Unit)? = null) {
        state = State.LAUGH
        val d = if (egg) eggDrawable else laughDrawable
        android.util.Log.d("Nailong", "playLaugh egg=$egg drawable=${d != null}")
        if (d is AnimatedImageDrawable) d.repeatCount = 0
        startDrawable(d)

        val duration = if (egg) eggDuration else laughDuration
        val r = Runnable {
            if (state != State.LAUGH) return@Runnable
            if (!egg) {
                // 6 秒版停在笑到一半，切回站姿时压一下遮住跳变
                startSquash()
                handler.postDelayed({ showIdle() }, 92)
            } else {
                showIdle()
            }
            onDone?.invoke()
        }
        endRunnable = r
        handler.postDelayed(r, duration)
    }

    private fun startSquash() {
        squashAnimator?.cancel()
        squashAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 260
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener {
                squash = it.animatedValue as Float
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    squash = 0f
                    invalidate()
                }
            })
        }
        squashAnimator?.start()
    }

    fun bounce() {
        bounceAnimator?.cancel()
        bounceAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 640
            addUpdateListener {
                bounce = it.animatedValue as Float
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    bounce = 0f
                    invalidate()
                }
            })
        }
        bounceAnimator?.start()
    }

    fun isLaughing() = state == State.LAUGH

    override fun onDetachedFromWindow() {
        endRunnable?.let { handler.removeCallbacks(it) }
        (current as? AnimatedImageDrawable)?.stop()
        super.onDetachedFromWindow()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downRawX = event.rawX
                downRawY = event.rawY
                lastRawX = downRawX
                lastRawY = downRawY
                dragging = false
                longPressed = false
                handler.postDelayed(longPressRunnable, 460)
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - lastRawX
                val dy = event.rawY - lastRawY
                val total = abs(event.rawX - downRawX) + abs(event.rawY - downRawY)
                if (!dragging && total > touchSlop) {
                    dragging = true
                    handler.removeCallbacks(longPressRunnable)
                }
                if (dragging) {
                    listener?.onPetDrag(dx, dy)
                    lastRawX = event.rawX
                    lastRawY = event.rawY
                }
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                handler.removeCallbacks(longPressRunnable)
                if (dragging) {
                    listener?.onPetDragEnd()
                } else if (!longPressed) {
                    listener?.onPetTap()
                }
                dragging = false
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun onDraw(canvas: Canvas) {
        val d = current ?: return
        val iw = d.intrinsicWidth.coerceAtLeast(1)
        val ih = d.intrinsicHeight.coerceAtLeast(1)

        // 留出弹跳余量：精灵只占窗口的 1/SCALE_PADDING
        val baseW = width / SCALE_PADDING
        val baseH = height / SCALE_PADDING
        val s = min(baseW / iw, baseH / ih)

        // 地面阴影
        val cx = width / 2f
        val baseY = height - 2f
        shadowPaint.shader = RadialGradient(
            cx, baseY, width * 0.30f,
            intArrayOf(Color.argb(72, 62, 42, 28), Color.argb(0, 62, 42, 28)),
            floatArrayOf(0f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawOval(
            cx - width * 0.26f, baseY - height * 0.030f,
            cx + width * 0.26f, baseY + height * 0.010f,
            shadowPaint,
        )

        val pulse = bounceScale(bounce)
        val sq = squashScale(squash)
        val sy = pulse * sq
        val sx = pulse * (1f + (sy - 1f) * -0.28f)

        val dw = iw * s
        val dh = ih * s
        val left = (width - dw) / 2f
        val top = height - dh

        canvas.save()
        canvas.scale(sx, sy, width / 2f, height.toFloat())
        d.setBounds(
            left.toInt(), top.toInt(),
            (left + dw).toInt(), (top + dh).toInt(),
        )
        d.draw(canvas)
        canvas.restore()
    }

    private fun bounceScale(t: Float): Float {
        if (t <= 0f) return 1f
        val keys = floatArrayOf(0f, 0.2f, 0.45f, 0.7f, 1f)
        val vals = floatArrayOf(1f, 1.18f, 0.94f, 1.05f, 1f)
        for (i in 1 until keys.size) {
            if (t <= keys[i]) {
                val k = (t - keys[i - 1]) / (keys[i] - keys[i - 1])
                return vals[i - 1] + (vals[i] - vals[i - 1]) * k
            }
        }
        return 1f
    }

    private fun squashScale(p: Float): Float {
        if (p <= 0f) return 1f
        return when {
            p < 0.45f -> 1f - 0.10f * (p / 0.45f)
            p < 0.75f -> 0.90f + 0.14f * ((p - 0.45f) / 0.30f)
            else -> 1.04f - 0.04f * ((p - 0.75f) / 0.25f)
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(
            MeasureSpec.getSize(widthMeasureSpec),
            MeasureSpec.getSize(heightMeasureSpec),
        )
    }
}
