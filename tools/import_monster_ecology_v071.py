"""Import only approved, complete ecology artwork. Never rewrite source pixels."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'game'
ART = ROOT.parents[1] / 'RPG2/art/monsters'
OUT = GAME / 'assets/monster_ecology_v071'
DESIGN = ROOT / 'docs/design/normal_monster_expansion'
PHASES = ['idle', 'windup', 'impact', 'recover']


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare():
    design = read(DESIGN / 'catalog.json')
    size_source = DESIGN / 'size_assignments.json'
    sizes = {e['monster_id']: e for e in read(size_source)['assignments']}
    review_path = ART / 'normal-ecology-priority-20260913/reuse_review.json'
    review = read(review_path)
    assert review == read(ART / 'normal-ecology-regional-20260913/reuse_review.json')
    reusable = {e['id'] for e in review['records'] if e['status'] == 'reuse_suitable'}
    held = [e for e in review['records'] if e['required_new_phases']]
    sources = {}
    for folder in ['normal-ecology-priority-20260913', 'normal-ecology-regional-20260913']:
        path = ART / folder / 'catalog.json'
        catalog = read(path)
        assert catalog['size_source_sha256'] == sha(size_source)
        for identity, species in catalog['species'].items():
            sources[identity] = (path, species, path.parent / catalog['sheets'][identity]['path'])
    assert len(sources) == 20 and len(reusable) == 9 and len(held) == 11
    new_ids = set(sources)
    legacy = read(GAME / 'assets/monster_motions_v06/catalog.json')
    species = {}
    sheets = {}
    copied = {}
    for monster in design['monsters']:
        identity = monster['id']
        if identity not in new_ids | reusable:
            continue
        if identity in sources:
            catalog_path, art, original = sources[identity]
        else:
            catalog_path = Path(monster['sprite']['existing_catalog'].replace('\\', '/'))
            art = read(catalog_path)['species'][identity]
            original = catalog_path.parent / art['sheet']
            reviewed = next(e for e in review['records'] if e['id'] == identity)
            assert sha(original) == reviewed['source_sha256']
        phases = [f['phase'] for f in art['frames']]
        assert phases == PHASES
        size = sizes[identity]
        assert size['ratio'] == monster['size']['display_ratio']
        assert size['size_class'] == monster['size']['size_class']
        if identity in new_ids:
            assert art['display_ratio'] == size['ratio'] and art['size_class'] == size['size_class']
        reused = identity in legacy['species']
        if reused:
            sheet = legacy['species'][identity]['sheet']
            destination = GAME / sheet.removeprefix('res://')
            assert sha(destination) == sha(original)
        else:
            name = identity + '.png'
            destination = OUT / 'sheets' / name
            sheet = 'res://assets/monster_ecology_v071/sheets/' + name
            copied[destination] = original
        with Image.open(original) as image:
            dimensions, mode = list(image.size), image.mode
        assert mode == 'RGB'
        sheets[sheet] = {'sha256': sha(original), 'source_path': str(original),
                         'size': dimensions, 'original_mode': mode,
                         'key': 'magenta_narrow', 'reused_v07_sheet': reused}
        frames = []
        for frame in art['frames']:
            rect = frame['rect']
            assert rect[0] >= 0 and rect[1] >= 0 and min(rect[2:]) > 0
            assert rect[0] + rect[2] <= dimensions[0] and rect[1] + rect[3] <= dimensions[1]
            frames.append({k: frame[k] for k in ['phase', 'rect', 'foot', 'body_bounds', 'body_facing', 'local_render_bounds'] if k in frame})
        pattern = monster['combat']['pattern']
        assert pattern['id'] == identity + ':primary' and pattern['recovery_seconds'] > 0
        species[identity] = {
            'id': identity, 'name_ko': monster['name'], 'sheet': sheet, 'frames': frames,
            'body_height': art['body_height'], 'source_facing': -1.0,
            'attack_direction': 'screen_left', 'hovering': bool(art.get('hovering', False)),
            'size_class': size['size_class'], 'display_ratio': size['ratio'],
            'reference_character_height': 112.0, 'body_pixels': 112.0 * size['ratio'],
            'scale_formula': '112 * display_ratio / fixed_idle_body_height',
            'pattern': pattern,
            'timing': {'windup_seconds': pattern['windup_seconds'],
                       'recovery_seconds': pattern['recovery_seconds'],
                       'impact_visual_seconds': min(.12, pattern['recovery_seconds']),
                       'impact_is_visual_only': True,
                       'release_motion_duration_default': pattern['recovery_seconds']},
            'provenance': {'source_catalog': str(catalog_path), 'source_catalog_sha256': sha(catalog_path),
                           'source_sheet': str(original), 'source_sha256': sha(original),
                           'new20': identity in new_ids, 'pose_review': 'four_requested_poses_delivered' if identity in new_ids else 'reuse_suitable',
                           'reused_v07_appearance': reused, 'original_pixels': 'unchanged'},
        }
    assert len(species) == 29 and len(copied) == 21 and len(sheets) == 26
    assert not set(species) & {e['id'] for e in held}
    return {'version': 1, 'pack_id': 'monster_ecology_v071', 'species_count': 29,
            'frame_count': 116, 'phases': PHASES, 'key': 'magenta_narrow',
            'combat_runtime_registration': 'main_owned_not_performed_by_importer',
            'species': species, 'sheets': sheets,
            'deferred': [{'id': e['id'], 'missing_requested_phases': e['required_new_phases'],
                          'reason': e['reason'], 'additional_art_produced': False} for e in held],
            'provenance': {'design_catalog_sha256': sha(DESIGN / 'catalog.json'),
                           'size_assignments_sha256': sha(size_source), 'reuse_review_sha256': sha(review_path)},
            'counts': {'new20': 20, 'reuse_suitable': 9, 'copied_original_sheets': 21,
                       'referenced_v07_sheets': 5, 'reused_v07_appearances': 8,
                       'deferred_species': 11, 'deferred_poses': 16},
            'notes': ['RGB originals plus existing shared magenta_narrow RGBA cache policy',
                      'Hare impact body faces right but kick remains screen-left; do not flip only this frame',
                      'Shrew second impact needs authoritative attack_impact_time refresh; reader schedules no hits',
                      'Whole source sheets can contain unlisted species; only the 29 explicit IDs are bound',
                      'No extra16 art-only species, bosses or background placements included']}, copied


def run(check=False):
    catalog, copies = prepare()
    encoded = json.dumps(catalog, ensure_ascii=False, indent=2) + '\n'
    if check:
        assert (OUT / 'catalog.json').read_text(encoding='utf-8') == encoded, 'stale ecology catalog'
    else:
        OUT.mkdir(parents=True, exist_ok=True)
        for target, source in copies.items():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        (OUT / 'catalog.json').write_text(encoded, encoding='utf-8')
    for path, entry in catalog['sheets'].items():
        assert sha(GAME / path.removeprefix('res://')) == entry['sha256']
    print('MONSTER_ECOLOGY_V071_IMPORT_PASS species=29 frames=116 copied=21 reused_sheets=5 mode=' + ('check' if check else 'import'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    run(parser.parse_args().check)
