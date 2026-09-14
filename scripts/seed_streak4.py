import io, sys, datetime, re
import xml.dom.minidom as minidom

SRC = sys.argv[1]
now_ms = int(datetime.datetime.now().timestamp() * 1000)

with io.open(SRC, 'r', encoding='utf-8') as f:
    xml = f.read()

# 1) Streak: flip the app's own long entry (2 -> 4) or insert if absent.
if 'name="flutter.streak"' in xml:
    out = []
    for ln in xml.splitlines(keepends=True):
        if 'name="flutter.streak"' in ln and ln.lstrip().startswith('<long'):
            ln = ln.replace('value="2"', 'value="4"')
        out.append(ln)
    xml = ''.join(out)
else:
    xml = xml.replace('</map>', '    <long name="flutter.streak" value="4" />\n</map>')

# 2) Today's activity date (string element form the app writes).
today = datetime.date.today().isoformat()
import re
pat = re.compile(r'<string name="flutter\.last_activity_date">[^<]*</string>')
entry = '<string name="flutter.last_activity_date">%s</string>' % today
if pat.search(xml):
    xml = pat.sub(entry, xml)
else:
    xml = xml.replace('</map>', '    %s\n</map>' % entry)

with io.open(SRC, 'w', encoding='utf-8') as f:
    f.write(xml)

minidom.parse(SRC)
print('seeded streak=4, last_activity_date=%s, XML OK' % today)
