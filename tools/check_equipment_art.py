"""Audit 115 item sprites, 2,500 definitions and unchanged character choices.

Default: assets, import, model checks, one gallery and two real game scenes.
--assets-only needs Python/Pillow only; --model-only omits graphics. No source
PNG is rewritten. Godot logs and test saves live in this checkout's runtime.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from PIL import Image, ImageChops, ImageStat
from check_icons import chroma_mask
from engine_path import ROOT, engine, hidden_options

CAPTURES = ["items-gallery", "bag", "drops"]


def asset_audit() -> dict:
    directory = ROOT / "game/assets/equipment"
    catalog = json.loads((directory / "items.json").read_text(encoding="utf-8"))
    items = catalog["items"]
    failures, rows, sheets = [], [], {}
    regions = defaultdict(list)
    images = {}
    if len(items) != 115:
        failures.append(f"Expected 115 item sprites, got {len(items)}")

    def inspect(key, entry):
        source = str(entry.get("sheet", ""))
        if not source.startswith("res://assets/equipment/"):
            failures.append(f"Invalid equipment resource location: {key}: {source}")
            return
        path = ROOT / "game" / source.removeprefix("res://")
        if source not in images:
            try:
                image = Image.open(path)
                image.load()
            except OSError as exc:
                failures.append(f"Missing or unreadable {path}: {exc}")
                return
            images[source] = image
            if image.format != "PNG" or image.mode not in ("RGB", "RGBA") or image.size not in ((1536, 1024), (1254, 1254)):
                failures.append(f"Unsupported native chroma sheet {source}: {image.format}/{image.mode}/{image.size}")
            keyed_fraction = chroma_mask(image).histogram()[255] / (image.width * image.height)
            if keyed_fraction < .005:
                failures.append(f"No meaningful native magenta background in {source}")
            sheets[source] = {"path": str(path), "size": list(image.size), "mode": image.mode, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "native_chroma_fraction": round(keyed_fraction, 5)}
            if sheets[source]["sha256"] != catalog["sheets"][path.stem]["source_sha256"]:
                failures.append(f"Original source SHA256 changed: {source}")
        image = images[source]
        rect = entry.get("rect", [])
        if len(rect) != 4 or any(not isinstance(v, (int, float)) or not math.isfinite(v) or int(v) != v for v in rect):
            failures.append(f"Invalid integer crop bounds {key}: {rect}")
            return
        x, y, width, height = map(int, rect)
        if min(x, y) < 0 or min(width, height) <= 0 or x + width > image.width or y + height > image.height:
            failures.append(f"Out-of-bounds crop {key}: {rect}")
            return
        for other, ox, oy, ow, oh in regions[source]:
            if max(x, ox) < min(x + width, ox + ow) and max(y, oy) < min(y + height, oy + oh):
                failures.append(f"Overlapping source regions: {key} / {other}")
        regions[source].append((key, x, y, width, height))
        crop = image.crop((x, y, x + width, y + height)).convert("RGBA")
        effective_alpha = ImageChops.multiply(crop.getchannel("A"), ImageChops.invert(chroma_mask(crop)))
        foreground = 1 - effective_alpha.histogram()[0] / (width * height)
        if foreground < .015:
            failures.append(f"Effectively empty sprite after native keying: {key}")
        composite = Image.composite(crop.convert("RGB"), Image.new("RGB", crop.size, (230, 220, 199)), effective_alpha)
        spreads = {}
        for size in [32, 64]:
            small = composite.copy(); small.thumbnail((size, size), Image.Resampling.LANCZOS)
            spread = ImageStat.Stat(small.convert("L")).stddev[0]
            spreads[str(size)] = round(spread, 3)
            if spread < 1:
                failures.append(f"Blank/flat rendered-size sprite {key} at {size}px")
        rows.append({"key": key, "sheet": source, "rect": rect, "foreground_fraction": round(foreground, 5), "luminance_spread": spreads})

    for key, entry in items.items():
        inspect(key, entry)
    if len(rows) != 115:
        failures.append(f"Expected 115 item regions, inspected {len(rows)}")
    if len(sheets) != 6:
        failures.append(f"Expected six original item PNGs, found {len(sheets)}")
    for image in images.values(): image.close()
    return {"status": "FAIL" if failures else "PASS", "failures": failures, "items": len(items), "regions": rows, "sheets": sheets, "pixel_policy": "Read-only classification/crops in memory; equipment reader keys alpha before upload with right/bottom padding. Source bytes and authored RGB are never edited.", "limits": "Pixel contrast cannot establish item meaning or crop quality. Inspect all six originals, the 115-item gallery and actual inventory/drop scenes."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--assets-only", action="store_true")
    modes.add_argument("--import-only", action="store_true")
    modes.add_argument("--model-only", action="store_true")
    args = parser.parse_args()
    run_dir = ROOT / "runtime/equipment-art-checks" / (time.strftime("%Y%m%d-%H%M%S") + f"-{os.getpid()}")
    run_dir.mkdir(parents=True)
    saves = run_dir / "saves"; saves.mkdir()
    artifacts = ROOT / "artifacts"; artifacts.mkdir(exist_ok=True)
    results, failures = [], []
    try:
        report = asset_audit()
        (artifacts / "equipment-art-assets.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"EQUIPMENT_ASSETS {report['status']} items={report['items']} sheets={len(report['sheets'])} regions={len(report['regions'])}", flush=True)
        results.append({"step": "assets", "status": report["status"], "regions": len(report["regions"])})
        if report["failures"]: raise RuntimeError("\n".join(report["failures"]))
        if args.assets_only: return 0
        try:
            executable = engine()
        except FileNotFoundError:
            sibling = Path("D:/SSRPG/RPG2/tools/godot/Godot_v4.6-stable_win64.exe")
            if os.environ.get("GODOT_EXE") or not sibling.is_file(): raise
            executable = str(sibling)

        def run(name, arguments):
            engine_log = run_dir / f"{name}-engine.log"
            command = [executable, "--log-file", str(engine_log), "--path", str(ROOT / "game")] + arguments
            try:
                process = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=150, **hidden_options())
                output, code = process.stdout + process.stderr, process.returncode
            except subprocess.TimeoutExpired as exc:
                def decode(value): return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
                output, code = decode(exc.stdout) + decode(exc.stderr) + "\nERROR: Godot timed out after 150 seconds\n", -1
            if engine_log.is_file(): output += "\nGodot file log:\n" + engine_log.read_text(encoding="utf-8", errors="replace")
            log = run_dir / f"{name}.log"; log.write_text(output, encoding="utf-8")
            status = "FAIL" if code or re.search(r"SCRIPT ERROR|ERROR:|WARNING:", output) else "PASS"
            results.append({"step": name, "status": status, "log": str(log)})
            print(f"EQUIPMENT_{name.upper()} {status}", flush=True)
            if status == "FAIL": failures.append(f"{name} failed (exit {code}); {log}\n{output[-12000:]}")
            return output

        run("import", ["--headless", "--editor", "--import", "--quit"])
        if failures: raise RuntimeError(failures[-1])
        if args.import_only: return 0
        output = run("model", ["--headless", "--verbose", "--script", "res://tests/equipment_art.gd", "--", "--mute", f"--save-dir={saves}"])
        marker = re.search(r"EQUIPMENT_ART_MODEL checks=(\d+) failures=(\d+) items=(\d+) definitions=(\d+) appearances=(\d+)", output)
        if marker is None or tuple(map(int, marker.groups()[1:])) != (0, 115, 2500, 60):
            failures.append(f"Incomplete equipment model result\n{output[-8000:]}"); results[-1]["status"] = "FAIL"
        if marker: results[-1].update(dict(zip(["checks", "failures", "items", "definitions", "appearances"], map(int, marker.groups()))))
        captures = []
        if not args.model_only:
            started = time.time_ns()
            output = run("visual", ["--script", "res://tests/visual_equipment_art.gd", "--", "--mute", f"--save-dir={saves}"])
            marker = re.search(r"EQUIPMENT_ART_VISUAL checks=(\d+) failures=(\d+) captures=(\d+) render_errors=(\d+)", output)
            if marker is None or tuple(map(int, marker.groups()[1:])) != (0, 3, 0):
                failures.append(f"Incomplete equipment real-render result\n{output[-8000:]}"); results[-1]["status"] = "FAIL"
            if marker: results[-1].update(dict(zip(["checks", "failures", "captures", "render_errors"], map(int, marker.groups()))))
            for name in CAPTURES:
                path = artifacts / f"equipment-{name}.png"
                if not path.is_file() or path.stat().st_mtime_ns < started - 2_000_000_000:
                    failures.append(f"Missing fresh actual capture: {path}"); continue
                with Image.open(path) as image:
                    if image.format != "PNG" or image.size != (1920, 1080): failures.append(f"Invalid Full HD capture format/dimensions: {path}")
                    details = {"path": str(path), "size": list(image.size)}
                    if "gallery" in name:
                        keyed = chroma_mask(image).histogram()[255]
                        details["bright_magenta_pixels"] = keyed
                        if keyed: failures.append(f"Bright magenta survives native gallery renderer: {name}: {keyed} pixels")
                    captures.append(details)
        summary = {"status": "FAIL" if failures else "PASS", "results": results, "captures": captures, "failures": failures, "run_directory": str(run_dir), "save_directory": str(saves), "rendered": not args.model_only}
        (artifacts / "equipment-art-verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
        if failures: raise RuntimeError("\n\n".join(failures))
        print(f"EQUIPMENT_ART_GATE PASS items=115 definitions=2500 appearances=60 captures={len(captures)} logs={run_dir}", flush=True)
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, TypeError) as exc:
        print(str(exc), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__": raise SystemExit(main())
