# 奶龙桌宠

点一下奶龙，它 Q 弹一下，然后告诉你今天几号、什么节日、接下来几天有什么事；
放着不管，它会在你设定的「静置区间」里随便挑一秒笑，连续第三次笑到躺在地上。

两种形态：

- **Android**：真·桌宠，奶龙浮在任何 App 之上（`dist/NailongPet-arm64.apk`）
- **Windows**：透明置顶窗口 + 托盘，绿色版免安装（`dist/windows/NailongPet-win-x64.zip`）
- **web**：模拟手机桌面，用来快速看效果（见下面的「跑起来」）

## 装到电脑上（Windows）

1. 下载 `dist/windows/NailongPet-win-x64.zip`（120MB），解压到任意目录
2. 双击 `NailongPet.exe`，奶龙出现在屏幕右下角

- **左键拖动**：挪位置
- **单击**：今日播报
- **长按**：笑（第三次笑到躺下）
- **右键**：菜单（打开设置 / 显示隐藏 / 退出）
- **托盘图标**：同样能打开设置、退出

设置窗口里改的音量 / 大小 / 静置区间，关掉窗口就会同步到奶龙。卸载 = 删文件夹。

> Windows 版是「Flutter web 构建 + Electron 外壳」：界面和逻辑跟手机是同一套 Dart 代码，
> 透明贴桌面这层由 Electron 做（和 Android 用 Kotlin 悬浮窗是同一个思路）。
> 待办在电脑上读不到系统日历，用的是 App 内的本地清单（在设置窗口里点「待办」维护）。

## 装到手机上（Android）

1. 把 `dist/NailongPet-arm64.apk` 传到手机（数据线 / 微信文件传输都行），点开安装；
   系统提示「未知来源」时允许一次。
   - arm64 版 29MB，绝大多数手机（含红米）都用这个
   - 万一提示「应用未安装」，换 `dist/NailongPet-universal.apk`（59MB，含所有架构）
2. 打开「奶龙桌宠」，三行权限都点成「已开启」：悬浮窗 / 日历 / 通知
3. 点 **把奶龙放到桌面**，然后按 Home 回主屏幕，奶龙就在右下角了

> 小米 / 红米额外开两个开关，不然锁屏一会儿就被系统杀掉：
> 设置 → 应用设置 → 奶龙桌宠 → **后台弹出界面**（允许）、**省电策略 → 无限制**。
> App 里有「电池白名单」按钮直接跳到对应页面。

**奶龙在 App 里不显示是正常的**：你自己的 App 在前台时它会先收起来，免得挡住设置面板，
一回到桌面就出现。

停止：打开 App 点「收回奶龙」。

## 跑起来（web）

```powershell
cd app
flutter build web --release
cd build\web
python -m http.server 8788 --bind 0.0.0.0
```

- 电脑上打开 <http://127.0.0.1:8788>
- 想看「第三次笑到躺下」的彩蛋：地址后面加 `?fast=1`，等待时间会被压缩成几秒

开发时热重载：`cd app && flutter run -d chrome`

> 注意：`app/web/flutter_bootstrap.js` 把 CanvasKit 指到了本地 `canvaskit/`。
> Flutter 默认从 gstatic CDN 下载，网络受限时会一直停在「奶龙这就来…」，别删这个文件。

## 交互

| 动作 | 结果 |
|---|---|
| 单击 | Q 弹 + 一声「啵」+ 播报气泡（再点收起，12 秒自动收起） |
| 长按 | 让它笑：前两次播 6 秒版，第三次起笑到躺下 |
| 拖动 | 挪位置，贴边吸附，下次打开还在原地；拖动也会重置静置计时 |
| 静置 | 在设置区间里随机挑一秒笑（默认 30–90 秒），笑完重新计时进入下一轮；第 3 次播放完整彩蛋，然后冷却 5 分钟 |
| 顶部按钮 | 待办 / 静音 / 设置（音量、奶龙大小、静置区间、振动、大笑开关、回位） |

