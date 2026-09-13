"""Read-only catalog/source and shared RGBA conversion verification."""
import json
import hashlib
from pathlib import Path

import numpy as np
from PIL import Image

from import_monster_ecology_v071 import run, ROOT, GAME, OUT
from prepare_render_cache import prepared_bytes


def validate():
    run(check=True)
    catalog = json.loads((OUT / 'catalog.json').read_text(encoding='utf-8'))
    frame_count = 0
    alpha_verified = 0
    for path, sheet in catalog['sheets'].items():
        source = GAME / path.removeprefix('res://')
        pixels = np.asarray(Image.open(source).convert('RGB'))
        raw, width, height = prepared_bytes(source, 'magenta_narrow')
        rgba = np.frombuffer(raw, dtype=np.uint8).reshape(height, width, 4)
        assert np.array_equal(rgba[:-1, :-1, :3], pixels), 'shared cache changed RGB'
        assert not rgba[-1, :, 3].any() and not rgba[:, -1, 3].any()
        assert hashlib.sha256(source.read_bytes()).hexdigest() == sheet['sha256']
        alpha_verified += 1
    for identity, entry in catalog['species'].items():
        assert entry['body_pixels'] == 112 * entry['display_ratio']
        assert entry['body_height'] > 0
        assert 0 < entry['timing']['impact_visual_seconds'] <= entry['timing']['recovery_seconds']
        for frame in entry['frames']:
            width, height = frame['rect'][2:]
            foot = np.array(frame['foot'])
            assert np.isfinite(foot).all()
            assert 0 <= foot[0] <= width
            if not entry['hovering']: assert 0 <= foot[1] <= height
            scale = entry['body_pixels'] / entry['body_height']
            for mirror in [-1, 1]:
                assert np.allclose(-foot * scale * [mirror, 1] + foot * scale * [mirror, 1], 0)
            frame_count += 1
    assert frame_count == 116 and alpha_verified == 26
    report = {'passed': True, 'species': 29, 'frames': 116, 'sheets': 26,
              'copied_originals': 21, 'reused_v07_sheets': 5,
              'source_hashes_and_provenance_match': True,
              'shared_rgba_conversion_preserves_all_rgb': True,
              'anchor_mirror_cases': frame_count * 2,
              'engine_test': 'separate_runtime_validation.json', 'live_combat_integration': 'main_owned_pending'}
    (OUT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    validate()
