package com.tomori.nailong_pet

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.Point
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

/**
 * 把奶龙放到别的 App 之上的悬浮窗服务。
 *
 * 一个前台服务 + 两个 WindowManager 窗口：
 *  - 宠物窗口：奶龙本体，接收触摸（点/长按/拖）
 *  - 气泡窗口：今日播报，NOT_TOUCHABLE，点上去会穿透
 */
class OverlayService : Service(), PetOverlayView.Listener {

    companion object {
        const val ACTION_STOP = "com.tomori.nailong_pet.STOP"
        private const val CHANNEL_ID = "nailong_overlay"
        private const val NOTIFICATION_ID = 42
        private const val COOLDOWN = 5 * 60_000L
        private const val SPRITE_ASPECT = 0.7425f

        @Volatile
        var running = false
            private set

        @Volatile
        private var instance: OverlayService? = null

        /** App 自己的界面是否在前台（onCreate 时服务可能还没起来，所以状态放在静态字段）。 */
        @Volatile
        var appForeground = false
            private set

        /** App 自己的界面在前台时先收起奶龙，免得它盖住设置面板。 */
        fun setAppForeground(fg: Boolean) {
            appForeground = fg
            instance?.applyAppForeground(fg)
        }

        fun start(ctx: Context) {
            val i = Intent(ctx, OverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }

        fun stop(ctx: Context) {
            ctx.startService(Intent(ctx, OverlayService::class.java).apply {
                action = ACTION_STOP
            })
        }
    }

    private lateinit var wm: WindowManager
    private lateinit var audio: PetAudio
    private lateinit var provider: BroadcastProvider

    private var petView: PetOverlayView? = null
    private var petParams: WindowManager.LayoutParams? = null
    private var bubbleView: PetBubbleView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var bubbleVisible = false

    private val handler = Handler(Looper.getMainLooper())
    private val random = Random(System.currentTimeMillis())

    private var laughs = 0
    private var cooling = false
    private var idleRunnable: Runnable? = null
    private var bubbleHideRunnable: Runnable? = null

    private val dp get() = resources.displayMetrics.density
    private fun dp(v: Float) = v * dp

    private val prefsListener =
        SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            when (key) {
                "flutter.volume", "flutter.muted" -> audio.setVolume(Prefs.volume(this))
                "flutter.pet_scale" -> resizePet()
                "flutter.idle_min", "flutter.idle_max" -> resetIdle()
            }
        }

    override fun onCreate() {
        super.onCreate()
        instance = this
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        audio = PetAudio(this)
        audio.setVolume(Prefs.volume(this))
        provider = BroadcastProvider(this)
        Prefs.sp(this).registerOnSharedPreferenceChangeListener(prefsListener)
        createChannel()
        HolidaySync.syncIfStale(this)
    }

