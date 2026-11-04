#!/usr/bin/env python3
"""Бесплатные скриншоты окна Roblox Studio (KDE Wayland: Spectacle снимает экран, вырезаем окно Studio).

    python3 tools/shot.py [имя] [--count N] [--every СЕК] [--delay СЕК] [--width ПИКС]

Studio должна быть видна (пользователь держит её на втором мониторе). Полный снимок экрана сразу удаляется —
остаётся только область окна Studio: build/shots/<имя>.png или <имя>_01.png… для серии (кадры «демки»).
Во время плейтеста запускать в фоне, камеру ставит клиентский сценарий (Camera Scriptable).
"""
import argparse
import os
import subprocess
import tempfile
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "shots"


def studio_rect():
    """(x, y, w, h) самого большого окна Studio в координатах экрана."""
    ids = subprocess.run(["xdotool", "search", "--name", "Roblox Studio"], capture_output=True, text=True).stdout.split()
    best = None
    for wid in ids:
        info = subprocess.run(["xdotool", "getwindowgeometry", wid], capture_output=True, text=True).stdout
        pos = size = None
        for line in info.splitlines():
            line = line.strip()
            if line.startswith("Position:"):
                pos = [int(v) for v in line.split()[1].split(",")]
            elif line.startswith("Geometry:"):
                size = [int(v) for v in line.split()[1].split("x")]
        if pos and size and (best is None or size[0] * size[1] > best[2] * best[3]):
            best = (pos[0], pos[1], size[0], size[1])
    if not best or best[2] < 400:
        raise SystemExit("окно Roblox Studio не найдено")
    return best


REF = Path(__file__).resolve().parent / "studio_ref.png"


def looks_like_studio(im) -> bool:
    ref = Image.open(REF).convert("L")
    probe = im.convert("L").resize((1280, round(im.height * 1280 / im.width))).crop((0, 0, ref.width, ref.height))
    diff = sum(abs(a - b) for a, b in zip(probe.getdata(), ref.getdata())) / (ref.width * ref.height)
    return diff < 18


def grab(dst: Path, rect, width: int):
    fd, tmp = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    try:
        subprocess.run(["spectacle", "-b", "-n", "-f", "-o", tmp], check=True, timeout=20,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            im = Image.open(tmp)
            im.load()
        except Exception:
            return False
        x, y, w, h = rect
        im = im.crop((x, y, x + w, y + h))
        # Studio сверху? Левый верхний угол (меню «File Edit View…») сравниваем с образцом tools/studio_ref.png.
        # Если окно закрыто чем-то другим — кадр не сохраняем (на экране могут быть личные окна пользователя)
        if not looks_like_studio(im):
            return False
        # только 3D-вид Studio: справа поверх окна бывают личные окна пользователя (мессенджеры) — отрезаем
        W, H = im.size
        im = im.crop((int(W * 0.005), int(H * 0.075), int(W * 0.78), int(H * 0.925)))
        if im.width > width:
            im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        im.convert("RGB").save(dst)
        return True
    finally:
        os.remove(tmp)  # весь экран не храним


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name", nargs="?", default="studio")
    ap.add_argument("--count", type=int, default=1)
    ap.add_argument("--every", type=float, default=1.0)
    ap.add_argument("--delay", type=float, default=0.0)
    ap.add_argument("--width", type=int, default=1600)
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    time.sleep(a.delay)
    rect = studio_rect()
    for i in range(a.count):
        t0 = time.time()
        dst = OUT / (f"{a.name}.png" if a.count == 1 else f"{a.name}_{i + 1:02d}.png")
        if grab(dst, rect, a.width):
            print(dst, flush=True)
        else:
            print("SKIP: Studio не видна (закрыта другим окном) — кадр не сохранён", flush=True)
        if i + 1 < a.count:
            time.sleep(max(0.0, a.every - (time.time() - t0)))


if __name__ == "__main__":
    main()
