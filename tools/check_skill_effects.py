"""Import, exercise real skill events, and capture the Godot VFX gallery.

GODOT_EXE can select an engine. Every run writes its own logs and save directory
under runtime/skill-effects-checks; player saves are never loaded or changed.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import time

from engine_path import ROOT, engine, hidden_options


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--import-only", action="store_true")
    args = parser.parse_args()
    run_dir = ROOT / "runtime/skill-effects-checks" / (time.strftime("%Y%m%d-%H%M%S") + f"-{os.getpid()}")
    run_dir.mkdir(parents=True, exist_ok=True)
    save_dir = run_dir / "saves"
    save_dir.mkdir()
    # Reuse the checkout's normal engine discovery; this sibling is the local
    # development engine when the publish folder intentionally omits binaries.
    try:
        executable = engine()
    except FileNotFoundError:
        sibling = Path("D:/SSRPG/RPG2/tools/godot/Godot_v4.6-stable_win64.exe")
        if os.environ.get("GODOT_EXE") or not sibling.is_file():
            raise
        executable = str(sibling)
    results = []
    errors = []

    def run(name: str, command: list[str], timeout: int = 120) -> str:
        # An explicit workspace log avoids Godot's default user:// log path.
        engine_log = run_dir / f"{name}-engine.log"
        command[1:1] = ["--log-file", str(engine_log)]
        try:
            result = subprocess.run(
                command, capture_output=True, text=True, encoding="utf-8",
                errors="replace", timeout=timeout, **hidden_options()
            )
            output = result.stdout + result.stderr
            returncode = result.returncode
        except subprocess.TimeoutExpired as exc:
            def decode(value):
                return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
            output = decode(exc.stdout) + decode(exc.stderr) + f"\nERROR: {name} timed out after {timeout} seconds\n"
            returncode = -1
        if engine_log.is_file():
            output += "\nGodot file log:\n" + engine_log.read_text(encoding="utf-8", errors="replace")
        log = run_dir / f"{name}.log"
        log.write_text(output, encoding="utf-8")
        bad = re.search(r"(?:SCRIPT ERROR|ERROR:|WARNING:)", output)
        status = "FAIL" if returncode or bad else "PASS"
        if status == "FAIL":
            errors.append(f"{name} failed (exit {returncode}); {log}\n{output[-12000:]}")
        results.append({"step": name, "status": status, "log": str(log)})
        print(f"{name} {status}", flush=True)
        return output

    try:
        run("import", [executable, "--headless", "--path", str(ROOT / "game"), "--editor", "--import", "--quit"])
        if errors:
            raise RuntimeError(errors[-1])
        if args.import_only:
            print(f"SKILL_EFFECTS_IMPORT PASS logs={run_dir}", flush=True)
            return 0
        output = run("skill-vfx", [
            executable, "--headless", "--verbose", "--path", str(ROOT / "game"),
            "--script", "res://tests/skill_vfx.gd", "--", "--mute", f"--save-dir={save_dir}",
        ])
        marker = re.search(r"SKILL_VFX_TESTS checks=(\d+) failures=(\d+) casts=(\d+) families=(\d+) events=(\d+) movement=(\d+)", output)
        if marker is None or int(marker[2]) != 0 or int(marker[1]) <= 0 or int(marker[4]) != 18:
            errors.append(f"Missing complete visual-event test result\n{output[-12000:]}")
            results[-1]["status"] = "FAIL"
        if marker:
            results[-1].update(dict(zip(["checks", "failures", "casts", "families", "events", "movement"], map(int, marker.groups()))))
        # Rendering remains useful evidence even when the model step reports a
        # warning. Every independent stage runs; any failure still fails the gate.
        combat = run("visual-skill-vfx", [
            executable, "--path", str(ROOT / "game"),
            "--script", "res://tests/visual_skill_vfx.gd", "--", "--mute", f"--save-dir={save_dir}",
        ])
        visual = re.search(r"VISUAL_SKILL_VFX_TESTS checks=(\d+) failures=(\d+) captures=(\d+) render_errors=(\d+)", combat)
        if visual is None or int(visual[2]) or int(visual[3]) != 8 or int(visual[4]) or "VISUAL_SKILL_VFX_PASS" not in combat:
            errors.append(f"Missing complete combat-render test result\n{combat[-12000:]}")
            results[-1]["status"] = "FAIL"
        if visual:
            results[-1].update(dict(zip(["checks", "failures", "captures", "render_errors"], map(int, visual.groups()))))
        artifacts = ROOT / "artifacts"
        artifacts.mkdir(exist_ok=True)
        captures = []
        # Three captures exercise separate portions of the real animation loop.
        # No --headless flag: these are Godot-rendered PNGs, not synthetic mocks.
        for index, when in enumerate([.22, .55, .90], start=1):
            capture = artifacts / f"skill-effects-gallery-{index}.png"
            started_ns = time.time_ns()
            run(f"gallery-{index}", [
                executable, "--path", str(ROOT / "game"), "res://vfx_gallery.tscn",
                "--", "--mute", f"--save-dir={save_dir}", f"--capture={capture}",
                f"--capture-at={when}", f"--duration={when + .35}",
            ])
            if not capture.is_file() or capture.stat().st_mtime_ns < started_ns - 2_000_000_000:
                errors.append(f"Gallery did not produce a fresh capture: {capture}")
                results[-1]["status"] = "FAIL"
                continue
            png = capture.read_bytes()
            if len(png) < 5000 or png[:8] != b"\x89PNG\r\n\x1a\n":
                errors.append(f"Invalid gallery PNG: {capture}")
                results[-1]["status"] = "FAIL"
                continue
            width, height = struct.unpack(">II", png[16:24])
            if width < 1000 or height < 600:
                errors.append(f"Gallery capture is unexpectedly small: {width}x{height}")
                results[-1]["status"] = "FAIL"
                continue
            captures.append({"path": str(capture), "width": width, "height": height, "capture_at": when})
        report = {"status": "FAIL" if errors else "PASS", "results": results, "captures": captures, "errors": errors, "run_directory": str(run_dir), "save_directory": str(save_dir)}
        (artifacts / "skill-effects-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        if errors:
            raise RuntimeError("\n\n".join(errors))
        print(f"SKILL_EFFECTS_GATE PASS checks={marker[1]} casts={marker[3]} families={marker[4]} captures={len(captures)} logs={run_dir}", flush=True)
        return 0
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        print(str(exc), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
