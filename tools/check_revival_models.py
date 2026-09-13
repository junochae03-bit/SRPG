"""Focused rescue regression gate; does not replace the project's complete gate."""
import re
import subprocess
import time
from engine_path import ROOT, engine, hidden_options
from godot_test_completion import completion_evidence

run = ROOT / "runtime" / ("revival-models-" + str(time.time_ns()))
run.mkdir(parents=True)
total = 0
for test in ("revival_aftereffects", "coop_rules", "combat_lifecycle", "town_services_v052"):
    result = subprocess.run([engine(), "--headless", "--path", str(ROOT / "game"),
                             "--script", "res://tests/" + test + ".gd"],
                            capture_output=True, text=True, encoding="utf-8", errors="replace",
                            timeout=60, **hidden_options())
    output = result.stdout + result.stderr
    (run / (test + ".log")).write_text(output, encoding="utf-8")
    if test == "revival_aftereffects":
        matches = re.findall(r"REVIVAL_AFTEREFFECTS_TESTS checks=(\d+) failures=(\d+)", output)
        if result.returncode or len(matches) != 1 or int(matches[0][0]) < 50 or int(matches[0][1]) or "ERROR:" in output:
            raise RuntimeError(output)
        count = int(matches[0][0])
    else:
        count = completion_evidence(test, output, result.returncode)["checks"]
    total += count
    print(test, "PASS", count, flush=True)
print("REVIVAL_MODELS_PASS checks=" + str(total), run, flush=True)
