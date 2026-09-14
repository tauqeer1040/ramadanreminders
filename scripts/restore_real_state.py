import io, sys, re
import xml.dom.minidom as minidom

SRC = sys.argv[1]
UID_KEY = 'flutter.local_trial_start_install_aid:CP2A.260705.006_uid_6BnaJGlRf7Q0U944OIEMSO2aACW2'
ORIGINAL_TRIAL_START = '1789297004390'  # genuine value from the first pull

with io.open(SRC, 'r', encoding='utf-8') as f:
    xml = f.read()

# 1) streak -> 2 (genuine pre-sim value)
out = []
for ln in xml.splitlines(keepends=True):
    if 'name="flutter.streak"' in ln and ln.lstrip().startswith('<long'):
        ln = re.sub(r'value="\d+"', 'value="2"', ln)
    out.append(ln)
xml = ''.join(out)

# 2) last_activity_date -> 2026-09-14 (genuine last journal day)
xml = re.sub(r'<string name="flutter\.last_activity_date">[^<]*</string>',
             '<string name="flutter.last_activity_date">2026-09-14</string>', xml)

# 3) activity dates: drop the injected 2026-09-15 entry (list stored as
#    base64-prefix + !["date",...] with HTML-escaped quotes)
xml = xml.replace('&quot;2026-09-15&quot;,', '').replace(',&quot;2026-09-15&quot;', '')

# 4) uid-scoped trial start -> original (trial active again, no gate)
out = []
done = False
for ln in xml.splitlines(keepends=True):
    if UID_KEY in ln and ('<long' in ln or '<int' in ln):
        tag = 'long' if '<long' in ln else 'int'
        out.append('    <%s name="%s" value="%s" />\n' % (tag, UID_KEY, ORIGINAL_TRIAL_START))
        done = True
    else:
        out.append(ln)
xml = ''.join(out)
if not done:
    xml = xml.replace('</map>', '    <long name="%s" value="%s" />\n</map>' % (UID_KEY, ORIGINAL_TRIAL_START))

with io.open(SRC, 'w', encoding='utf-8') as f:
    f.write(xml)

minidom.parse(SRC)
print('restored: streak=2, last_activity=2026-09-14, dates without 09-15, trial start original. XML OK')
