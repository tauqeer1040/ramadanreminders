"""Regenerate the stale streak-shield thumbnail from the fresh full artwork."""
from PIL import Image

SRC = "assets/shop/full/streak_shield.webp"
DST = "assets/shop/thumbs/streak_shield.webp"

img = Image.open(SRC).convert("RGBA")
# Match the original thumb dimensions (300x200), high-quality downscale.
thumb = img.resize((300, 200), Image.LANCZOS)
thumb.save(DST, "WEBP", lossless=True, quality=100, method=6)
print(f"wrote {DST} {thumb.size}, mode={thumb.mode}")
