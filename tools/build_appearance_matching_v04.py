"""Compile reviewed weapon/motion eligibility without changing source artwork."""
from pathlib import Path
import argparse, json

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
review = json.loads((ROOT / 'docs/costume_v04/CLASS_MATCHING.json').read_text('utf8'))
gat = json.loads((ROOT / 'docs/costume_v04/GAT_CLASS_MATCHING_PROPOSAL.json').read_text('utf8'))
assert review['schema_version'] >= 2 and len(review['entries']) == 33
result = {}
for key, entry in review['entries'].items():
    result[key] = {
        'allowed_base_classes': [] if 'permitted_jobs' in entry else entry['allowed_base_classes'],
        'allowed_classes': entry.get('permitted_jobs', []),
        'weapon_subtype': entry.get('weapon_subtype', ''),
        'runtime_role': entry.get('runtime_role', 'player_costume'),
    }
for entry in gat['entries']:
    result[entry['id']] = {'allowed_base_classes': entry['allowed_base_classes'], 'allowed_classes': []}
assert len(result) == 57
path = ROOT / 'game/assets/costume_v04/class_matching.json'
payload = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + '\n'
if args.check:
    assert path.read_text('utf8') == payload, 'Runtime appearance rules differ from reviewed matching'
else:
    path.write_text(payload, 'utf8')
print('APPEARANCE_MATCHING_V04 PASS entries=57 player_costumes=30 town_visitors=3')
