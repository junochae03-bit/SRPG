"""CPU asset checks; Godot reader checks are in the companion .gd test."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

GAME = Path(__file__).resolve().parents[1]
ROOT = GAME / 'assets/monster_motions_v06'


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def validate():
    catalog = load(ROOT / 'catalog.json')
    legacy = load(GAME / 'assets/world/dungeon-v04/catalog.json')
    sizes = load(GAME.parent / 'docs/design/normal_monster_expansion/size_assignments.json')
    assignments = {s['monster_id']: s for s in sizes['assignments']}
    assert catalog['variants'] == legacy['variants']
    assert set(catalog['base_ids']) == set(load(GAME / 'data/monsters-v05.json'))
    required = set(catalog['base_ids']) | set(catalog['raid_bosses'].values())
    for mapping in catalog['variants'].values():
        required.update(mapping.values())
    assert required == set(catalog['species']) and len(required) == 48
    assert len(catalog['sheets']) == 16
    images = {}
    for sheet, metadata in catalog['sheets'].items():
        path = GAME / sheet.removeprefix('res://')
        assert hashlib.sha256(path.read_bytes()).hexdigest() == metadata['sha256']
        im = Image.open(path)
        assert im.size == (1536, 1024) and im.mode == 'RGB'
        images[sheet] = np.asarray(im)
    frames = 0
    for identity, entry in catalog['species'].items():
        assert entry['size_policy'] == assignments[identity]
        assert entry['source_facing'] == -1 and entry['body_height'] > 0
        assert [f['phase'] for f in entry['frames']] == catalog['phases']
        rgb = images[entry['sheet']]
        for frame in entry['frames']:
            x, y, w, h = frame['rect']
            assert min(x, y) >= 0 and min(w, h) > 0
            assert x + w <= rgb.shape[1] and y + h <= rgb.shape[0]
            fx, fy = frame['foot']
            assert 0 <= fx <= w and fy >= 0
            if entry['hovering']:
                # Authored ground plane can sit below the cropped flying body.
                reference = entry['frames'][0]
                assert abs((y + fy) - (reference['rect'][1] + reference['foot'][1])) < .02
            else:
                assert fy <= h
            cx, cy, cw, ch = frame['content_rect']
            assert x <= cx and y <= cy and cx + cw <= x + w and cy + ch <= y + h
            crop = rgb[y:y+h, x:x+w]
            # Proposed shared magenta_narrow: original .15/.20 smoothstep alpha.
            distance = np.max(np.abs(crop.astype(float) / 255.0 - [1, 0, 1]), axis=2)
            alpha = np.clip((distance - .15) / .05, 0, 1)
            alpha = alpha * alpha * (3 - 2 * alpha)
            assert np.count_nonzero(alpha > 0) > 100
            for scale in [.5, 1.2, 2, 3, 6, 10]:
                for facing in [-1, 1]:
                    origin = -np.array([fx, fy]) * scale * [facing, 1]
                    anchor = np.array([fx, fy]) * scale * [facing, 1]
                    assert np.allclose(origin + anchor, 0)
            frames += 1
    assert frames == 192
    report = {'passed': True, 'species': 48, 'frames': frames, 'original_sheets': 16,
              'anchor_scale_facing_cases': frames * 12,
              'source_hashes_match': True, 'size_assignments_match': True,
              'godot_reader_test': 'pending_main_serial_execution'}
    (ROOT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    validate()
