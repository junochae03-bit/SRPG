"""Project approved design rows onto runtime contracts without rebalancing."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / 'docs/design/normal_monster_expansion/catalog.json'
ART = ROOT / 'game/assets/monster_ecology_v071/catalog.json'
OUT = ROOT / 'game/data/monster_ecology_v071.json'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def build():
    design, art = read(DESIGN), read(ART)
    approved = set(art['species'])
    assert len(approved) == 29
    crafting = read(ROOT / 'game/data/exploration_crafting_v071.json')['materials']
    source_drops = design['drops']
    monsters = {}
    for original in design['monsters']:
        identity = original['id']
        if identity not in approved:
            continue
        pattern = original['combat']['pattern']
        appearances = {str(row['floor']): row for row in design['appearances'] if row['monster_id'] == identity}
        assert len(appearances) == 9
        first = appearances[str(original['spawn']['floor_min'])]
        shape = pattern['shape']
        mapping = {
            'cone': {'shape': 'cone', 'radius': pattern['range_tiles'], 'angle': .8, 'basis': 'DB range; MonsterAttacks.contains default half-angle'},
            'circle': {'shape': 'circle', 'radius': 1., 'basis': 'MonsterAttacks shade target-circle radius; DB range remains trigger distance'},
            'two_bites': {'shape': 'circle', 'radius': .55, 'hit_delays': [0., .25], 'basis': 'existing rat contact radius; explicit DB two-bite interval and multiplier'},
            'short_dash': {'shape': 'line', 'radius': .58, 'distance': pattern['range_tiles'], 'basis': 'existing bat capsule half-width; DB dash distance; instantaneous swept path like existing dash'},
            'projectile': {'shape': 'line', 'radius': .18, 'distance': pattern['range_tiles'], 'speed': pattern.get('projectile_speed_tiles', 4.), 'basis': 'existing spellbook shot half-width; DB speed/range; new swept projectile routine'},
        }[shape]
        drops = []
        for row in source_drops:
            if row['monster_id'] != identity:
                continue
            assert row['risk_bonus'] is False and row['mode'] == 'independent'
            assert row['item_id'] in crafting or row['item_id'] in ['seed', 'ore']
            drops.append({'key': row['item_id'], 'kind': 'material', 'material': row['item_id'],
                          'chance': row['chance'], 'amount': row['amount'], 'risk_bonus': False,
                          'source_drop_id': row['id'], 'scope': row['scope']})
        assert len(drops) == 3
        definition = {k: first[k] for k in ['health', 'damage', 'speed', 'xp', 'gold']}
        definition.update(name=original['name'], range=pattern['range_tiles'],
                          respawn=999999., ai='ranged' if shape == 'projectile' else 'melee',
                          art=0, art_sheet='enemies', height=art['species'][identity]['body_pixels'],
                          elite=False, boss=False, ecology=True)
        monsters[identity] = {'id': identity, 'definition': definition, 'appearances': appearances,
                             'region': original['region'], 'tier': original['tier'],
                             'spawn': original['spawn'], 'ecology': original['ecology'],
                             'source_combat': original['combat'], 'pattern': pattern,
                             'physical_mapping': mapping, 'drops': drops,
                             'species_drop_materials': [row['material'] for row in drops],
                             'equipment_baseline_by_floor': {f: row['baseline_appearance_id'].split(':')[2] for f, row in appearances.items()},
                             'size': original['size'], 'body_pixels': art['species'][identity]['body_pixels'],
                             'implemented_by_module': ['authored_floor_stats', 'physical_' + shape, 'windup_start_lock', 'cooldown_and_recovery_metadata', 'fixed_personal_drop_roll'],
                             'not_applied': {'elemental_damage': original['combat']['damage_element'],
                                             'resistance_percent': original['combat']['resistance_percent'],
                                             'weakness_percent': original['combat']['weakness_percent'],
                                             'status_effect': pattern['status'],
                                             'collision_radius_tiles': original['size']['collision_radius_tiles'],
                                             'receiving_hit_radius_tiles': original['size']['hit_radius_tiles']}}
    assert set(monsters) == approved
    return {'schema_version': 1, 'status': 'runtime_connected',
            'monsters': monsters, 'regions': design['regions'],
            'counts': {'species': 29, 'appearances': 261, 'dedicated_drops': 87},
            'population_policy': {'original_species_slot_probability': .1, 'new_total_upper_bound': .4,
                                  'held_slots': 'keep_original_candidate_no_renormalization',
                                  'density': 'replace_existing_normal_slots_only',
                                  'group_size': 'enforce authored minimum and maximum; reject changed groups that cannot fit existing slots',
                                  'constraints': ['max_two_species_per_changed_group', 'max_one_ranged', 'no_predator_prey_pair', 'preserve_elite_guardian_raid_risk_reinforcements', 'reject_invalid_group_as_a_whole']},
            'geometry_mapping_policy': 'retain structured DB shape/range; missing footprint parameters explicitly reuse existing physical defaults; prose does not override structured shape',
            'damage_policy': 'existing MonsterAttacks.damage physical mitigation; no new elements/resistances/statuses',
            'drop_policy': 'three exact independent rows, no chance bonus; expose material exclusions; equipment remains separate legacy policy',
            'deferred_ids': [row['id'] for row in art['deferred']],
            'provenance': {'design_path': str(DESIGN), 'design_sha256': hashlib.sha256(DESIGN.read_bytes()).hexdigest(),
                           'art_catalog_sha256': hashlib.sha256(ART.read_bytes()).hexdigest(),
                           'stats_policy': 'copy authored 261 appearance rows exactly; factors already applied once; never run Abyss scaling again'}}


def run(check=False):
    data = build()
    encoded = json.dumps(data, ensure_ascii=False, indent=2) + '\n'
    if check:
        assert OUT.read_text(encoding='utf-8') == encoded
    else:
        OUT.write_text(encoded, encoding='utf-8')
    print('MONSTER_ECOLOGY_DATA_V071_PASS species=29 appearances=261 drops=87')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    run(parser.parse_args().check)
