"""生成通知栏用的单色小图标（白色剪影）。"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "_work" / "keyed" / "f_0001.png"
OUT = ROOT / "app" / "android" / "app" / "src" / "main" / "res" / "drawable"


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a > 8)
    crop = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

    canvas = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    target_h = 84
    ratio = target_h / crop.height
    resized = crop.resize((int(crop.width * ratio), target_h), Image.LANCZOS)

    alpha = resized.split()[3]
    white = Image.new("RGBA", resized.size, (255, 255, 255, 0))
    white.putalpha(alpha)

    x = (96 - resized.width) // 2
    y = (96 - resized.height) // 2
    canvas.alpha_composite(white, (x, y))

    OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT / "ic_notify.png")
    print("wrote", OUT / "ic_notify.png")


if __name__ == "__main__":
    main()
