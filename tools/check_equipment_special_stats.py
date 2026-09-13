"""Focused option generation, persistence and real combat regression gate."""
import argparse
import re
import subprocess
import time

from engine_path import ROOT, engine, hidden_options
from godot_test_completion import completion_evidence

parser = argparse.ArgumentParser()
parser.add_argument("--focused", action="store_true", help="Run only the new feature test")
args = parser.parse_args()
tests = ["equipment_special_stats"]
if not args.focused:
    tests += ["character_stats_v2", "boss_stagger_v03", "revival_aftereffects",
              "inventory_grid", "consumables", "tactical_tools"]
run = ROOT / "runtime" / ("equipment-special-stats-" + str(time.time_ns()))
run.mkdir(parents=True)
total = 0
print("Evidence:", run, flush=True)
for test in tests:
    result = subprocess.run([engine(), "--headless", "--path", str(ROOT / "game"),
                             "--script", "res://tests/" + test + ".gd"],
                            capture_output=True, text=True, encoding="utf-8", errors="replace",
                            timeout=60, **hidden_options())
    output = result.stdout + result.stderr
    (run / (test + ".log")).write_text(output, encoding="utf-8")
    if test == "equipment_special_stats":
        matches = re.findall(r"^EQUIPMENT_SPECIAL_STATS_TESTS checks=(\d+) failures=(\d+)\r?$", output, re.M)
        if (result.returncode or len(matches) != 1 or int(matches[0][0]) < 280
                or int(matches[0][1]) or any(token in output for token in ("ERROR:", "SCRIPT ERROR", "WARNING:"))):
            raise RuntimeError(output)
        count = int(matches[0][0])
    else:
        count = completion_evidence(test, output, result.returncode)["checks"]
    total += count
    print(test, "PASS", count, flush=True)
print("EQUIPMENT_SPECIAL_STATS_PASS checks=" + str(total), flush=True)
