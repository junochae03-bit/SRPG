"""Audit semantic icon assets, all skill mappings, and actual Godot UI rendering.

Default: Pillow asset checks, Godot import, 1510-node model check, and thirteen
screenshots. --assets-only needs Python/Pillow only. GODOT_EXE selects Godot 4.6.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from PIL import Image, ImageChops, ImageStat

from engine_path import ROOT, engine, hidden_options

SIZES = (24, 32, 48)
CAPTURES = [f"gallery-{size}" for size in SIZES] + [
    "skills-mage", "skills-gambler", "skills-summoner", "stats", "hud", "inventory", "portal", "codex",
    "battle-check", "battle-down-empty",
]


def chroma_mask(image: Image.Image) -> Image.Image:
    """Return a classification mask matching gat_chroma; source pixels stay intact."""
    red, green, blue = image.convert("RGB").split()
    red = red.point(lambda value: 255 if value >= 166 else 0)
    green = green.point(lambda value: 255 if value <= 89 else 0)
    blue = blue.point(lambda value: 255 if value >= 166 else 0)
    return ImageChops.multiply(ImageChops.multiply(red, green), blue)


def audit_assets() -> dict:
    """Read original pixels only; never rewrite source sheets or make thumbnails."""
    icon_dir = ROOT / "game/assets/icons"
    catalog = json.loads((icon_dir / "semantic_catalog.json").read_text(encoding="utf-8"))
    failures, sheets, icons = [], [], []
    seen = set()
    hashes = defaultdict(list)
    columns, rows, cell = (int(catalog[key]) for key in ("columns", "rows", "cell_size"))
    if (columns, rows, cell) != (6, 4, 256):
        failures.append(f"Unexpected catalog geometry: {columns} columns, {rows} rows, {cell} cell")
    if len(catalog["sheets"]) != 7:
        failures.append("Catalog must contain seven sheets")
    sheet_names = set()
    for sheet in catalog["sheets"]:
        name = sheet["name"]
        if name in sheet_names:
            failures.append(f"Duplicate sheet name: {name}")
        sheet_names.add(name)
        path = icon_dir / f"wood-{name}.png"
        items = sheet["items"]
        if len(items) != columns * rows:
            failures.append(f"Sheet {name} has {len(items)} entries, expected 24")
        frames = sheet.get("frames", [[i % columns * cell, i // columns * cell, cell, cell] for i in range(len(items))])
        if len(frames) != len(items):
            failures.append(f"Sheet {name} frames and items have different lengths")
            continue
        if not path.is_file():
            failures.append(f"Missing original sheet: {path}")
            continue
        try:
            with Image.open(path) as source:
                source.load()
                if source.format != "PNG" or source.mode not in ("RGB", "RGBA"):
                    failures.append(f"Sheet {name} must be RGB or RGBA PNG, got {source.format}/{source.mode}")
                if source.size != (1536, 1024):
                    failures.append(f"Sheet {name} dimensions are {source.size}, expected (1536, 1024)")
                sheet_info = {"sheet": name, "path": str(path), "mode": source.mode, "size": list(source.size), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "explicit_frames": "frames" in sheet}
                if source.mode == "RGBA":
                    alpha_hist = source.getchannel("A").histogram()
                    sheet_info["transparent_fraction"] = round(alpha_hist[0] / (source.width * source.height), 5)
                else:
                    sheet_info["transparent_fraction"] = 0.0
                sheet_info["native_chroma_fraction"] = round(chroma_mask(source).histogram()[255] / (source.width * source.height), 5)
                if sheet_info["native_chroma_fraction"] < .005:
                    failures.append(f"Sheet {name} has no meaningful native magenta background; an earlier opaque source may still be present")
                sheets.append(sheet_info)
                valid_regions = []
                for key, frame in zip(items, frames):
                    if not isinstance(key, str) or not key:
                        failures.append(f"Empty or non-string key in {name}")
                        continue
                    if key in seen:
                        failures.append(f"Duplicate semantic key: {key}")
                    seen.add(key)
                    if len(frame) != 4 or any(not isinstance(value, (int, float)) or int(value) != value for value in frame):
                        failures.append(f"Invalid pixel bounds for {key}: {frame}")
                        continue
                    x, y, width, height = map(int, frame)
                    if min(x, y) < 0 or min(width, height) <= 0 or x + width > source.width or y + height > source.height:
                        failures.append(f"Out-of-bounds icon {key}: {frame}")
                        continue
                    for other_key, ox, oy, ow, oh in valid_regions:
                        if max(x, ox) < min(x + width, ox + ow) and max(y, oy) < min(y + height, oy + oh):
                            failures.append(f"Overlapping atlas crops: {key} and {other_key}")
                    valid_regions.append((key, x, y, width, height))
                    crop = source.crop((x, y, x + width, y + height)).convert("RGBA")
                    keyed = chroma_mask(crop)
                    effective_alpha = ImageChops.multiply(crop.getchannel("A"), ImageChops.invert(keyed))
                    alpha = effective_alpha.histogram()
                    visible_fraction = 1 - alpha[0] / (width * height)
                    if visible_fraction < .025:
                        failures.append(f"Icon {key} is effectively empty after native chroma keying")
                    # Readability uses a transient mathematical composite only.
                    # No original or derived asset image is written by this audit.
                    opaque = Image.composite(crop.convert("RGB"), Image.new("RGB", crop.size, (241, 231, 212)), effective_alpha)
                    values = {}
                    for size in SIZES:
                        thumbnail = opaque.convert("RGB")
                        thumbnail.thumbnail((size, size), Image.Resampling.LANCZOS)
                        deviation = ImageStat.Stat(thumbnail.convert("L")).stddev[0]
                        values[str(size)] = round(deviation, 3)
                        # This catches empty/flat cells. It does not claim to
                        # measure human symbol recognition or accessibility.
                        if deviation < 2.0:
                            failures.append(f"Icon {key} is blank/flat at {size}px (luminance spread {deviation:.2f})")
                    pixel_hash = hashlib.sha256(crop.tobytes() + str(crop.size).encode()).hexdigest()
                    hashes[pixel_hash].append(key)
                    icons.append({"key": key, "sheet": name, "rect": [x, y, width, height], "visible_fraction": round(visible_fraction, 5), "native_chroma_fraction": round(keyed.histogram()[255] / (width * height), 5), "luminance_spread": values, "pixel_sha256": pixel_hash})
        except (OSError, ValueError) as exc:
            failures.append(f"Cannot inspect {path}: {exc}")
    if len(seen) != 168 or len(icons) != 168:
        failures.append(f"Expected 168 unique usable icons, found keys={len(seen)}, usable={len(icons)}")
    for required in ("unknown", "skill_empty", "class_warrior", "class_gambler", "bag", "health", "shield", "slash"):
        if required not in seen:
            failures.append(f"Missing required semantic key: {required}")
    return {"status": "FAIL" if failures else "PASS", "failures": failures, "icons": icons, "sheets": sheets, "duplicate_pixel_groups": [keys for keys in hashes.values() if len(keys) > 1], "background_policy": "Original RGB/RGBA magenta-keyed atlases are supported. Native gat_chroma removes magenta at render time; cream artwork remains. Alpha is recorded, not required, and source pixels are never rewritten.", "readability_limit": "Non-flat pixels at 24/32/48px do not establish recognizable meaning; inspect the Godot gallery and UI captures."}


def audit_rendered_captures(started_ns: int, visual_output: str, artifacts: Path | None = None) -> dict:
    """Inspect an already completed visual_icons run; never launch Godot.

    The caller must record started_ns immediately before that engine run and
    supply its actual output. Asset and 1510-node model checks remain separate.
    This lets the full gate reuse its own render without trusting older PNGs.
    """
    artifacts = ROOT / "artifacts" if artifacts is None else Path(artifacts)
    failures, captures, visual = [], [], {}
    if not isinstance(started_ns, int) or started_ns <= 0:
        raise ValueError("Capture start must be the engine run's time.time_ns()")
    marker = re.search(r"ICON_VISUAL_TESTS checks=(\d+) failures=(\d+) captures=(\d+) render_errors=(\d+)", visual_output)
    if marker:
        visual = dict(zip(["checks", "failures", "captures", "render_errors"], map(int, marker.groups())))
    if not visual or visual["checks"] <= 0 or visual["failures"] or visual["captures"] != len(CAPTURES) or visual["render_errors"]:
        failures.append("Incomplete real-render coverage result\n" + visual_output[-8000:])
    if re.search(r"SCRIPT ERROR|ERROR:|WARNING:", visual_output):
        failures.append("Godot reported errors or warnings in the supplied visual run")
    for name in CAPTURES:
        path = artifacts / f"icons-{name}.png"
        if not path.is_file() or path.stat().st_mtime_ns < started_ns - 2_000_000_000:
            failures.append(f"Missing fresh Godot capture: {path}")
            continue
        try:
            with Image.open(path) as capture:
                details = {"path": str(path), "size": list(capture.size), "mtime_ns": path.stat().st_mtime_ns,
                           "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                captures.append(details)
                if capture.size != (1920, 1080) or capture.format != "PNG":
                    failures.append(f"Invalid Godot capture dimensions/format: {path}")
                    continue
                if name.startswith("gallery-"):
                    remaining = chroma_mask(capture).histogram()[255]
                    details["bright_magenta_pixels"] = remaining
                    if remaining:
                        failures.append(f"Native chroma left {remaining} bright magenta pixels in {path}")
                    samples = {"keyed_background": ((1517, 43), (24, 44, 48)), "preserved_cream": ((1632, 43), (241, 231, 212))}
                    rgb = capture.convert("RGB")
                    for label, (point, expected) in samples.items():
                        actual = rgb.getpixel(point)
                        details[label] = list(actual)
                        if max(abs(a - b) for a, b in zip(actual, expected)) > 6:
                            failures.append(f"Native chroma calibration {label} failed in {path}: {actual}, expected {expected}")
        except (OSError, ValueError) as exc:
            failures.append(f"Cannot inspect Godot capture {path}: {exc}")
    return {"status": "FAIL" if failures else "PASS", "rendered": True, "visual": visual,
            "captures": captures, "failures": failures, "capture_started_ns": started_ns, "checked_at_ns": time.time_ns(),
            "scope": "Post-render validation only: supplied Godot result, 13 fresh FullHD captures, gallery native chroma/calibration, and image hashes. No additional engine run; asset/model coverage is recorded by the caller."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--assets-only", action="store_true", help="Run read-only Pillow/catalog audit without Godot")
    modes.add_argument("--import-only", action="store_true", help="Run asset audit and Godot import, then stop")
    modes.add_argument("--skip-render", action="store_true", help="Run assets, import, and model coverage without graphics")
    args = parser.parse_args()
    run_dir = ROOT / "runtime/icon-checks" / (time.strftime("%Y%m%d-%H%M%S") + f"-{os.getpid()}")
    run_dir.mkdir(parents=True)
    save_dir = run_dir / "saves"
    save_dir.mkdir()
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    results, errors = [], []
    try:
        asset_report = audit_assets()
        (artifacts / "icon-asset-audit.json").write_text(json.dumps(asset_report, ensure_ascii=False, indent=2), encoding="utf-8")
        results.append({"step": "assets", "status": asset_report["status"], "icons": len(asset_report["icons"]), "sheets": len(asset_report["sheets"])})
        print(f"ICON_ASSETS {asset_report['status']} icons={len(asset_report['icons'])} sheets={len(asset_report['sheets'])}", flush=True)
        errors.extend(asset_report["failures"])
        if errors or args.assets_only:
            if errors:
                raise RuntimeError("\n".join(errors))
            return 0
        try:
            executable = engine()
        except FileNotFoundError:
            sibling = Path("D:/SSRPG/RPG2/tools/godot/Godot_v4.6-stable_win64.exe")
            if os.environ.get("GODOT_EXE") or not sibling.is_file():
                raise
            executable = str(sibling)

        def run(name: str, arguments: list[str], timeout: int = 120) -> str:
            engine_log = run_dir / f"{name}-engine.log"
            command = [executable, "--log-file", str(engine_log), "--path", str(ROOT / "game")] + arguments
            try:
                result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout, **hidden_options())
                output, code = result.stdout + result.stderr, result.returncode
            except subprocess.TimeoutExpired as exc:
                def decode(value):
                    return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
                output, code = decode(exc.stdout) + decode(exc.stderr) + f"\nERROR: timeout after {timeout}s\n", -1
            if engine_log.is_file():
                output += "\nGodot file log:\n" + engine_log.read_text(encoding="utf-8", errors="replace")
            log = run_dir / f"{name}.log"
            log.write_text(output, encoding="utf-8")
            status = "FAIL" if code or re.search(r"SCRIPT ERROR|ERROR:|WARNING:", output) else "PASS"
            results.append({"step": name, "status": status, "log": str(log)})
            print(f"ICON_{name.upper()} {status}", flush=True)
            if status == "FAIL":
                errors.append(f"{name} failed (exit {code}); {log}\n{output[-12000:]}")
            return output

        run("import", ["--headless", "--editor", "--import", "--quit"])
        if errors:
            raise RuntimeError(errors[-1])
        if args.import_only:
            print(f"ICON_IMPORT PASS logs={run_dir}", flush=True)
            return 0
        output = run("model", ["--headless", "--verbose", "--script", "res://tests/icons.gd", "--", "--mute", f"--save-dir={save_dir}"])
        marker = re.search(r"ICON_MODEL_TESTS checks=(\d+) failures=(\d+) icons=(\d+) skills=(\d+) classes=(\d+)", output)
        if marker is None or int(marker[2]) or tuple(map(int, marker.groups()[2:])) != (168, 1510, 20):
            errors.append(f"Incomplete model coverage result\n{output[-8000:]}")
            results[-1]["status"] = "FAIL"
        if marker:
            results[-1].update(dict(zip(["checks", "failures", "icons", "skills", "classes"], map(int, marker.groups()))))
        captures = []
        if not args.skip_render:
            started = time.time_ns()
            visual_output = run("visual", ["--script", "res://tests/visual_icons.gd", "--", "--mute", f"--save-dir={save_dir}"])
            rendered = audit_rendered_captures(started, visual_output, artifacts)
            errors.extend(rendered["failures"])
            results[-1].update(rendered["visual"])
            if rendered["status"] == "FAIL":
                results[-1]["status"] = "FAIL"
            captures = rendered["captures"]
        report = {"status": "FAIL" if errors else "PASS", "rendered": not args.skip_render, "results": results, "captures": captures, "errors": errors, "run_directory": str(run_dir), "save_directory": str(save_dir)}
        (artifacts / "icon-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        if errors:
            raise RuntimeError("\n\n".join(errors))
        print(f"ICON_GATE PASS icons=168 build_nodes=1510 classes=20 captures={len(captures)} logs={run_dir}", flush=True)
        return 0
    except (OSError, ValueError, KeyError, RuntimeError) as exc:
        print(str(exc), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
