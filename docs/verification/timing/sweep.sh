#!/bin/bash
# Clock sweep for the out-of-context timing study.
# Usage (from anywhere, with Vivado 2023.2 on PATH):
#   docs/verification/timing/sweep.sh [out_dir]
# Writes one Vivado run per (period, TRACE_EN) under out_dir (default ./timing_runs)
# and appends one line per run to out_dir/results.csv. Nothing is written to the repo.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
out=$(mkdir -p "${1:-timing_runs}" && cd "${1:-timing_runs}" && pwd)
[ -f "$out/results.csv" ] || echo "period_ns,trace_en,wns_ns,whs_ns,luts,ffs,ramb" > "$out/results.csv"
for trace in 0 1; do
  for p in 10 8 6.67 5; do
    echo "=== period $p ns, TRACE_EN=$trace ==="
    vivado -mode batch -nojournal -log "$out/p${p}_t${trace}.log" -source "$here/timing.tcl" \
      -tclargs "$p" "$trace" "$repo" "$out/p${p}_t${trace}" > /dev/null 2>&1
  done
done
column -s, -t "$out/results.csv"