**静置计时的规则**：只有「碰到奶龙」（点它 / 长按 / 拖它）才重新计时。
在屏幕别的地方操作、切到别的 App，都不影响它——时间到了就笑。

## 播报里有什么

- 公历 + 星期 + 农历（节气当天带上节气）
- 节日标签：传统节日 / 国际节日 / 法定假期 / **调休上班**
- **接下来 4 天**的系统日程（今天 / 明天 / 后天 / M/d，最多 9 条）

法定节假日数据来自 [NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn)
（每年国务院公告后更新，带 gov.cn 原文链接），App 每 7 天自动同步一次到本地；
同步失败就用构建时内置的 2024–2031 表兜底，离线也能用。

## 目录

```
app/                 Flutter 工程（web + android）
  lib/               界面与状态机，见 lib/ 下的注释
  lib/services/desktop_bridge*.dart  Windows 桌面模式的桥接（拖动/气泡留白/右键菜单）
  assets/pet/        idle.webp / laugh.webp / egg.webp（透明动画）
  assets/audio/      laugh.mp3 / laugh_full.mp3 / tap.wav
  assets/fonts/      站酷快乐体（OFL）
  web/               manifest、PWA 图标、启动页、flutter_bootstrap.js
  android/.../kotlin/com/tomori/nailong_pet/
    OverlayService.kt   悬浮窗服务（前台服务 + 两个 WindowManager 窗口）
    PetOverlayView.kt   奶龙本体：AnimatedImageDrawable 播动画、Q 弹、拖动
    PetBubbleView.kt    播报卡片（native 绘制）
    BroadcastData.kt    读 calendar.json + 系统日历
    HolidaySync.kt      节假日在线同步（holiday-cn）
    UpdateChecker.kt    GitHub Releases 版本检查
    Prefs.kt            读 Flutter 写的 SharedPreferences（double 是带前缀的字符串）
  android/app/src/main/assets/calendar.json   2024–2031 的农历/节日/调休表
desktop/             Windows 外壳（Electron）
  main.js            透明置顶窗口、托盘、拖动、气泡留白、本地静态服务
  preload.js         给页面注入 desktopDragStart / desktopReserveBubble 等
  run.ps1            从源码跑（会检查并补 Electron 运行时）
  pack.ps1           打绿色版 zip
tools/               素材与构建
  build_assets.py    ffmpeg 裁帧 → rembg 抠图 → 拼段 → WebP / 音频
  make_icons.py      从站立帧生成 App 图标
  build_apk.ps1      打正式版 APK（会先镜像到 C:\nailong_build 绕开中文路径）
docs/design-spec.md  所有已确认的设计决策（改需求先改这里）
dist/                打好的 APK 和 Windows 绿色版
_work/               素材中间产物（可删，删了要重跑 tools/build_assets.py）
```

## 素材管线

```powershell
python tools/build_assets.py key     # rembg 抠 521 帧（约 4 分钟）
python tools/build_assets.py seg     # 拼 idle / laugh / egg
python tools/build_assets.py webp    # 编码 WebP
python tools/build_assets.py audio   # 切笑声、合成点击音
python tools/make_icons.py           # 生成图标
python tools/make_notify_icon.py     # 生成通知栏小图标
cd app && dart run tool/gen_calendar.dart   # 生成 2024–2031 的日历表
```

源视频路径写死在 `tools/build_assets.py` 顶部（`VIDEO`），换素材改那里。

