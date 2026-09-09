"""Analyze original equipment PNGs and write JSON coordinates only; never save images.

All foreground pixels, including disconnected weapons, gloves and ribbons, are
included. Adaptive cells follow empty strips near the nominal grid boundaries.
Missing clear separators need visual review and block catalog writes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BACKGROUND = "Original PNG preserved. Alpha-zero and RGB r>.65,b>.65,g<.35 are transparent in the existing Gat chroma shader."


class ReviewRequired(ValueError):
    pass


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def foreground(pixels: np.ndarray) -> np.ndarray:
    rgb = pixels[:, :, :3]
    chroma = (rgb[:, :, 0] > 255 * .65) & (rgb[:, :, 2] > 255 * .65) & (rgb[:, :, 1] < 255 * .35)
    opaque = pixels[:, :, 3] > 0 if pixels.shape[2] == 4 else np.ones(chroma.shape, dtype=bool)
    return opaque & ~chroma


def cell_rect(width: int, height: int, columns: int, rows: int, index: int) -> list[int]:
    col, row = index % columns, index // columns
    x, y = col * width // columns, row * height // rows
    return [x, y, (col + 1) * width // columns - x, (row + 1) * height // rows - y]


def empty_strip_cuts(occupied: np.ndarray, count: int, label: str, margin: int) -> list[int]:
    """Choose genuinely empty separators within 25% of each nominal cell size."""
    length = len(occupied)
    indices = np.flatnonzero(~occupied)
    runs = np.split(indices, np.flatnonzero(np.diff(indices) > 1) + 1)
    gaps = [(int(run[0]), int(run[-1]) + 1) for run in runs if len(run) >= margin * 2]
    cuts = [0]
    cell_size = length / count
    for boundary in range(1, count):
        nominal = boundary * cell_size
        low, high = int(np.ceil(nominal - cell_size * .25)), int(np.floor(nominal + cell_size * .25))
        candidates = []
        for start, end in gaps:
            first, last = max(start + margin, low), min(end - margin, high)
            if first > last:
                continue
            # Center the separator in the available gap, keeping spare pixels on
            # both sides rather than shaving a sword tip to hit the nominal grid.
            cut = int(np.clip(round((start + end) / 2), first, last))
            candidates.append((abs(cut - nominal), -(end - start), cut))
        if not candidates:
            raise ReviewRequired(f"{label}: no empty strip at boundary {boundary}/{count}, nominal={nominal:.1f}, search={low}..{high}. Inspect overlapping parts; no pixels were discarded.")
        cuts.append(min(candidates)[2])
    cuts.append(length)
    if any(right <= left for left, right in zip(cuts, cuts[1:])):
        raise ReviewRequired(f"{label}: ambiguous separator order {cuts}")
    return cuts


def adaptive_cells(mask: np.ndarray, columns: int, rows: int, label: str, margin: int) -> tuple[list[list[int]], dict]:
    height, width = mask.shape
    cells = [None] * (columns * rows)
    x_cuts = empty_strip_cuts(mask.any(axis=0), columns, label + " columns", margin)
    row_cuts = []
    for col, (left, right) in enumerate(zip(x_cuts, x_cuts[1:])):
        y_cuts = empty_strip_cuts(mask[:, left:right].any(axis=1), rows, f"{label} column {col} rows", margin)
        row_cuts.append(y_cuts)
        for row, (top, bottom) in enumerate(zip(y_cuts, y_cuts[1:])):
            cells[row * columns + col] = [left, top, right - left, bottom - top]
    grid = {"mode": "adaptive_columns_then_rows", "column_cuts": x_cuts, "row_cuts_by_column": row_cuts}
    # The cells partition every original pixel exactly once. bounds() below also
    # checks empty crop padding so an adjacent object cannot enter another crop.
    if sum(cell[2] * cell[3] for cell in cells) != width * height:
        raise ReviewRequired(f"{label}: adaptive cells do not partition the original image")
    return cells, grid


def bounds(mask: np.ndarray, cell: list[int], label: str, padding: int, clearance: int) -> dict:
    x, y, width, height = cell
    local = mask[y:y + height, x:x + width]
    yy, xx = np.nonzero(local)
    if not len(xx):
        raise ReviewRequired(f"{label}: empty cell {cell}")
    left, top, right, bottom = int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1
    margins = [left, top, width - right, height - bottom]
    if min(margins) < max(padding, clearance):
        raise ReviewRequired(f"{label}: foreground touches cell boundary; margins L/T/R/B={margins}, cell={cell}. Inspect for clipped or neighboring parts.")
    return {
        "rect": [x + left - padding, y + top - padding, right - left + 2 * padding, bottom - top + 2 * padding],
        "foreground_rect": [x + left, y + top, right - left, bottom - top],
        "cell": cell,
    }


def analyze_sheet(root: Path, spec: dict, padding: int, clearance: int) -> tuple[dict, dict, Path, str]:
    path = root / "game/assets/equipment" / (spec["name"] + ".png")
    if not path.is_file():
        raise ReviewRequired(f"{spec['name']}: missing PNG {path}")
    original_hash = digest(path)
    with Image.open(path) as image:
        pixels = np.asarray(image.convert("RGBA"))
    mask = foreground(pixels)
    height, width = mask.shape
    columns, rows = int(spec["columns"]), int(spec["rows"])
    if columns <= 0 or rows <= 0:
        raise ReviewRequired(f"{spec['name']}: invalid grid {columns}x{rows}")
    sheet_path = "res://assets/equipment/" + path.name
    metadata = {"sheet": sheet_path, "width": width, "height": height, "columns": columns, "rows": rows, "source_sha256": original_hash}
    keys = spec["keys"]
    if len(keys) != columns * rows:
        raise ReviewRequired(f"{spec['name']}: {len(keys)} entries do not fill {columns}x{rows}")
    cells, grid = adaptive_cells(mask, columns, rows, spec["name"], max(padding, clearance))
    metadata["grid"] = grid
    frames, issues = [], []
    for index, key in enumerate(keys):
        try:
            frames.append(bounds(mask, cells[index], f"{spec['name']}[{index}] {key}", padding, clearance))
        except ReviewRequired as error:
            issues.append(str(error))
    if issues:
        raise ReviewRequired("\n".join(issues))
    entries = {key: {"sheet": sheet_path, **frame} for key, frame in zip(keys, frames)}
    return entries, metadata, path, original_hash


def self_test() -> None:
    pixels = np.zeros((20, 40, 4), dtype=np.uint8)
    pixels[:, :] = [255, 0, 255, 255]
    pixels[4:16, 4:16] = [120, 90, 60, 255]
    pixels[4:16, 24:36] = [245, 240, 210, 255]
    pixels[0, 0] = [0, 0, 0, 0]
    original = pixels.copy()
    mask = foreground(pixels)
    first = bounds(mask, [0, 0, 20, 20], "first", 2, 2)
    assert first["rect"] == [2, 2, 16, 16]
    assert bounds(mask, [20, 0, 20, 20], "second", 2, 2)["foreground_rect"] == [24, 4, 12, 12]
    assert not mask[0, 0] and np.array_equal(pixels, original)
    try:
        bounds(np.ones((20, 20), dtype=bool), [0, 0, 20, 20], "crossing", 2, 2)
    except ReviewRequired:
        pass
    else:
        raise AssertionError("Boundary-crossing foreground was accepted")
    assert cell_rect(1536, 1024, 5, 4, 19) == [1228, 768, 308, 256]
    asymmetric = np.zeros((100, 100), dtype=bool)
    asymmetric[5:47, 5:38] = True
    asymmetric[58:95, 5:38] = True
    asymmetric[5:39, 58:95] = True
    asymmetric[46:95, 58:95] = True
    cells, grid = adaptive_cells(asymmetric, 2, 2, "asymmetric-items", 2)
    assert grid["row_cuts_by_column"][0] != grid["row_cuts_by_column"][1]
    assert sum(asymmetric[y:y+h, x:x+w].sum() for x, y, w, h in cells) == asymmetric.sum()
    for index, cell in enumerate(cells):
        bounds(asymmetric, cell, str(index), 2, 2)
    try:
        adaptive_cells(np.ones((100, 100), dtype=bool), 2, 2, "no-gap", 2)
    except ReviewRequired:
        pass
    else:
        raise AssertionError("Overlapping foreground without an empty separator was accepted")
    print("EQUIPMENT_BOUNDS_SELF_TEST_PASS crop/chroma/alpha/crossing/adaptive-grid/source-unchanged")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=ROOT, help="Project root (default: this script's parent project)")
    parser.add_argument("--manifest", type=Path, help="Prompt manifest, default docs/EQUIPMENT_ART_PROMPTS.json")
    parser.add_argument("--dry-run", action="store_true", help="Analyze and report only; write no JSON. Missing/unsafe PNGs return 2.")
    parser.add_argument("--sheet", action="append", help="Only analyze this sheet name; repeatable, requires --dry-run")
    parser.add_argument("--padding", type=int, default=2, help="Crop margin around all foreground pixels (default: 2)")
    parser.add_argument("--edge-clearance", type=int, default=2, help="Required empty margin at cell edges (default: 2)")
    parser.add_argument("--self-test", action="store_true", help="Run in-memory analysis checks without PNGs or JSON writes")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if args.sheet and not args.dry_run:
        parser.error("--sheet requires --dry-run so partial atlases cannot replace a full catalog")
    if args.padding < 0 or args.edge_clearance < 1:
        parser.error("padding must be nonnegative and edge clearance must be positive")
    root = args.root.resolve()
    manifest_path = args.manifest or root / "docs/EQUIPMENT_ART_PROMPTS.json"
    manifest = json.loads(manifest_path.read_text("utf-8-sig"))
    specs = manifest["item_sheets"]
    if args.sheet:
        unknown = set(args.sheet) - {spec["name"] for spec in specs}
        if unknown:
            parser.error("Unknown selected sheets: " + ", ".join(sorted(unknown)))
        specs = [spec for spec in specs if spec["name"] in args.sheet]
    items, sheets, hashes, issues = {}, {}, {}, []
    for spec in specs:
        try:
            entries, metadata, path, original_hash = analyze_sheet(root, spec, args.padding, args.edge_clearance)
            if items.keys() & entries.keys():
                raise ReviewRequired(f"Duplicate keys in {spec['name']}")
            items.update(entries);sheets[spec["name"]] = metadata;hashes[path] = original_hash
            print(f"OK {spec['name']} {metadata['width']}x{metadata['height']} entries={len(entries)}")
        except (ReviewRequired, OSError, ValueError, KeyError) as error:
            issues.append(str(error))
    for path, original_hash in hashes.items():
        if digest(path) != original_hash:
            issues.append(f"Source changed during analysis: {path}")
    if issues:
        for issue in issues:
            print("REVIEW_REQUIRED " + issue, file=sys.stderr)
        print("No catalog JSON written; original PNGs were only read.", file=sys.stderr)
        return 2
    if not args.sheet and len(items) != 115:
        raise ReviewRequired(f"Expected 115 item entries, got {len(items)}")
    if not args.dry_run:
        destination = root / "game/assets/equipment/items.json"
        data = {"schema_version": 1, "background": BACKGROUND, "padding": args.padding, "sheets": sheets, "items": items}
        # All analysis succeeds before the metadata write; never save a PNG.
        destination.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", "utf-8")
        print("WROTE " + str(destination))
    print(f"EQUIPMENT_BOUNDS_{'DRY_RUN' if args.dry_run else 'PASS'} items={len(items)} original_pngs_unchanged={len(hashes)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError) as error:
        print("REVIEW_REQUIRED " + str(error), file=sys.stderr)
        raise SystemExit(2)
