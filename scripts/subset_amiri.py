#!/usr/bin/env python3
"""Subset Amiri-Regular.ttf to Arabic + basic Latin + common punctuation."""
import os
from fontTools.subset import Subsetter, Options
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'fonts', 'Amiri-Regular.ttf')
DST = os.path.join(ROOT, 'assets', 'fonts', 'Amiri-Regular.subset.ttf')

# Characters to keep:
# - Basic Latin (space, digits, punctuation): U+0020 - U+007E
# - Arabic block: U+0600 - U+06FF
# - Arabic Supplement: U+0750 - U+077F
# - Arabic Extended-A: U+08A0 - U+08FF
# - Arabic Presentation Forms-B: U+FE70 - U+FEFF
# - Common punctuation used with Arabic text

chars = set()
# Basic Latin (printable ASCII)
for i in range(0x20, 0x7F):
    chars.add(i)
# Arabic blocks
for i in range(0x0600, 0x0700):
    chars.add(i)
for i in range(0x0750, 0x0780):
    chars.add(i)
for i in range(0x08A0, 0x0900):
    chars.add(i)
# Arabic Presentation Forms-B (needed for proper rendering)
for i in range(0xFE70, 0xFF00):
    chars.add(i)
# Additional punctuation
for c in [0x200C, 0x200D, 0x200E, 0x200F, 0x2010, 0x2013, 0x2014, 0x2018,
          0x2019, 0x201C, 0x201D, 0x2026, 0x002E, 0x002C, 0x003A, 0x003B,
          0x0021, 0x003F, 0x0028, 0x0029, 0x005B, 0x005D, 0x007B, 0x007D,
          0x002F, 0x005C, 0x002D, 0x005F, 0x002B, 0x003D, 0x002A, 0x0023,
          0x0024, 0x0025, 0x0026, 0x0040, 0x005E, 0x007E]:
    chars.add(c)

options = Options()
options.desubroutinize = True
options.layout_features = ['*']  # keep all OpenType layout features for Arabic shaping

font = TTFont(SRC)
subsetter = Subsetter(options=options)
subsetter.populate(unicodes=chars)
subsetter.subset(font)
font.save(DST)
font.close()

orig = os.path.getsize(SRC)
new = os.path.getsize(DST)
print(f'Original: {orig / 1024:.1f} KB -> Subset: {new / 1024:.1f} KB '
      f'({(1 - new / orig) * 100:.0f}% reduction)')
print(f'Output: {DST}')
