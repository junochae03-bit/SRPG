"""Read source pixels and write atlas geometry only. Never writes raster assets.

Whole connected silhouettes own their weapons even outside the old grid cell.
Disconnected accents follow the nearest silhouette. Touching silhouettes require
an explicit reviewed seam; inseparable artwork uses a documented clean pose.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'game/data/sprite_frame_regions.json'
REPORT = ROOT / 'docs/qa/sprite-frame-regions.json'
# Coordinates reviewed against the original sheets, not uniform grid guesses.
SEAMS = {'tank': ('x', 987), 'runesword': ('x', 984), 'hunter': ('y', 934)}


def analyze(key, entry):
    path = ROOT / 'game' / entry['sheet'].removeprefix('res://')
    image = np.asarray(Image.open(path).convert('RGBA'))
    r, g, b = image[:, :, :3].transpose(2, 0, 1)
    mask = (image[:, :, 3] > 0) & ~((r > 255*.65) & (b > 255*.65) & (g < 255*.35))
    labels, count = ndimage.label(mask, np.ones((3, 3)))
    areas = np.bincount(labels.ravel())
    if key in SEAMS:
        axis, cut = SEAMS[key]
        merged = int(areas[1:].argmax()) + 1
        yy, xx = np.indices(mask.shape)
        labels[(labels == merged) & ((xx if axis == 'x' else yy) >= cut)] = count + 1
    # Reaper's chain is painted through its neighbor's hair. Do not pretend a
    # bounding-box crop can reconstruct the hidden hair. Use intact poses.
    reaper = key == 'reaper'
    if reaper:
        merged = int(areas[1:].argmax()) + 1
        labels[(labels == merged) & (np.indices(mask.shape)[1] >= 637)] = count + 1
    areas = np.bincount(labels.ravel())
    slices = ndimage.find_objects(labels)
    bodies = [i for i in range(1, len(areas)) if areas[i] > 5000]
    if len(bodies) != 16:
        raise ValueError(f'{key}: {len(bodies)} silhouettes; manual review required')
    bodies.sort(key=lambda i: (slices[i-1][0].start + slices[i-1][0].stop) / 2)
    bodies = [i for row in range(4) for i in sorted(bodies[row*4:row*4+4], key=lambda i: slices[i-1][1].start)]
    lookup = np.full(len(areas), -1, dtype=np.int16)
    for index, label in enumerate(bodies):
        lookup[label] = index
    main = np.isin(labels, bodies)
    nearest = ndimage.distance_transform_edt(~main, return_distances=False, return_indices=True)
    nearest_owner = lookup[labels[tuple(nearest)]]
    for label, region in enumerate(slices, 1):
        if region is None or lookup[label] >= 0:
            continue
        votes = nearest_owner[region][labels[region] == label]
        lookup[label] = np.bincount(votes, minlength=16).argmax()
    owners = lookup[labels]
    frames, findings = {}, []
    for index, old in enumerate(entry['frames']):
        x, y, w, h = map(int, old['rect'])
        owned = owners == index
        foreign = int((mask[y:y+h, x:x+w] & (owners[y:y+h, x:x+w] != index)).sum())
        missing = int(owned.sum() - owned[y:y+h, x:x+w].sum())
        if reaper and index in (9, 10):
            frames[str(index)] = {'use_frame': 8 if index == 9 else 6,
                'reason': 'Original chain crosses neighboring hair; intact anticipation/release pose preserves timing.'}
            findings.append({'index': index, 'fallback': frames[str(index)]['use_frame'], 'source_overlap': True})
            continue
        if not foreign and not missing:
            continue
        ys, xs = np.nonzero(owned)
        x0, y0 = max(0, int(xs.min())-1), max(0, int(ys.min())-1)
        x1, y1 = min(mask.shape[1], int(xs.max())+2), min(mask.shape[0], int(ys.max())+2)
        # Render horizontal strips from the ORIGINAL texture. A strip includes
        # transparent gaps but never samples pixels assigned to another frame.
        strips = []
        for row in range(y0, y1):
            cols = np.flatnonzero(owned[row])
            if not len(cols):
                continue
            left, right = max(0, int(cols.min())-1), min(mask.shape[1], int(cols.max())+2)
            blocked = mask[row, left:right] & (owners[row, left:right] != index)
            good = np.flatnonzero(~blocked) + left
            runs = np.split(good, np.flatnonzero(np.diff(good) > 1)+1)
            for run in runs:
                if not len(run) or not owned[row, run].any():
                    continue
                a, b = int(run[0]), int(run[-1])+1
                # Merge adjacent rows with identical source extents.
                match = next((s for s in reversed(strips) if s[0] == a and s[2] == b-a and s[1]+s[3] == row), None)
                if match is not None:
                    match[3] += 1
                else:
                    strips.append([a, row, b-a, 1])
        rendered = np.zeros(mask.shape, dtype=bool)
        for a, b, sw, sh in strips:
            rendered[b:b+sh, a:a+sw] = True
        assert not (rendered & mask & ~owned).any(), (key, index, 'foreign')
        assert not (owned & ~rendered).any(), (key, index, 'lost foreground')
        frames[str(index)] = {'rect': [x0, y0, x1-x0, y1-y0],
            'foot': [x+old['foot'][0]-x0, y+old['foot'][1]-y0], 'strips': strips}
        if not (mask[y0:y1, x0:x1] & (owners[y0:y1, x0:x1] != index)).any():
            del frames[str(index)]['strips']
        findings.append({'index': index, 'foreign_before': foreign, 'missing_before': missing,
            'foreign_after': 0, 'missing_after': 0, 'foreground_pixels': int(owned.sum()), 'strips': len(strips)})
    for value in list(frames.values()):
        if 'use_frame' in value:
            source_index = value['use_frame']
            source = frames.get(str(source_index), entry['frames'][source_index])
            value.update({k: source[k] for k in ('rect', 'foot', 'strips') if k in source})
    return frames, {'sheet': entry['sheet'], 'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'reviewed_seam': list(SEAMS[key]) if key in SEAMS else None, 'frames': findings}


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify committed geometry and source hashes without writing files')
    args = parser.parse_args()
    jobs = json.loads((ROOT/'game/assets/jobs/catalog.json').read_text())['sprites']
    motions = json.loads((ROOT/'game/assets/motions/catalog.json').read_text())
    result = {'schema': 1, 'entries': {}}
    report = {'scope': 'Registered job and base-motion sheets; source PNG unchanged', 'entries': {}}
    for prefix, entries in [('jobs:', jobs), ('motions:', motions)]:
        for key, entry in entries.items():
            frames, audit = analyze(key, entry)
            if frames:
                result['entries'][prefix+key] = frames
            report['entries'][prefix+key] = audit
            print(prefix+key, 'corrected', list(frames))
    if args.check:
        assert json.loads(OUTPUT.read_text(encoding='utf-8')) == result, 'Geometry differs; review source changes before regeneration'
        assert json.loads(REPORT.read_text(encoding='utf-8')) == report, 'Source hashes or audit differ'
        print('SPRITE_REGIONS_AUDIT_PASS source hashes, geometry, ownership and anchors verified')
        return
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf-8')
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
