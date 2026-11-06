#!/usr/bin/env python3
"""Retain every run, including failures; never modify RTL or prior evidence."""
import hashlib
from pathlib import Path
import shlex
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[4]
BASE = Path(__file__).resolve().parent
OUT = Path(tempfile.mkdtemp(prefix="run_", dir=BASE))
print(f"Evidence: {OUT}", flush=True)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

protected = sorted(p for directory in (ROOT / "rtl", ROOT / "tb", ROOT / "docs")
                   for p in directory.rglob("*") if p.is_file() and BASE not in p.parents)
before = {str(p.relative_to(ROOT)): digest(p) for p in protected}

def manifest(name, values):
    (OUT / name).write_text("".join(f"{value}  {key}\n" for key, value in values.items()))

manifest("protected_before.sha256", before)
manifest("verification_sources.sha256", {str(p.relative_to(ROOT)): digest(p)
         for p in (Path(__file__).resolve(), BASE / "tb_d01.sv")})

def run(args, log):
    with (OUT / "commands.log").open("a") as f:
        f.write(shlex.join([str(a) for a in args]) + "\n")
    result = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (OUT / log).write_bytes(result.stdout)
    with (OUT / "exit_codes.log").open("a") as f:
        f.write(f"{log}: {result.returncode}\n")
    return result.returncode, result.stdout.decode(errors="replace")

run(["iverilog", "-V"], "iverilog_version.log")
run(["vvp", "-V"], "vvp_version.log")
run(["git", "rev-parse", "HEAD"], "git_head.log")
run(["git", "status", "--short"], "git_status.log")
sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "rtl").rglob("*.sv"))
results = []
for label, top, bench, parameters, marker in [
    ("d01", "tb_d01", BASE / "tb_d01.sv", [], "PASS ALL D01 selectors=4 checks=8"),
    ("trace0", "tb_rv32i_core_top", ROOT / "tb/integration/tb_rv32i_core_top.sv",
     ["-P", "tb_rv32i_core_top.TRACE_EN=0"], "PASS ALL TRACE_EN=0 tests=12"),
    ("trace1", "tb_rv32i_core_top", ROOT / "tb/integration/tb_rv32i_core_top.sv",
     ["-P", "tb_rv32i_core_top.TRACE_EN=1"], "PASS ALL TRACE_EN=1 tests=12"),
]:
    binary = OUT / f"{label}.vvp"
    rc, _ = run(["iverilog", "-g2012", "-s", top, *parameters, "-o", str(binary),
                 str(bench.relative_to(ROOT)), *sources], f"compile_{label}.log")
    passed = False
    if rc == 0:
        rc, output = run(["timeout", "30s", "vvp", str(binary)], f"simulation_{label}.log")
        print(output, end="", flush=True)
        passed = rc == 0 and marker in output.splitlines()
    results.append((label, passed))

after = {str(p.relative_to(ROOT)): digest(p) for p in protected}
manifest("protected_after.sha256", after)
unchanged = before == after
(OUT / "integrity.log").write_text(f"Protected files checked: {len(before)}\nUnchanged: {unchanged}\n")
ok = all(passed for _, passed in results) and unchanged
(OUT / "status.log").write_text("".join(f"{label}: {'PASS' if passed else 'FAIL'}\n"
    for label, passed in results) + f"protected_unchanged: {unchanged}\nexit_status={0 if ok else 1}\n")
sys.exit(0 if ok else 1)
