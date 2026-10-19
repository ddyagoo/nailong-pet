// 奶龙桌宠 · Windows 外壳
//
// 复用 Flutter 的 web 构建：一个透明、无边框、置顶的窗口放奶龙，
// 另一个普通窗口放设置（就是 Flutter 那套界面）。
const { app, BrowserWindow, Tray, Menu, ipcMain, screen, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const http = require('http');

const DESKTOP_DIR = __dirname;
// 打包后 web 构建会被拷到 resources/app/web；开发时直接用 app/build/web
const WEB_ROOT = fs.existsSync(path.join(DESKTOP_DIR, 'web', 'index.html'))
  ? path.join(DESKTOP_DIR, 'web')
  : path.join(DESKTOP_DIR, '..', 'app', 'build', 'web');
const PREFERRED_PORT = 17878;
const BASE_W = 360;
const BASE_H = 400;
const BUBBLE_EXTRA = 380;

let petWin = null;
let settingsWin = null;
let tray = null;
let server = null;
let baseUrl = '';
let dragTimer = null;
let savePath = '';
const isDemo = process.argv.includes('--demo');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.ico': 'image/x-icon',
};

function clampi(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}

function loadPos() {
  try {
    const raw = fs.readFileSync(savePath, 'utf8');
    const p = JSON.parse(raw);
    if (typeof p.x === 'number' && typeof p.y === 'number') return p;
  } catch (_) {}
  return null;
}

function savePos() {
  if (!petWin) return;
  try {
    const [x, y] = petWin.getPosition();
    fs.writeFileSync(savePath, JSON.stringify({ x, y }));
  } catch (_) {}
}

function startServer() {
  return new Promise((resolve, reject) => {
    const handler = (req, res) => {
      let pathname = '/';
      try {
        pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
      } catch (_) {}
      if (pathname === '/') pathname = '/index.html';
      const file = path.normalize(path.join(WEB_ROOT, pathname));
      if (!file.startsWith(WEB_ROOT)) {
        res.writeHead(403);
        res.end('forbidden');
        return;
      }
      fs.stat(file, (err, stat) => {
        if (err || !stat.isFile()) {
          res.writeHead(404);
          res.end('not found');
          return;
        }
        res.writeHead(200, {
          'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream',
          'Cache-Control': 'no-store',
        });
        fs.createReadStream(file).pipe(res);
      });
    };

    server = http.createServer(handler);
    server.on('error', (e) => {
      if (e.code === 'EADDRINUSE') {
        // 端口被占就换一个（当然 localStorage 会跟着换，属于极端情况）
        server.listen(0, '127.0.0.1', () => {
          baseUrl = `http://127.0.0.1:${server.address().port}`;
          resolve();
        });
      } else {
        reject(e);
      }
    });
    server.listen(PREFERRED_PORT, '127.0.0.1', () => {
      baseUrl = `http://127.0.0.1:${server.address().port}`;
      resolve();
    });
  });
}

function createPetWindow() {
  const wa = screen.getPrimaryDisplay().workArea;
  const saved = loadPos();
  const x = saved ? saved.x : wa.x + wa.width - BASE_W - 28;
  const y = saved ? saved.y : wa.y + wa.height - BASE_H - 28;

  petWin = new BrowserWindow({
    width: BASE_W,
    height: BASE_H,
    x,
    y,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    hasShadow: false,
    resizable: false,
    maximizable: false,
    minimizable: false,
    fullscreenable: false,
    skipTaskbar: true,
    alwaysOnTop: true,
    focusable: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      backgroundThrottling: false,
    },
  });

  petWin.setAlwaysOnTop(true, 'screen-saver');
  petWin.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  petWin.loadURL(baseUrl + '/?desktop=1');
  petWin.on('closed', () => {
    petWin = null;
  });
}

function openSettings() {
  if (settingsWin) {
    settingsWin.show();
    settingsWin.focus();
    return;
  }
  settingsWin = new BrowserWindow({
    width: 460,
    height: 800,
    title: '奶龙桌宠 · 设置',
    backgroundColor: '#FFF3DC',
    icon: path.join(__dirname, 'assets', 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
    },
  });
  settingsWin.setMenuBarVisibility(false);
  settingsWin.loadURL(baseUrl + '/');
  settingsWin.on('closed', () => {
    settingsWin = null;
    // 设置写的是同一个 origin 的 localStorage，重载奶龙让它读新值
    if (petWin) petWin.webContents.reload();
  });
}

