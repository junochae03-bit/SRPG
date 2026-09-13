"""Check the generated runtime projection against the independent design/art sources."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative):
    return json.loads((ROOT / relative).read_text(encoding='utf-8'))


def run():
    design = read('docs/design/normal_monster_expansion/catalog.json')
    art = read('game/assets/monster_ecology_v071/catalog.json')
    runtime = read('game/data/monster_ecology_v071.json')
    actual = runtime['monsters']
    assert set(actual) == set(art['species']) and len(actual) == 29
    assert runtime['regions'] == design['regions']
    assert set(runtime['deferred_ids']).isdisjoint(actual)
    count = 0
    for original in design['monsters']:
        kind = original['id']
        if kind not in actual:
            continue
        row = actual[kind]
        for field in ['spawn', 'ecology', 'size']:
            assert row[field] == original[field], (kind, field)
        assert row['source_combat'] == original['combat']
        assert row['pattern'] == original['combat']['pattern']
        authored = [a for a in design['appearances'] if a['monster_id'] == kind]
        assert row['appearances'] == {str(a['floor']): a for a in authored}
        count += len(authored)
        for appearance in authored:
            assert appearance['floor'] % 10 != 0
            assert row['equipment_baseline_by_floor'][str(appearance['floor'])] == appearance['baseline_appearance_id'].split(':')[2]
        expected_drops = [d for d in design['drops'] if d['monster_id'] == kind]
        assert len(expected_drops) == len(row['drops']) == 3
        for expected, transformed in zip(expected_drops, row['drops']):
            assert transformed['kind'] == 'material'
            assert transformed['key'] == transformed['material'] == expected['item_id']
            for field in ['chance', 'amount', 'risk_bonus', 'scope']:
                assert transformed[field] == expected[field], (kind, field)
            assert transformed['source_drop_id'] == expected['id']
        assert row['species_drop_materials'] == [d['item_id'] for d in expected_drops]
        assert row['not_applied']['status_effect'] == original['combat']['pattern']['status']
        assert row['not_applied']['elemental_damage'] == original['combat']['damage_element']
    assert count == 261
    # Regression: authored speed must not receive the legacy 2.8 clamp.
    assert max(a['speed'] for r in actual.values() for a in r['appearances'].values()) > 2.8
    print('MONSTER_ECOLOGY_MAPPING_V071_PASS species=29 appearances=261 drops=87 exact_source_fields=true')


if __name__ == '__main__':
    run()
