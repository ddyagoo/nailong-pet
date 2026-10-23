# 奶龙桌宠 · 设计规格

> 本文件固化 2026-10-18/19 与用户在 grilling 过程中确认的所有决策。
> 后续开发遇到歧义时以本文为准；要改就先改这里。

## 1. 产品目标

一个手机上的「桌宠」：奶龙浮在桌面（真机上浮在任何 App 之上），
点一下会 Q 弹一下并播报今天的日期、节日、待办；放着一动不动它会笑。

## 2. 已确认的决策

| # | 决策 | 结果 |
|---|---|---|
| 平台 | 技术栈 | Flutter，**Android 优先**；iOS 只做 App 内形态（系统不允许跨 App 悬浮） |
| 形态 | 桌宠怎么浮 | Android 用系统悬浮窗（`SYSTEM_ALERT_WINDOW`）；App 本体只做设置/待办 |
| 预览 | 先看什么 | 先出 **web 版**（模拟手机桌面 + 手机边框），用户验收后再出 APK |
| 素材 | 角色从哪来 | 用户提供的录屏（720×1566 / 19.1s / 30fps），白底抠成透明帧序列 |
| 素材 | 动画结构 | 拆成 `idle` 循环 + `laugh`（6s）+ `egg`（完整段）三个 WebP |
| 素材 | 衔接 | 大笑 6s 版停在笑到一半，用 App 内一次「压扁回弹」遮住切回 idle；完整段用源视频 17.43s 处的硬切，该帧与 idle 首帧几乎完全一致（差异 0.57/255），直接无缝 |
| 播报 | 形式 | **只弹文字气泡，不出人声**（无 TTS） |
| 播报 | 版式 | 一个大气泡（Q4 选 B）：日期 + 农历/节气 + 节日标签 + 待办清单 |
| 播报 | 语气 | **播报员口吻**，克制准确，不卖萌 |
| 待办 | 数据源 | **读手机系统日历**（Android `READ_CALENDAR`）；web 版用本地示例清单 |
| 节日 | 范围 | 公历 + 农历传统节日 + 二十四节气 + 国际节日 + 法定假期与**调休** |
| 节日 | 数据 | `lunar` 包内置表（2001–2026，含调休）；2027 官方安排未公布，先按「无调休」处理 |
| 声音 | 出声内容 | 只有笑声与点击「啵」声；总音量一条滑杆（默认 70%）+ 静音按钮 |
| 声音 | 静音反馈 | 静音时点击改用轻振动（可关） |
| 大笑 | 触发 | 静置后在**设置区间**里随机挑一秒笑（默认 30–90 秒，可调 10–300）；**只有碰奶龙（点/长按/拖动）才重新计时**，操作屏幕别处或切 App 不影响 |
| 大笑 | 彩蛋 | 连续第 3 次笑播完整版（含笑到躺地），之后 **冷却 5 分钟**（冷却只挡自动笑，长按仍可） |
| 大笑 | 一轮结束 | 笑完立即重新计时，开始下一轮的随机区间 |
| 交互 | 单击 | Q 弹 + 点击音 + 气泡（再点收起） |
| 交互 | 长按 | **让它笑**（前两次 6 秒版，第三次起完整版） |
| 交互 | 拖动 | 可拖动，贴边吸附，记住位置；拖动同时重置静置计时 |
| 交互 | 双击 | 暂不绑定（素材不够，硬造会假） |
| 外观 | 大小 | 设置里 60%–160% 滑杆，改大小时以脚为基准往上长，位置持久化 |
| 外观 | 弹跳余量 | 悬浮窗比奶龙大 1.22 倍，Q 弹放大时头顶不会被裁 |
| 播报 | 日程范围 | 读系统日历，**今天 + 未来 3 天**，最多 9 条，按天标注（今天/明天/后天/M/d） |
| 播报 | 节假日数据 | 在线同步 `NateScarlet/holiday-cn`（7 天一次，带 gov.cn 原文），失败回退内置 2024–2031 表；**Android 原生层和 Flutter/web/Windows 各同步一份，缓存到本地** |
| 更新 | 应用内检查 | 首页「检查更新」查 GitHub Releases latest，比版本号，弹窗跳转 release 页面 |
| 外观 | 风格 | 奶油暖黄：主色 `#F5B93F`，深棕描边 `#3E2A1C`，气泡白底 + 3px 棕描边 + 圆角，标题用站酷快乐体 |
| 兼容 | 机型 | Android 8.0（minSdk 26）起，适配小屏/平板/折叠/横竖屏；拿不到悬浮窗权限时降级为 App 内桌宠并给指引 |
| 不做 | 卡包 | 不做收集玩法 |
| 不做 | 开机自启 | 不做（国产 ROM 不稳定），改为引导电池白名单 |