## 打 APK

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_apk.ps1
```

为什么要镜像到 `C:\nailong_build`：项目在中文路径下，Dart 的 AOT 快照器会报
`Unable to read file ... app.dill`，Gradle 里已经用 `android.overridePathCheck=true`
绕过了 AGP 的检查，但 AOT 这一步只能靠纯英文路径。

签名用的是 `android/app/nailong-release.jks`，密码写在 `android/key.properties`：

```
storePassword=<你自己的密码>
keyPassword=<你自己的密码>
keyAlias=nailong
```

**这个 keystore 要留着**，以后升级同一个 App 必须用同一把钥匙，否则只能卸载重装。

## 打 Windows 包

```powershell
cd app; flutter build web --release; cd ..     # 先出 web 构建（Electron 加载的就是它）
cd desktop; .\run.ps1                          # 从源码跑，第一次会自动装 Electron
.\pack.ps1                                     # 打绿色版：dist/windows/NailongPet-win-x64.zip
```

- `desktop/run.ps1` 会检查 `node_modules/electron/dist/electron.exe`，没有就 `npm install`，
  装不上就自动从 npmmirror 拉 zip 解压（国内直连 GitHub 经常失败）
- 这台机器上跑 Electron 要先 `Remove-Item Env:ELECTRON_RUN_AS_NODE`：如果环境里带了这个变量，
  Electron 会退化成纯 Node，`require('electron')` 拿到的是 npm 包路径而不是 API
- 绿色版不用装运行时，解压双击 `NailongPet.exe` 即可；exe 图标还是 Electron 默认的
  （换图标需要 rcedit，没做）

## Android 的实现说明

- 悬浮窗用 `TYPE_APPLICATION_OVERLAY`，宠物窗口接收触摸，气泡窗口不抢焦点
- 动画直接用 `AnimatedImageDrawable` 播 WebP（API 28+）；API 26/27 会退化成静态首帧
- 气泡窗口如果加 `FLAG_NOT_TOUCHABLE`，Android 12+ 会把窗口 alpha 压到 0.8 导致卡片发灰，
  所以改成可点击（点一下就收起）
- 日期/农历/节气来自构建期生成的 `calendar.json`（用同一个 lunar 包算的，和 web 一致），
  避免在 Kotlin 里重写一遍农历算法；法定节假日优先用在线同步的数据覆盖
- 待办读 `CalendarContract.Instances`，查今天起 4 天、最多 9 条
- App 自己的界面在前台时会调 `OverlayService.setAppForeground(true)` 把奶龙收起来
- 宠物窗口比奶龙本身大 1.22 倍，Q 弹放大时头顶才不会被窗口裁掉

## 发到 GitHub / 应用内更新

仓库根目录已经 `git init` 并提交过，`.gitignore` 排除了：

- `app/android/key.properties`、`*.jks`（签名密码，**千万别传**）
- `dist/`、`*.apk`（APK 走 GitHub Releases）
- `_work/`、`_probe/`（几百 MB 的素材中间产物）
- `app/build/`、`.dart_tool/`、`.gradle/` 等构建目录

推送：

```powershell
git remote add origin https://github.com/<你的用户名>/nailong-pet.git
git branch -M main
git push -u origin main
```

**应用内更新**：`UpdateChecker.kt` 里写死了仓库地址，改成你自己的：

```kotlin
const val REPO = "tomori/nailong-pet"
```

App 首页底部有「检查更新」，点一下拉 GitHub Releases 的 latest，比版本号；
有新版就弹窗显示 release notes，点「去 GitHub 下载」跳到 release 页面。

发新版流程：

1. 改 `app/pubspec.yaml` 的 `version: 0.2.0+2`（**+2 是 versionCode，必须递增**）
2. `tools\build_apk.ps1` 重新打包
3. GitHub 建一个 tag `v0.2.0` 的 Release，把 APK 传上去
4. 装旧版的人点「检查更新」就能看到

## 还没做的

1. 全屏视频 / 游戏时自动静音（现在是照常会笑）
2. API 26/27 的动画（只有静态帧）
3. 气泡在奶龙被拖到屏幕顶部时会盖住它（暂时接受）
4. iOS（系统不允许跨 App 悬浮，只能做 App 内桌宠）


