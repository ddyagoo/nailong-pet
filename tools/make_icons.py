"""Generate the app icon / PWA icons from a keyed idle frame."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "_work" / "keyed" / "f_0001.png"
OUT = ROOT / "app" / "web" / "icons"
APP = ROOT / "app"


def head() -> Image.Image:
    """整个站姿（去掉透明留白），更适合做图标主体。"""
    im = Image.open(SRC).convert("RGBA")
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a > 8)
    box = (max(0, xs.min() - 4), max(0, ys.min() - 4),
           min(im.width, xs.max() + 4), min(im.height, ys.max() + 4))
    return im.crop(box)


def rounded_mask(size: int, radius: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius, fill=255)
    return m


def make_icon(size: int, *, maskable: bool) -> Image.Image:
    ss = 4  # 超采样
    w = size * ss
    canvas = Image.new("RGBA", (w, w), (0, 0, 0, 0))

    bg = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    grad = Image.new("RGBA", (w, w))
    top = np.array([255, 214, 120], dtype=np.float32)
    bot = np.array([242, 154, 48], dtype=np.float32)
    for y in range(w):
        t = y / max(1, w - 1)
        c = (top * (1 - t) + bot * t).astype(np.uint8)
        ImageDraw.Draw(grad).line([(0, y), (w, y)], fill=tuple(int(v) for v in c) + (255,))
    bg.paste(grad, (0, 0))

    # 一点点柔光
    glow = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        (int(w * 0.45), int(-w * 0.25), int(w * 1.15), int(w * 0.55)),
        fill=(255, 245, 210, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.08))
    bg = Image.alpha_composite(bg, glow)

    h = head()
    target_h = int(w * (0.54 if maskable else 0.60))
    ratio = target_h / h.height
    h = h.resize((int(h.width * ratio), target_h), Image.LANCZOS)

    # 地面阴影
    sh = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse(
        (int(w * 0.30), int(w * 0.75), int(w * 0.70), int(w * 0.85)),
        fill=(120, 70, 10, 60))
    sh = sh.filter(ImageFilter.GaussianBlur(w * 0.03))
    bg = Image.alpha_composite(bg, sh)

    px = (w - h.width) // 2
    py = int(w * 0.80) - h.height
    bg.alpha_composite(h, (px, py))

    # 描一圈奶油色内边
    ring = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle(
        (int(w * 0.035), int(w * 0.035), int(w * 0.965), int(w * 0.965)),
        radius=int(w * 0.22), outline=(255, 248, 232, 150), width=max(2, int(w * 0.008)))
    bg = Image.alpha_composite(bg, ring)

    if maskable:
        out = bg
    else:
        out = Image.new("RGBA", (w, w), (0, 0, 0, 0))
        out.paste(bg, (0, 0), rounded_mask(w, int(w * 0.22)))

    return out.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for size in (192, 512):
        make_icon(size, maskable=False).save(OUT / f"Icon-{size}.png")
        make_icon(size, maskable=True).save(OUT / f"Icon-maskable-{size}.png")
    make_icon(64, maskable=False).save(ROOT / "app" / "web" / "favicon.png")
    # Android 启动图标
    res = APP / "android" / "app" / "src" / "main" / "res"
    if res.exists():
        for folder, size in {
            "mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
            "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192,
        }.items():
            d = res / folder
            d.mkdir(parents=True, exist_ok=True)
            make_icon(size, maskable=False).save(d / "ic_launcher.png")
    print("icons written")


if __name__ == "__main__":
    main()
