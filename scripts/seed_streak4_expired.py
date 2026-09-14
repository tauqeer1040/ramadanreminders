import io, sys, datetime, re
import xml.dom.minidom as minidom

SRC = sys.argv[1]
KEY = 'flutter.local_trial_start_install_aid:CP2A.260705.006_uid_6BnaJGlRf7Q0U944OIEMSO2aACW2'
now_ms = int(datetime.datetime.now().timestamp() * 1000)
expired_start = now_ms - 6 * 86400 * 1000

with io.open(SRC, 'r', encoding='utf-8') as f:
    xml = f.read()

# 1) streak -> 4 (flip the app's own long entry, or insert)
if 'name="flutter.streak"' in xml:
    out = []
    for ln in xml.splitlines(keepends=True):
        if 'name="flutter.streak"' in ln and ln.lstrip().startswith('<long'):
            ln = re.sub(r'value="\d+"', 'value="4"', ln)
        out.append(ln)
    xml = ''.join(out)
else:
    xml = xml.replace('</map>', '    <long name="flutter.streak" value="4" />\n</map>')

# 2) last_activity_date -> today
today = datetime.date.today().isoformat()
entry = '<string name="flutter.last_activity_date">%s</string>' % today
if re.search(r'<string name="flutter\.last_activity_date">[^<]*</string>', xml):
    xml = re.sub(r'<string name="flutter\.last_activity_date">[^<]*</string>', entry, xml)
else:
    xml = xml.replace('</map>', '    %s\n</map>' % entry)

# 3) trial start -> 6 days ago (expired past 3d trial + grace)
done = False
out = []
for ln in xml.splitlines(keepends=True):
    if KEY in ln and ('<long' in ln or '<int' in ln):
        tag = 'long' if '<long' in ln else 'int'
        out.append('    <%s name="%s" value="%d" />\n' % (tag, KEY, expired_start))
        done = True
    else:
        out.append(ln)
xml = ''.join(out)
if not done:
    xml = xml.replace('</map>', '    <long name="%s" value="%d" />\n</map>' % (KEY, expired_start))

with io.open(SRC, 'w', encoding='utf-8') as f:
    f.write(xml)

minidom.parse(SRC)
print('seeded: streak=4, last_activity=%s, trial_start=6d ago (EXPIRED). XML OK' % today)
