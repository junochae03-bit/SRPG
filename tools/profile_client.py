"""Measure a hidden client with an isolated copy of a supplied save.

Wall-frame intervals depend on focus, GPU scheduling and other running clients.
Compare CPU components and first-load stalls under the same renderer/settings;
this probe does not establish a guaranteed player FPS.
"""
import argparse
import hashlib
import json
import statistics
import subprocess
import time
from pathlib import Path
from engine_path import ROOT, engine, hidden_options


def metrics(values):
    values = sorted(values)
    if not values:
        return {}
    return {"n": len(values), "mean": round(statistics.mean(values), 3),
            **{name: round(values[int((len(values) - 1) * q)], 3)
               for name, q in [("p50", .5), ("p95", .95), ("p99", .99)]},
            "max": round(max(values), 3)}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--save", type=Path, required=True)
    parser.add_argument("--label", default="client")
    parser.add_argument("--floor", type=int)
    parser.add_argument("--menu", choices=["bag", "skills", "codex"])
    parser.add_argument("--combat", action="store_true", help="Drive the existing test bot in the isolated copy")
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for c in args.label):
        parser.error("label must be a simple identifier")
    source = args.save.read_bytes()
    json.loads(source)
    run = ROOT / "runtime/performance-v05" / (args.label + "-" + str(time.time_ns()))
    saves = run / "saves"
    saves.mkdir(parents=True)
    (saves / "slot-1.json").write_bytes(source)
    command = [engine(), "--path", str(ROOT / "game"), "--script",
               "res://tests/performance_probe_v05.gd", "--disable-vsync", "--",
               "--play", "--mute", "--slot=1", "--save-dir=" + str(saves),
               "--duration=12", "--probe-output=" + str(run / "timings.json")]
    if args.floor is not None:
        command.append("--probe-floor=" + str(args.floor))
    if args.menu:
        command.append("--probe-menu=" + args.menu)
    if args.combat:
        command.append("--bot")
    start = time.perf_counter()
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf8",
                            errors="replace", timeout=85, **hidden_options())
    log = result.stdout + result.stderr
    (run / "engine.log").write_text(log, "utf8")
    assert result.returncode == 0 and not any(s in log for s in ["ERROR:", "SCRIPT ERROR", "WARNING:"]), log[-5000:]
    data = json.loads((run / "timings.json").read_text("utf8"))
    summary = {"label": args.label, "fixture_sha256": hashlib.sha256(source).hexdigest(),
               "wall_s": round(time.perf_counter() - start, 2),
               "gpu": data["gpu"], "draw_calls": data["draw_calls"],
               "window_size": data.get("window_size"), "viewport_size": data.get("viewport_size"),
               "physics_ms": data["physics_ms"], "process_ms": data["process_ms"],
               "frames": metrics([r["ms"] for r in data["frames"]]),
               "warm_frames": metrics([r["ms"] for r in data["frames"] if r["at_ms"] > 5000]),
               "timings": {k: metrics(v) for k, v in data["timings"].items()}}
    (run / "summary.json").write_text(json.dumps(summary, indent=2), "utf8")
    print(json.dumps(summary), flush=True)
    print("PROFILE", run / "summary.json", flush=True)


if __name__ == "__main__":
    main()