## 3. 素材管线

源视频（本机录屏，720×1566 / 19.1s / 30fps，白底）：

| 时间 | 内容 |
|---|---|
| 0.00–1.50 | 站立待机 |
| 1.60–12.30 | 站着大笑（能量最密在 1.6–7.6） |
| 12.30–13.40 | 笑到后仰倒地 |
| 13.40–17.30 | 躺在地上笑（音频止于 17.28） |
| 17.43 | 硬切回站立（**不是爬起来的动作**） |
| 18.40+ | 录屏者划出 iOS 控制中心，画面变暗（不可用） |

处理步骤（`tools/build_assets.py`）：

1. `ffmpeg` 裁掉状态栏与底部按钮：`crop=660:860:40:400`
2. `rembg`（u2netp 模型）抠透明，阴影一并去掉，App 里用 Flutter 画地面投影
3. 边缘处理：先把白底污染反解掉（`decontaminate`），再用**预乘 alpha** 缩放，
   否则透明区残留的白色会渗进边缘，在暖色壁纸上形成一圈灰白
4. 统一画布 597×804，缩放到宽 560（接近源分辨率）
5. 拼三段：
   - `idle.webp`：0–1.5s 正放 + 倒放（44 帧，2.93 秒，眨眼和眼珠来回都在里面）
   - `laugh.webp`：1.6–7.6s
   - `egg.webp`：1.6–17.43s（含倒地与源视频自带的硬切）
6. 帧率：idle 15fps / laugh 24fps / egg 20fps；WebP q76、alpha 质量 60

**待机节奏**：`idle.webp` 不循环播放，而是「播一次 → 停 0.5–2 秒（设置里可调，
上限 10 秒）→ 再播」，停顿由 `BlinkRhythm` 随机取。动作保持第一版的整段，
节奏却不固定。早先试过拆成眨眼 / 转眼珠小片段，动作太短、停顿太长，观感反而碎。

音频（`ffmpeg`）：`laugh.mp3`（1.6–7.6s，尾部淡出）、`laugh_full.mp3`（1.68–17.28s），
点击音由 Python 合成成 `tap.wav`。

## 4. 运行时结构

```
lib/
  main.dart                 装配 + 全局 settings→audio/brain 同步
  theme.dart                奶油暖黄 palette / 字体
  screens/home_scene.dart   模拟桌面、手机边框、顶部时钟
  ui/pet_layer.dart         奶龙本体：拖动、Q弹、长按菜单、气泡定位
  ui/idle_pet.dart          待机整段动画 + 随机停顿后重播
  ui/bubble.dart            今日播报卡片
  ui/settings_sheet.dart    音量、振动、大笑开关、回位
  ui/todo_sheet.dart        待办增删勾选
  pet/sprite_player.dart    自驱动 ui.Codec 的逐帧播放器（能停、能重播）
  pet/eye_rhythm.dart       待机停顿的随机节奏（纯逻辑，可单测）
  pet/pet_brain.dart        40s/90–150s/3次/5min 状态机
  services/holiday_service.dart  日期/农历/节气/节日/调休
  services/todo_store.dart       待办（web 本地，Android 换系统日历）
  services/settings_service.dart 偏好持久化
  services/audio_service.dart    音效播放 + web 手势解锁
```

关键实现说明：

- **web 必须用本地 CanvasKit**：Flutter 默认从 gstatic CDN 拉 `canvaskit.wasm`，
  网络受限时应用会永远停在启动页。`app/web/flutter_bootstrap.js` 里把
  `canvasKitBaseUrl` 指向构建产物自带的 `canvaskit/`。
