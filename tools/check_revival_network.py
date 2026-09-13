"""Two real peers exercise held rescue, persistent injuries and separate town treatments."""
from pathlib import Path
import re
import socket
import subprocess
import time
from engine_path import ROOT, engine, hidden_options

run = ROOT / "runtime" / ("revival-network-" + str(time.time_ns()))
run.mkdir(parents=True)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
    probe.bind(("127.0.0.1", 0))
    port = probe.getsockname()[1]
processes = []
logs = []
try:
    for role in ("host", "guest"):
        folder = run / role
        folder.mkdir()
        log = (folder / "run.log").open("w", encoding="utf-8")
        logs.append(log)
        command = [engine(), "--headless", "--path", str(ROOT / "game"), "--script",
                   "res://tests/revival_network.gd", "--", "--role=" + role,
                   "--directory=" + str(folder), "--port=" + str(port)]
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, **hidden_options())
        processes.append((role, process))
        if role == "host":
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                output = (folder / "run.log").read_text("utf-8", errors="replace")
                if "REVIVAL_HOST_READY" in output:
                    break
                if process.poll() is not None:
                    raise RuntimeError(output)
                time.sleep(.1)
            else:
                raise RuntimeError("Host did not start: " + str(folder / "run.log"))
    deadline = time.monotonic() + 100
    for role, process in processes:
        code = process.wait(timeout=max(1, deadline - time.monotonic()))
        output = (run / role / "run.log").read_text("utf-8", errors="replace")
        matches = re.findall(r"REVIVAL_NETWORK_TESTS role=" + role + r" checks=(\d+) failures=(\d+)", output)
        if code or len(matches) != 1 or int(matches[0][0]) < 20 or int(matches[0][1]) or "SCRIPT ERROR" in output or "ERROR:" in output:
            raise RuntimeError(role + " failed: " + output)
        print(role, "PASS", matches[0][0], "checks", flush=True)
    print("REVIVAL_NETWORK_PASS", run, flush=True)
finally:
    for _, process in processes:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
    for log in logs:
        log.close()
