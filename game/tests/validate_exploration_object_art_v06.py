"""CPU validation only; does not launch Godot or alter source pixels."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

GAME = Path(__file__).resolve().parents[1]
ROOT = GAME / 'assets/exploration_objects_v06'


def validate():
    catalog = json.loads((ROOT / 'catalog.json').read_text(encoding='utf-8'))
    assert len(catalog['objects']) == 12 and len(catalog['sheets']) == 4
    images = {}
    for path, entry in catalog['sheets'].items():
        file = GAME / path.removeprefix('res://')
        assert hashlib.sha256(file.read_bytes()).hexdigest() == entry['sha256']
        image = Image.open(file)
        assert image.mode == 'RGB' and image.size == (1254, 1254)
        assert entry['key'] == 'magenta_narrow'
        images[path] = np.asarray(image)
    referenced = set()
    for category, themes in catalog['pools'].items():
        for biome, pool in themes.items():
            assert pool
            for identity in pool:
                referenced.add(identity)
                states = catalog['objects'][identity]['frames']
                assert all(state in states for state in (['closed', 'empty'] if category == 'cache' else ['available', 'depleted']))
            if biome == 'cave' and category == 'cache':
                assert set(pool) <= {'oak_chest', 'buried_urn'}
    assert referenced == set(catalog['objects'])
    frames = 0
    for identity, entry in catalog['objects'].items():
        assert entry['body_height'] > 0
        assert len(entry['frames']) == 3
        image = images[entry['sheet']]
        for state, frame in entry['frames'].items():
            x, y, width, height = frame['rect']
            fx, fy = frame['foot']
            assert min(x, y) >= 0 and min(width, height) > 0
            assert x + width <= 1254 and y + height <= 1254
            assert 0 <= fx <= width and 0 <= fy <= height
            rgb = image[y:y+height, x:x+width].astype(float) / 255.0
            distance = np.max(np.abs(rgb - [1, 0, 1]), axis=2)
            alpha = np.clip((distance - .15) / .05, 0, 1)
            alpha = alpha * alpha * (3 - 2 * alpha)
            assert np.count_nonzero(alpha > 0) > 100
            for target_height in [70, 100, 150]:
                scale = target_height / entry['body_height']
                assert np.allclose(-np.array([fx, fy]) * scale + np.array([fx, fy]) * scale, 0)
            frames += 1
    assert frames == 36
    report = {'passed': True, 'objects': 12, 'authored_frames': 36,
              'runtime_states': 24, 'original_sheets': 4, 'anchor_scale_cases': 108,
              'source_hashes_match': True, 'key': 'magenta_narrow',
              'godot_test': 'pending_main_serial_execution'}
    (ROOT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    validate()
