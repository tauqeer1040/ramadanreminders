import io, sys

SRC = sys.argv[1]
with io.open(SRC, 'r', encoding='utf-8') as f:
    xml = f.read()

before = xml.count('name="flutter.streak"')
xml = xml.replace('<int name="flutter.streak" value="2" />', '', 1)
after = xml.count('name="flutter.streak"')

with io.open(SRC, 'w', encoding='utf-8') as f:
    f.write(xml)

print('flutter.streak entries: %d -> %d' % (before, after))
