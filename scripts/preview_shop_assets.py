"""Render streak-shield asset candidates onto a dark background for preview."""
from PIL import Image

PAIRS = [
    ("assets/shop/thumbs/streak_shield.webp", "build/bundletool/thumb_view.png"),
    ("assets/shop/full/streak_shield.webp", "build/bundletool/full_view.png"),
]

for src, dst in PAIRS:
    try:
        img = Image.open(src).convert("RGBA")
        bg = Image.new("RGB", img.size, (40, 40, 40))
        bg.paste(img, mask=img.split()[3])
        bg.thumbnail((360, 360))
        bg.save(dst)
        print(f"{src} {img.size} -> {dst}")
    except Exception as e:
        print(f"{src}: ERROR {e}")
