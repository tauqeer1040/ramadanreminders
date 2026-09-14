import io, sys, xml.dom.minidom

SRC = sys.argv[1]
with io.open(SRC, 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
removed = []
for ln in lines:
    # Drop the seed script's inserted lines (wrong tag types / malformed attrs)
    if ('name="flutter.streak"' in ln and ln.lstrip().startswith('<int')) \
       or ('name="flutter.last_activity_date"' in ln and ' value=' in ln) \
       or ('name="flutter.streak_activity_dates"' in ln and ' value=' in ln):
        removed.append(ln.strip())
        continue
    # Flip the app's original long streak 2 -> 4
    if 'name="flutter.streak"' in ln and ln.lstrip().startswith('<long'):
        out.append(ln.replace('value="2"', 'value="4"'))
        continue
    out.append(ln)

with io.open(SRC, 'w', encoding='utf-8') as f:
    f.writelines(out)

# Validate well-formedness before we trust it
xml.dom.minidom.parse(SRC)
print('removed %d bad line(s), streak long flipped to 4, XML well-formed' % len(removed))
for r in removed:
    print('  dropped:', r[:90])