- **不能用 `Image` widget 播动画**：它会无限循环且没有结束回调。`sprite_player.dart`
  直接驱动 `ui.Codec.getNextFrame()`，按 `FrameInfo.duration` 计时，播完回调。
- 三段动画常驻 `IndexedStack`，隐藏的那个暂停 ticker，避免每次重播重新解码。
- 待机只挂一个 `SpritePlayer`（`loop: false`），播完由 `IdlePet` 排一个随机停顿再
  `restart()`，codec 常驻、不用重新解码。
- 大笑结束的「压扁回弹」（220ms）把跨帧跳变藏在动作里。

## 5. Android 实现（已完成）

| 点 | 做法 |
|---|---|
| 悬浮窗 | 前台服务 + `WindowManager`；宠物窗口 `TYPE_APPLICATION_OVERLAY`，气泡窗口单独一个（不抢焦点、可点击收起） |
| 动画 | `AnimatedImageDrawable` 播同一批 WebP；API 26/27 退化成静态首帧 |
| 待机眨眼 | idle drawable 一次性播放（`repeatCount = 0`），2933ms 后按设置里的随机停顿（默认 0.5–2 秒，上限 10 秒）再 `start()`；笑的时候清掉待执行的计时 |
| 日期/节日 | 构建期用 Dart 的 `lunar` 包生成 `calendar.json`（2024–2031），原生查表，避免重写农历算法 |
| 待办 | `CalendarContract.Instances` 查今天，最多 6 条 |
| 设置共享 | 读 Flutter 的 `FlutterSharedPreferences`（double 带 `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu` 前缀） |
| App 在前台 | 调 `OverlayService.setAppForeground(true)` 把奶龙收起来，避免挡住自己的设置面板 |
| 气泡透明度 | 不能加 `FLAG_NOT_TOUCHABLE`（Android 12+ 会强制 alpha 0.8 导致发灰），改成可点击 |

产物：`dist/NailongPet.apk`（61MB，全架构单包；不再单独出 arm64）。

## 6. Windows 实现（原生 Flutter）

第一版是「Flutter web + Electron 外壳」，82MB 且气泡一出现就把窗口拉高 380px，
奶龙跟着跳。2026-10 换成一等公民的 `flutter build windows`：

| 点 | 做法 |
|---|---|
| 框架 | `app/windows/` runner：`WS_POPUP` 无边框、`WS_EX_TOOLWINDOW` 不进任务栏、置顶 |
| 透明 | `flutter_acrylic` 的 `WindowEffect.transparent`（`SetWindowCompositionAttribute`）。**原生 Flutter 的交换链是不透明的**，只靠 DWM 玻璃会得到纯黑底，必须走这个 API |
| 气泡 | 单窗口固定 420×660 逻辑像素，气泡画在窗口内 → **不再改窗口尺寸，乱跳问题从架构上消失** |
| 拖动 | `window_manager.startDragging()`，窗口位置本地记住 |
| 点击穿透 | `SetWindowRgn` 把窗口裁成可点区域：待机时用 idle 首帧的 alpha 生成列剪影（放大 1.26 覆盖 Q 弹），笑的时候用整块。区域外点击直接落给桌面 |
| 托盘 | `tray_manager`：显示/隐藏、检查更新、退出；右键奶龙弹同一份菜单 |
| 更新 | `lib/services/update_service.dart`：`http` 拉 Releases + `package_info_plus` 比版本，`url_launcher` 打开下载页 |
| 打包 | NSIS（`tools/installer.nsi`），装到 `%LOCALAPPDATA%\Programs\NailongPet` |
| 退出 | 发 `WM_CLOSE` 走正常关闭流程；`window_manager.destroy()` 会等插件逐个收尾，实测卡 15 秒 |

产物：`dist/windows/NailongPet-Setup-<版本>.exe`（18MB）。

## 7. 已知限制

1. Android 8.0/8.1 只有静态帧（`AnimatedImageDrawable` 需要 API 28）
2. 奶龙被拖到屏幕顶部时，气泡会盖住它
3. 全屏视频 / 游戏时不会自动静音（仍会笑）；Windows 上也还没有「全屏游戏时自动隐藏」
4. iOS 做不了跨 App 悬浮，只能做 App 内桌宠
