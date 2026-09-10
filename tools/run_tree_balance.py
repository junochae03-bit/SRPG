"""전체 직업의 전후 밸런스 측정. 개인 저장 파일은 사용하지 않는다."""
import subprocess
import sys
from engine_path import ROOT, engine, hidden_options

label = sys.argv[1] if len(sys.argv) > 1 else "current"
assert label in {"before", "after", "current"}
result = subprocess.run(
    [engine(), "--headless", "--path", str(ROOT / "game"), "--script",
     "res://tests/tree_balance_benchmark.gd", "--", label],
    capture_output=True, text=True, encoding="utf8", errors="replace",
    timeout=600, **hidden_options(),
)
output = result.stdout + result.stderr
(ROOT / "runtime" / f"tree-balance-{label}.log").write_text(output, encoding="utf8")
print(output[-6000:])
sys.exit(result.returncode or int("ERROR:" in output or "failures=0" not in output))