    private fun applyAppForeground(fg: Boolean) {
        handler.post {
            if (fg) {
                idleRunnable?.let { handler.removeCallbacks(it) }
                hideBubble()
                petView?.let {
                    try {
                        wm.removeView(it)
                    } catch (_: Exception) {
                    }
                }
                petView = null
                petParams = null
            } else if (petView == null) {
                showPet()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        if (petView == null) showPet()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        running = false
        instance = null
        idleRunnable?.let { handler.removeCallbacks(it) }
        bubbleHideRunnable?.let { handler.removeCallbacks(it) }
        handler.removeCallbacksAndMessages(null)
        hideBubble()
        petView?.let {
            try {
                wm.removeView(it)
            } catch (_: Exception) {
            }
        }
        petView = null
        Prefs.sp(this).unregisterOnSharedPreferenceChangeListener(prefsListener)
        audio.release()
        super.onDestroy()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        handler.post { resizePet() }
    }

    // ---------------- 通知 ----------------

    private fun createChannel() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID, "桌面上的奶龙", NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "让奶龙一直待在桌面上"
                    setShowBadge(false)
                },
            )
        }
    }

    private fun startInForeground() {
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("奶龙在桌面上")
            .setContentText("点一下看今天 · 长按让它笑")
            .setSmallIcon(R.drawable.ic_notify)
            .setContentIntent(open)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        running = true
    }

    // ---------------- 窗口 ----------------

    private fun screenSize(): Point {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val b = wm.currentWindowMetrics.bounds
            Point(b.width(), b.height())
        } else {
            val dm = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(dm)
            Point(dm.widthPixels, dm.heightPixels)
        }
    }

    private fun desiredPetSize(): Point {
        val screen = screenSize()
        val base = min(screen.x * 0.56f, dp(300f))
        val visualW = (base * Prefs.scale(this)).toInt()
            .coerceIn(dp(90f).toInt(), dp(460f).toInt())
        // 窗口比奶龙大一圈，给 Q 弹留余量
        val w = (visualW * PetOverlayView.SCALE_PADDING).toInt()
        return Point(w, (w / SPRITE_ASPECT).toInt())
    }

    private fun showPet() {
        if (appForeground) return
        if (!android.provider.Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        val screen = screenSize()
        val size = desiredPetSize()
        val saved = Prefs.overlayPos(this)
        var x = saved?.first ?: (screen.x - size.x - dp(16f).toInt())
        var y = saved?.second ?: (screen.y - size.y - dp(8f).toInt())
        x = x.coerceIn(0, max(0, screen.x - size.x))
        y = y.coerceIn(0, max(0, screen.y - size.y))

        val lp = WindowManager.LayoutParams(
            size.x, size.y,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            this.x = x
            this.y = y
        }

        val view = PetOverlayView(this)
        view.listener = this
        try {
            wm.addView(view, lp)
        } catch (e: Exception) {
            stopSelf()
            return
        }
        petView = view
        petParams = lp
        resetIdle()
    }

    private fun resizePet() {
        val view = petView ?: return
        val lp = petParams ?: return
        val screen = screenSize()
        val size = desiredPetSize()
        val oldW = lp.width
        val oldH = lp.height
        lp.width = size.x
        lp.height = size.y
        // 以脚为基准缩放，并保持水平中心
        lp.x = (lp.x + (oldW - size.x) / 2).coerceIn(0, max(0, screen.x - size.x))
        lp.y = (lp.y + (oldH - size.y)).coerceIn(0, max(0, screen.y - size.y))
        try {
            wm.updateViewLayout(view, lp)
        } catch (_: Exception) {
        }
        if (bubbleVisible) updateBubble()
    }

    // ---------------- 触摸 ----------------

    override fun onPetTap() {
        petView?.bounce()
        audio.playTap()
        if (Prefs.hapticOn(this)) vibrate()
        if (petView?.isLaughing() == true) {
            petView?.showIdle()
            audio.stop()
        }
        resetIdle()
        if (bubbleVisible) hideBubble() else showBubble()
    }

    override fun onPetLongPress() {
        if (Prefs.hapticOn(this)) vibrate()
        laugh()
        resetIdle()
    }

    override fun onPetDrag(dx: Float, dy: Float) {
        val view = petView ?: return
        val lp = petParams ?: return
        // 只有真的动了奶龙才重新计时；碰屏幕其他地方不影响
        resetIdle()
        val screen = screenSize()
        lp.x = (lp.x + dx).toInt().coerceIn(0, max(0, screen.x - lp.width))
        lp.y = (lp.y + dy).toInt().coerceIn(0, max(0, screen.y - lp.height))
        try {
            wm.updateViewLayout(view, lp)
        } catch (_: Exception) {
        }
        if (bubbleVisible) updateBubble()
    }

    override fun onPetDragEnd() {
        val lp = petParams ?: return
        val screen = screenSize()
        val snap = dp(28f).toInt()
        if (lp.x < snap) lp.x = dp(10f).toInt()
        if (lp.x > screen.x - lp.width - snap) lp.x = screen.x - lp.width - dp(10f).toInt()
        try {
            wm.updateViewLayout(petView, lp)
        } catch (_: Exception) {
        }
        Prefs.saveOverlayPos(this, lp.x, lp.y)
        if (bubbleVisible) updateBubble()
    }

    // ---------------- 气泡 ----------------

    private fun showBubble() {
        val pet = petParams ?: return
        val screen = screenSize()
        val view = bubbleView ?: PetBubbleView(this).also { bubbleView = it }
        view.data = provider.today()
        view.widthPx = min(dp(300f).toInt(), (screen.x * 0.88f).toInt())
        view.measure(
            View.MeasureSpec.makeMeasureSpec(view.widthPx, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        val h = view.measuredHeight

        val lp = WindowManager.LayoutParams(
            view.widthPx, h,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }

        // 注意：如果加 FLAG_NOT_TOUCHABLE，Android 12+ 会把整个窗口的 alpha
        // 强制压到 0.8（防止遮挡点击），卡片会发灰。所以这里让气泡可点击，
        // 点一下就是收起。
        view.setOnClickListener { hideBubble() }

        placeBubble(lp, pet)
        try {
            wm.addView(view, lp)
        } catch (_: Exception) {
            return
        }
        bubbleParams = lp
        bubbleVisible = true
        bubbleHideRunnable?.let { handler.removeCallbacks(it) }
        val hide = Runnable { hideBubble() }
        bubbleHideRunnable = hide
        handler.postDelayed(hide, 12_000)
    }

    private fun placeBubble(lp: WindowManager.LayoutParams, pet: WindowManager.LayoutParams) {
        val screen = screenSize()
        val center = pet.x + pet.width / 2
        val x = (center - lp.width / 2).coerceIn(dp(8f).toInt(), max(dp(8f).toInt(), screen.x - lp.width - dp(8f).toInt()))
        val statusBar = statusBarHeight()
        // 窗口顶上有一圈透明余量，气泡要贴着头顶而不是窗口顶
        val spriteTop = pet.y + (pet.height - pet.height / PetOverlayView.SCALE_PADDING).toInt()
        var y = spriteTop - lp.height - dp(2f).toInt()
        if (y < statusBar) y = statusBar
        lp.x = x
        lp.y = y
        bubbleView?.tailAlign =
            ((center - x).toFloat() / lp.width).coerceIn(0.16f, 0.84f)
    }

    private fun updateBubble() {
        val view = bubbleView ?: return
        val lp = bubbleParams ?: return
        val pet = petParams ?: return
        placeBubble(lp, pet)
        view.invalidate()
        try {
            wm.updateViewLayout(view, lp)
        } catch (_: Exception) {
        }
    }

    private fun hideBubble() {
        bubbleHideRunnable?.let { handler.removeCallbacks(it) }
        if (!bubbleVisible) return
        bubbleVisible = false
        try {
            bubbleView?.let { wm.removeView(it) }
        } catch (_: Exception) {
        }
    }

    private fun statusBarHeight(): Int {
        val id = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else dp(24f).toInt()
    }

    // ---------------- 笑 ----------------

    private fun resetIdle() {
        idleRunnable?.let { handler.removeCallbacks(it) }
        val delay = nextIdleDelay()
        android.util.Log.d("Nailong", "idle timer: ${delay / 1000}s")
        val r = Runnable { maybeLaugh() }
        idleRunnable = r
        handler.postDelayed(r, delay)
    }

    /** 静置区间里随机取一秒。 */
    private fun nextIdleDelay(): Long {
        val lo = Prefs.idleMin(this)
        val hi = Prefs.idleMax(this).coerceAtLeast(lo)
        val span = hi - lo
        val seconds = lo + if (span > 0) random.nextInt(span + 1) else 0
        return seconds * 1000L
    }

    private fun maybeLaugh() {
        if (!Prefs.laughOn(this) || cooling) {
            resetIdle()
            return
        }
        laugh()
    }

    private fun laugh() {
        if (petView?.isLaughing() == true) {
            // 上一轮还没播完（比如刚长按过），别丢掉这一轮，重新排下一次
            resetIdle()
            return
        }
        laughs += 1
        val egg = laughs % 3 == 0
        android.util.Log.d("Nailong", "laugh #$laughs egg=$egg")
        hideBubble()
        petView?.playLaugh(egg) { onLaughFinished(egg) }
        audio.playLaugh(egg)
        if (Prefs.hapticOn(this)) vibrate()
    }

    private fun onLaughFinished(egg: Boolean) {
        if (egg) {
            laughs = 0
            cooling = true
            handler.postDelayed({ cooling = false }, COOLDOWN)
        }
        resetIdle()
    }

    private fun vibrate() {
        try {
            val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (v.hasVibrator()) {
                v.vibrate(VibrationEffect.createOneShot(18, VibrationEffect.DEFAULT_AMPLITUDE))
            }
        } catch (_: Exception) {
        }
    }
}

