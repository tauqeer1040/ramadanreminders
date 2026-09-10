import json
import io
import sys

d = json.load(io.open(sys.argv[1], encoding='utf-8'))
for r in d['workflow_runs'][:3]:
    print(r['name'], '|', r['head_sha'][:7], '|', r['status'], '|', r['conclusion'], '|', r['html_url'])
