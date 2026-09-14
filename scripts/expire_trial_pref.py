import io, re, sys, datetime, xml.dom.minidom

SRC = sys.argv[1]
KEY = 'flutter.local_trial_start_install_aid:CP2A.260705.006_uid_6BnaJGlRf7Q0U944OIEMSO2aACW2'

now_ms = int(datetime.datetime.now().timestamp() * 1000)
expired_start = now_ms - 6 * 86400 * 1000  # 6 days ago: 3d trial + 3d grace gone

with io.open(SRC, 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
done = False
for ln in lines:
    if KEY in ln and ('<long' in ln or '<int' in ln):
        tag = 'long' if '<long' in ln else 'int'
        m = re.search(r'value="(\d+)"', ln)
        old = m.group(1) if m else '?'
        out.append('    <%s name="%s" value="%d" />\n' % (tag, KEY, expired_start))
        done = True
        age_h = (now_ms - int(old)) / 3600000.0 if m else -1
        print('trial start: %s (%.1fh ago) -> %d (6d ago) [tag=%s]' % (old, age_h, expired_start, tag))
    else:
        out.append(ln)

if not done:
    print('ERROR: trial start key not found')
    sys.exit(1)

with io.open(SRC, 'w', encoding='utf-8') as f:
    f.writelines(out)

xml.dom.minidom.parse(SRC)
print('XML well-formed')
