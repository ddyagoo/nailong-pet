"""Build 奶龙 desk-pet assets from the source screen recording.

Stages
------
key    : cut every frame out of the white studio background (rembg u2netp)
seg    : assemble playback clips (idle loop / 6s laugh / full easter egg)
audio  : slice + normalise the laugh track, synthesise the tap sound
webp   : encode the clips as animated WebP into the Flutter asset folder
all    : key -> seg -> webp -> audio
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FRAMES = ROOT / "_work" / "frames"          # cropped 660x860 source frames
KEYED = ROOT / "_work" / "keyed"
CLIPS = ROOT / "_work" / "clips"
ASSETS = ROOT / "app" / "assets" / "pet"
AUDIO = ROOT / "app" / "assets" / "audio"
# 源视频自己放：默认读环境变量 NAILONG_VIDEO，没有就用 _work/source.mp4
VIDEO = Path(os.environ.get("NAILONG_VIDEO", ROOT / "_work" / "source.mp4"))

FPS = 30
# Source timeline (seconds) measured from the recording.
IDLE_END = 1.50
LAUGH_START = 1.60
LAUGH_PEAK_END = 7.60
FALL_START = 12.30
FALL_END = 13.40
LYING_END = 17.30
EGG_END = 17.43  # 源视频在这里硬切回站立，恰好是 idle 首帧的姿态

OUT_W = 560  # display width of the sprite in physical pixels


def f2i(t: float) -> int:
    return int(round(t * FPS))


def stage_key() -> None:
    os.environ.setdefault("HTTP_PROXY", "http://127.0.0.1:7897")
    os.environ.setdefault("HTTPS_PROXY", "http://127.0.0.1:7897")
    from rembg import new_session, remove

    KEYED.mkdir(parents=True, exist_ok=True)
    src = sorted(FRAMES.glob("f_*.png"))
    if not src:
        sys.exit(f"no frames in {FRAMES}")
    session = new_session("u2netp")
    done = 0
    for p in src:
        out = KEYED / p.name
        if out.exists() and out.stat().st_size > 0:
            continue
        im = Image.open(p).convert("RGB")
        cut = remove(im, session=session)
        cut.save(out)
        done += 1
        if done % 25 == 0:
            print(f"keyed {done}/{len(src)}", flush=True)
    print(f"key stage done, {done} new frames", flush=True)


def _bbox(im: Image.Image, thr: int = 8) -> tuple[int, int, int, int]:
    a = np.asarray(im)
    alpha = a[..., 3] > thr
    ys, xs = np.nonzero(alpha)
    if len(xs) == 0:
        return (0, 0, im.width, im.height)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def decontaminate(im: Image.Image) -> Image.Image:
    """去掉白底在边缘留下的灰边。

    抠图得到的半透明像素仍然是「主体色 × alpha + 白 × (1-alpha)」，
    直接叠到暖色壁纸上会看到一圈灰白。按 alpha 反解出主体色即可。
    """
    a = np.asarray(im).astype(np.float32)
    alpha = a[..., 3:4] / 255.0
    rgb = a[..., :3]
    edge = (alpha[..., 0] > 0.03) & (alpha[..., 0] < 0.985)
    safe = np.maximum(alpha, 0.03)
    fixed = (rgb - (1.0 - alpha) * 255.0) / safe
    out = np.where(edge[..., None], fixed, rgb)
    merged = np.concatenate([np.clip(out, 0, 255), a[..., 3:4]], axis=2)
    return Image.fromarray(merged.astype(np.uint8), "RGBA")


def stage_seg() -> None:
    """Assemble clips on a shared canvas."""
    CLIPS.mkdir(parents=True, exist_ok=True)
    files = sorted(KEYED.glob("f_*.png"))
    if not files:
        sys.exit("run key first")

    # shared canvas: union of content boxes over every frame, padded
    union = [10**9, 10**9, -1, -1]
    for p in files[::6]:
        im = Image.open(p)
        b = _bbox(im)
        union[0] = min(union[0], b[0]); union[1] = min(union[1], b[1])
        union[2] = max(union[2], b[2]); union[3] = max(union[3], b[3])
    pad = 6
    box = (max(0, union[0] - pad), max(0, union[1] - pad),
           min(files[0].width if False else 660, union[2] + pad),
           min(860, union[3] + pad))
    print("canvas box", box)

    def load(i: int) -> Image.Image:
        im = Image.open(files[i]).convert("RGBA").crop(box)
        return decontaminate(im)

    def scale(im: Image.Image) -> Image.Image:
        """预乘 alpha 再缩放，否则透明区残留的白色会渗进边缘形成灰边。"""
        a = np.asarray(im).astype(np.float32)
        al = a[..., 3:4] / 255.0
        pre = np.concatenate([a[..., :3] * al, a[..., 3:4]], axis=2)
        tmp = Image.fromarray(np.clip(pre, 0, 255).astype(np.uint8), "RGBA")
        w, h = tmp.size
        small = tmp.resize((OUT_W, round(h * OUT_W / w)), Image.LANCZOS)
        b = np.asarray(small).astype(np.float32)
        a2 = np.maximum(b[..., 3:4] / 255.0, 1e-3)
        rgb = b[..., :3] / a2
        merged = np.concatenate([np.clip(rgb, 0, 255), b[..., 3:4]], axis=2)
        return Image.fromarray(merged.astype(np.uint8), "RGBA")

    def comp(a: np.ndarray, b: np.ndarray, t: float) -> np.ndarray:
        """Crossfade two straight-alpha RGBA arrays in premultiplied space."""
        a = a.astype(np.float32) / 255.0
        b = b.astype(np.float32) / 255.0
        aa = a[..., 3:4]; ba = b[..., 3:4]
        ac = a[..., :3] * aa; bc = b[..., :3] * ba
        oa = aa * (1 - t) + ba * t
        oc = ac * (1 - t) + bc * t
        rgb = np.where(oa > 1e-4, oc / np.maximum(oa, 1e-4), 0.0)
        out = np.concatenate([rgb, oa], axis=2)
        return (np.clip(out, 0, 1) * 255).astype(np.uint8)

    idle_end = f2i(IDLE_END)
    laugh_start = f2i(LAUGH_START)
    peak_end = f2i(LAUGH_PEAK_END)
    lying_end = f2i(LYING_END)

    # ---- idle: 0 .. 1.5s, ping-ponged for a seamless loop ----
    idle_idx = list(range(0, idle_end))
    idle = [load(i) for i in idle_idx]
    idle = idle + idle[-2:0:-1]
    idle = [scale(im) for im in idle]
    for n, im in enumerate(idle):
        im.save(CLIPS / ("idle_%04d.png" % n))
    print("idle frames", len(idle))

    # ---- laugh: 1.6 .. 7.6s。
    #      最后一帧仍然是笑到一半的姿势，切回 idle 的衔接交给 App 里的
    #      「Q 弹回位」动画遮住（直接交叉淡化会变成双重曝光，试过不行）。 ----
    laugh = [scale(load(i)) for i in range(laugh_start, peak_end)]
    for n, im in enumerate(laugh):
        im.save(CLIPS / ("laugh_%04d.png" % n))
    print("laugh frames", len(laugh))

    # ---- egg: 完整段。源视频 17.43 处的硬切正好落回站立姿态，
    #      与 idle 首帧几乎完全一致，所以这里不需要再合成起身动作。 ----
    egg = [scale(load(i)) for i in range(laugh_start, f2i(EGG_END))]
    for n, im in enumerate(egg):
        im.save(CLIPS / ("egg_%04d.png" % n))
    print("egg frames", len(egg))


def _encode(name: str, frames: list[Image.Image], fps: float,
            quality: int = 76) -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    out = ASSETS / f"{name}.webp"
    frames[0].save(
        out, "WEBP", save_all=True, append_images=frames[1:],
        duration=int(round(1000 / fps)), loop=0, quality=quality,
        method=6, alpha_quality=60, minimize_size=True,
    )
    print(f"{out.name}: {len(frames)} frames @ {fps:g}fps, "
          f"{out.stat().st_size/1e3:.0f} kB")


def _resample(name: str, fps: float) -> list[Image.Image]:
    """Take a clip folder and resample it from 30fps to *fps*."""
    files = sorted(CLIPS.glob(f"{name}_*.png"))
    if not files:
        sys.exit(f"run seg first (no {name}_*.png)")
    step = FPS / fps
    frames: list[Image.Image] = []
    k = 0
    while True:
        idx = int(round(k * step))
        if idx >= len(files):
            break
        frames.append(Image.open(files[idx]).convert("RGBA"))
        k += 1
    return frames


def stage_webp() -> None:
    # 笑声动作快，保 24fps；彩蛋很少播，20fps 省体积。
    for name, (fps, quality) in {"laugh": (24, 78), "egg": (20, 76)}.items():
        _encode(name, _resample(name, fps), fps, quality)


def stage_eyes() -> None:
    """待机：源视频 0–1.5s 正放 + 倒放。

    这一整段 2.93 秒里身体不动、眼皮和眼珠在动，第一版就是拿它循环的。
    现在仍然用整段（观感才对），只是不再循环播放——由 App 用随机间隔
    「播一次 → 停一会儿 → 再播」，节奏不再固定。
    """
    _encode("idle", _resample("idle", 15), 15)

    # 清掉上一版拆出来的小片段，别让它们继续被打进包里
    for stale in ("blink", "blink2", "glance"):
        p = ASSETS / f"{stale}.webp"
        if p.exists():
            p.unlink()
            print(f"removed stale {p.name}")


def _run(cmd: list[str]) -> None:
    import subprocess
    subprocess.run(cmd, check=True)


def stage_audio() -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    ff = "ffmpeg"

    # short laugh: same window as the 6s clip, fade the cut
    _run([ff, "-v", "error", "-y", "-ss", str(LAUGH_START), "-to", str(LAUGH_PEAK_END),
          "-i", str(VIDEO), "-vn",
          "-af", "afade=t=in:st=0:d=0.08,afade=t=out:st=5.55:d=0.45,volume=0.9",
          "-ac", "1", "-c:a", "libmp3lame", "-b:a", "96k", str(AUDIO / "laugh.mp3")])
    # full laugh
    _run([ff, "-v", "error", "-y", "-ss", "1.68", "-to", "17.28",
          "-i", str(VIDEO), "-vn",
          "-af", "afade=t=in:st=0:d=0.08,afade=t=out:st=14.9:d=0.6,volume=0.9",
          "-ac", "1", "-c:a", "libmp3lame", "-b:a", "96k", str(AUDIO / "laugh_full.mp3")])

    # tap "boing": quick pitch drop + soft envelope
    sr = 44100
    dur = 0.16
    t = np.arange(int(sr * dur)) / sr
    f0, f1 = 720.0, 240.0
    phase = 2 * np.pi * (f0 * t + (f1 - f0) * t ** 2 / (2 * dur))
    env = np.exp(-t * 26) * np.minimum(1, t / 0.004)
    sig = 0.55 * np.sin(phase) * env + 0.18 * np.sin(2 * phase) * env
    pcm = (np.clip(sig, -1, 1) * 32767).astype("<i2")
    import wave
    with wave.open(str(AUDIO / "tap.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(pcm.tobytes())

    for p in sorted(AUDIO.glob("*.wav")):
        print(p.name, f"{p.stat().st_size/1e3:.0f} kB")


STAGES = {
    "key": stage_key,
    "seg": stage_seg,
    "webp": stage_webp,
    "eyes": stage_eyes,
    "audio": stage_audio,
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage", nargs="+", choices=[*STAGES, "all"])
    args = ap.parse_args()
    names = list(STAGES) if "all" in args.stage else args.stage
    for n in names:
        print(f"== {n} ==", flush=True)
        STAGES[n]()


if __name__ == "__main__":
    main()
