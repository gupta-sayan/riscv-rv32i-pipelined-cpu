#!/usr/bin/env bash
# Execute from repository root; preserve every run and all failures.
set -u
evidence_dir=docs/verification/module14
mkdir -p "$evidence_dir/runs" || exit $?
log_dir=$(mktemp -d "$evidence_dir/runs/run_XXXXXXXX") || exit $?
printf 'Evidence directory: %s\n' "$log_dir"
: > "$log_dir/commands.log"
: > "$log_dir/status.log"
failed=0
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
required() { run_check "$@" || failed=1; }
sha256sum rtl/core/ex_event_mux.sv > "$log_dir/rtl_run_before.sha256" || exit $?
required baseline_compare cmp "$evidence_dir/rtl_before.sha256" "$log_dir/rtl_run_before.sha256"
required iverilog_version iverilog -V
required verilator_version verilator --version
if run_check compile iverilog -g2012 -Wall -s tb_ex_event_mux -o "$log_dir/ex_event_mux.vvp" rtl/core/ex_event_mux.sv tb/unit/tb_ex_event_mux.sv; then
    required simulation vvp "$log_dir/ex_event_mux.vvp"
else
    failed=1
    printf 'simulation skipped: compilation failed\n' >> "$log_dir/status.log"
fi
required lint_rtl verilator --lint-only --Wall --top-module ex_event_mux rtl/core/ex_event_mux.sv
required lint_tb verilator --lint-only --timing --Wall --timescale 1ns/1ps --top-module tb_ex_event_mux rtl/core/ex_event_mux.sv tb/unit/tb_ex_event_mux.sv
sha256sum rtl/core/ex_event_mux.sv > "$log_dir/rtl_after.sha256" || exit $?
required integrity_compare cmp "$log_dir/rtl_run_before.sha256" "$log_dir/rtl_after.sha256"
required final_baseline_compare cmp "$evidence_dir/rtl_before.sha256" "$log_dir/rtl_after.sha256"
printf 'OVERALL exit=%s\n' "$failed" >> "$log_dir/status.log"
cat "$log_dir/status.log"
exit "$failed"
