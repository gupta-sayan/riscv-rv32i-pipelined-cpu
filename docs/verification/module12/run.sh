#!/usr/bin/env bash
# Run from repository root; preserve every command and exit status.
set -u
evidence_dir=docs/verification/module12
mkdir -p "$evidence_dir/runs" || exit $?
log_dir=$(mktemp -d "$evidence_dir/runs/run_XXXXXXXX") || exit $?
printf 'Evidence directory: %s\n' "$log_dir"
: > "$log_dir/commands.log"
: > "$log_dir/status.log"
run_check() {
    local name="$1"
    shift
    printf '%q ' "$@" >> "$log_dir/commands.log"
    printf '\n' >> "$log_dir/commands.log"
    "$@" > "$log_dir/$name.log" 2>&1
    local result=$?
    printf '%s exit=%s\n' "$name" "$result" >> "$log_dir/status.log"
    return "$result"
}
# Both fingerprints are controlled evidence; never regenerate them from RTL.
failed=0
run_required() {
    run_check "$@" || failed=1
}
sha256sum rtl/core/pc_fetch.sv > "$log_dir/rtl_run_before.sha256" || exit $?
run_required rtl_current_before_compare cmp "$evidence_dir/rtl_a03_baseline.sha256" "$log_dir/rtl_run_before.sha256"
run_required iverilog_version iverilog -V
run_required verilator_version verilator --version
# Compile into this run's directory so a failed compile cannot reuse stale output.
if run_check iverilog_compile iverilog -g2012 -Wall -s tb_pc_fetch -o "$log_dir/tb_pc_fetch.vvp" rtl/core/pc_fetch.sv tb/unit/tb_pc_fetch.sv; then
    run_required simulation vvp "$log_dir/tb_pc_fetch.vvp"
else
    failed=1
    printf 'simulation SKIPPED: compilation failed\n' >> "$log_dir/status.log"
fi
run_required verilator_rtl verilator --lint-only --Wall --top-module pc_fetch rtl/core/pc_fetch.sv
run_required verilator_tb verilator --lint-only --timing --Wall --timescale 1ns/1ps --top-module tb_pc_fetch rtl/core/pc_fetch.sv tb/unit/tb_pc_fetch.sv
sha256sum rtl/core/pc_fetch.sv > "$log_dir/rtl_after.sha256" || exit $?
run_required rtl_current_after_compare cmp "$evidence_dir/rtl_a03_baseline.sha256" "$log_dir/rtl_after.sha256"
run_required rtl_run_compare cmp "$log_dir/rtl_run_before.sha256" "$log_dir/rtl_after.sha256"
# A historical difference is informational. An unreadable evidence file is an error.
run_check rtl_historical_compare cmp "$evidence_dir/rtl_before.sha256" "$log_dir/rtl_after.sha256"
historical_status=$?
case "$historical_status" in
    0) printf 'HISTORICAL: original fingerprint matches current RTL\n' >> "$log_dir/status.log" ;;
    1) printf 'HISTORICAL: original fingerprint differs; informational, not an integrity failure\n' >> "$log_dir/status.log" ;;
    *) failed=1
       printf 'ERROR: historical evidence comparison could not be completed\n' >> "$log_dir/status.log" ;;
esac
printf 'OVERALL exit=%s (current A03 baseline, same-run integrity, simulation, lint)\n' "$failed" >> "$log_dir/status.log"
cat "$log_dir/status.log"
exit "$failed"
