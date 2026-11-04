#!/usr/bin/env python3
"""Group gallery screenshots by the yellow aura label and build 3x3 contact sheets (one frame per aura).

    python3 tools/gallery_sheets.py <prefix> <out-name>
"""
import glob
import sys

from PIL import Image

prefix, out = sys.argv[1], sys.argv[2]
fs = sorted(glob.glob(f"build/shots/{prefix}_*.png"))
groups, last = [], None
for f in fs:
    im = Image.open(f).convert("RGB")
    w, h = im.size
    reg = im.crop((0, int(h * 0.15), int(w * 0.4), int(h * 0.27))).resize((200, 36))
    bits = [1 if (r > 180 and g > 180 and b < 90) else 0 for r, g, b in reg.getdata()]
    if sum(bits) < 20:
        continue
    if last is not None and sum(a != b for a, b in zip(bits, last)) < 30:
        groups[-1].append(f)
    else:
        groups.append([f])
    last = bits
print(len(groups), "auras")
picks = [g[-1] for g in groups]
tw = 520
for k in range(0, len(picks), 9):
    ims = [Image.open(f) for f in picks[k:k + 9]]
    th = round(ims[0].height * tw / ims[0].width)
    sheet = Image.new("RGB", (tw * 3, th * 3))
    for i, im in enumerate(ims):
        sheet.paste(im.resize((tw, th)), ((i % 3) * tw, (i // 3) * th))
    name = f"build/{out}_{k // 9}.jpg"
    sheet.save(name, quality=88)
    print(name)
