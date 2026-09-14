import re, sys, datetime, io

SRC = sys.argv[1]
now_ms = int(datetime.datetime.now().timestamp() * 1000)

today = datetime.date.today()
days = [(today - datetime.timedelta(days=i)).isoformat() for i in range(4)]
# streak_activity_dates: json string list, newest last to match app writes
dates_json = '["' + '","'.join([days[3], days[2], days[1], days[0]]) + '"]'

trial_start = now_ms - 6 * 86400 * 1000  # 6 days ago: 3-day trial + grace long gone

with io.open(SRC, 'r', encoding='utf-8') as f:
    xml = f.read()

def set_entry(xml, name, value, kind):
    """Replace existing pref entry or insert before </map>."""
    pat = re.compile(r'<%s name="%s" value="[^"]*" />' % (kind, re.escape(name)))
    entry = '<%s name="%s" value="%s" />' % (kind, name, value)
    if pat.search(xml):
        return pat.sub(entry, xml)
    return xml.replace('</map>', '    ' + entry + '\n</map>')

xml = set_entry(xml, 'flutter.streak', '4', 'int')
xml = set_entry(xml, 'flutter.last_activity_date', days[0], 'string')
xml = set_entry(xml, 'flutter.streak_activity_dates', dates_json, 'string')
xml = set_entry(xml,
    'flutter.local_trial_start_install_aid:CP2A.260705.006_uid_6BnaJGlRf7Q0U944OIEMSO2aACW2',
    str(trial_start), 'int')

with io.open(SRC, 'w', encoding='utf-8') as f:
    f.write(xml)

print('seeded: streak=4, dates=%s..%s, trial_start=%d (6d ago)' % (days[3], days[0], trial_start))