function buildContextMenu() {
  return Menu.buildFromTemplate([
    { label: '打开设置…', click: openSettings },
    { type: 'separator' },
    {
      label: '显示奶龙',
      click: () => {
        if (petWin) {
          petWin.show();
        }
      },
    },
    {
      label: '先藏起来',
      click: () => {
        if (petWin) petWin.hide();
      },
    },
    { type: 'separator' },
    { label: '退出奶龙', click: () => app.quit() },
  ]);
}

function createTray() {
  const icon = path.join(__dirname, 'assets', 'icon.png');
  try {
    tray = new Tray(icon);
  } catch (_) {
    return;
  }
  tray.setToolTip('奶龙桌宠');
  tray.setContextMenu(
    Menu.buildFromTemplate([
      { label: '打开设置…', click: openSettings },
      {
        label: '显示 / 隐藏奶龙',
        click: () => {
          if (!petWin) return;
          if (petWin.isVisible()) petWin.hide();
          else petWin.show();
        },
      },
      { type: 'separator' },
      { label: '退出', click: () => app.quit() },
    ]),
  );
  tray.on('click', () => {
    if (petWin) petWin.isVisible() ? petWin.hide() : petWin.show();
  });
}

// ---------------- IPC ----------------

ipcMain.on('pet:dragStart', () => {
  if (!petWin) return;
  const start = screen.getCursorScreenPoint();
  const [wx, wy] = petWin.getPosition();
  if (dragTimer) clearInterval(dragTimer);
  dragTimer = setInterval(() => {
    if (!petWin) return;
    const p = screen.getCursorScreenPoint();
    const bounds = petWin.getBounds();
    const wa = screen.getDisplayNearestPoint(p).workArea;
    const nx = clampi(wx + (p.x - start.x), wa.x - 60, wa.x + wa.width - bounds.width + 60);
    const ny = clampi(wy + (p.y - start.y), wa.y - 20, wa.y + wa.height - bounds.height + 20);
    petWin.setPosition(Math.round(nx), Math.round(ny));
  }, 16);
});

ipcMain.on('pet:dragEnd', () => {
  if (dragTimer) clearInterval(dragTimer);
  dragTimer = null;
  savePos();
});

ipcMain.on('pet:reserve', (_e, visible) => {
  if (!petWin) return;
  const b = petWin.getBounds();
  const targetH = visible ? BASE_H + BUBBLE_EXTRA : BASE_H;
  if (b.height === targetH) return;
  const delta = targetH - b.height;
  const wa = screen.getDisplayNearestPoint({ x: b.x, y: b.y }).workArea;
  const ny = clampi(b.y - delta, wa.y, wa.y + wa.height - targetH);
  petWin.setBounds({ x: b.x, y: Math.round(ny), width: b.width, height: targetH });
});

ipcMain.on('pet:menu', () => {
  if (!petWin) return;
  buildContextMenu().popup({ window: petWin });
});

// ---------------- 启动 ----------------

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (petWin) {
      petWin.show();
      petWin.focus();
    }
  });

  app.whenReady().then(async () => {
    savePath = path.join(app.getPath('userData'), 'pet-window.json');
    app.setAppUserModelId('com.tomori.nailong_pet');
    await startServer();
    createPetWindow();
    createTray();

    if (isDemo) {
      setTimeout(() => {
        if (!petWin) return;
        const b = petWin.getBounds();
        const x = Math.round(b.width / 2);
        const y = Math.round(b.height - 120);
        petWin.webContents.sendInputEvent({ type: 'mouseDown', x, y, button: 'left', clickCount: 1 });
        petWin.webContents.sendInputEvent({ type: 'mouseUp', x, y, button: 'left', clickCount: 1 });
      }, 6000);
      setTimeout(async () => {
        if (!petWin) return;
        const img = await petWin.capturePage();
        fs.writeFileSync(path.join(__dirname, 'demo-shot.png'), img.toPNG());
        app.quit();
      }, 9500);
    }
  });

  app.on('window-all-closed', () => {
    // 有托盘，关掉窗口不退出
  });

  app.on('before-quit', () => {
    if (dragTimer) clearInterval(dragTimer);
    if (server) server.close();
  });
}

// 阻止页面里点链接跑出应用
app.on('web-contents-created', (_e, contents) => {
  contents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
});
