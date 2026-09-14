"""Streak-shield artwork: baked neutral-grey background -> transparency.

Keeps only the border-connected, low-saturation region (the backdrop wash,
including the bright top glow). Saturated orb/flame/glow pixels survive even
when dark. Edge feathered to avoid halo fringe. Originals backed up to /tmp
before first run (see task log); this script overwrites the webps in place.
"""
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

SRC = ['assets/shop/thumbs/streak_shield.webp',
       'assets/shop/full/streak_shield.webp']

SAT_TOL = 38      # max-min RGB below this => "grey"
DARK_FLOOR = 18   # below this luminance => keep (orb interior shadows)
FEATHER = 2.0     # px blur on the cutout mask


def cutout(path):
    img = Image.open(path).convert('RGB')
    a = np.asarray(img).astype(np.int16)
    mx, mn = a.max(axis=2), a.min(axis=2)
    lum = a.mean(axis=2)
    grey = (mx - mn < SAT_TOL) & (lum >= DARK_FLOOR)

    h, w = grey.shape
    # border-connected flood (4-neighbourhood) over grey pixels only
    seen = np.zeros_like(grey, dtype=bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if grey[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if grey[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        if y > 0 and grey[y - 1, x] and not seen[y - 1, x]:
            seen[y - 1, x] = True; dq.append((y - 1, x))
        if y + 1 < h and grey[y + 1, x] and not seen[y + 1, x]:
            seen[y + 1, x] = True; dq.append((y + 1, x))
        if x > 0 and grey[y, x - 1] and not seen[y, x - 1]:
            seen[y, x - 1] = True; dq.append((y, x - 1))
        if x + 1 < w and grey[y, x + 1] and not seen[y, x + 1]:
            seen[y, x + 1] = True; dq.append((y, x + 1))
    cut = int(seen.sum())
    print(f'{path}: {w}x{h} cut {cut} px ({100.0 * cut / (w * h):.1f}%)')

    mask = Image.fromarray((~seen).astype(np.uint8) * 255, 'L')
    mask = mask.filter(ImageFilter.GaussianBlur(FEATHER))
    out = img.convert('RGBA')
    out.putalpha(mask)
    out.save(path, 'WEBP', lossless=True, quality=100, method=6)
    print(f'  saved RGBA webp')


if __name__ == '__main__':
    for p in SRC:
        cutout(p)
