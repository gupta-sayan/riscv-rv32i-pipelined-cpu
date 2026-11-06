#!/usr/bin/env bash
# Execute from repository root; preserve every run and all failures.
set -u
# Optional end-to-end negative test launches a plain child run, avoiding recursion.
if [[ $# -gt 1 || (${1:-} != "" && ${1:-} != --with-negative-runner-test) ]]; then
    printf 'Usage: bash %s [--with-negative-runner-test]\n' "$0" >&2
    exit 2
fi
evidence_dir=docs/verification/module16
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
sha256sum rtl/core/wb_trace.sv > "$log_dir/rtl_run_before.sha256" || exit $?
required baseline_compare cmp "$evidence_dir/rtl_before.sha256" "$log_dir/rtl_run_before.sha256"
required iverilog_version iverilog -V
required verilator_version verilator --version
if run_check compile iverilog -g2012 -Wall -s tb_wb_trace -o "$log_dir/wb_trace.vvp" rtl/core/wb_trace.sv tb/unit/tb_wb_trace.sv; then
    required simulation vvp "$log_dir/wb_trace.vvp"
    required elaboration python3 "$evidence_dir/check_elaboration.py" "$log_dir/wb_trace.vvp"
else
    failed=1
    printf 'simulation skipped: compilation failed\n' >> "$log_dir/status.log"
fi
required waiver_scope python3 "$evidence_dir/check_waiver_scope.py" "$log_dir"
required lint_trace0_waived verilator --lint-only --Wall --top-module wb_trace "-GTRACE_EN=1'b0" "$evidence_dir/trace_disabled.vlt" rtl/core/wb_trace.sv
required lint_trace1 verilator --lint-only --Wall --top-module wb_trace "-GTRACE_EN=1'b1" rtl/core/wb_trace.sv
required lint_tb_waived verilator --lint-only --timing --Wall --timescale 1ns/1ps --top-module tb_wb_trace "$evidence_dir/trace_disabled.vlt" rtl/core/wb_trace.sv tb/unit/tb_wb_trace.sv
if [[ ${1:-} == --with-negative-runner-test ]]; then
    required negative_runner python3 "$evidence_dir/check_runner_failure.py" "$log_dir"
fi
sha256sum rtl/core/wb_trace.sv > "$log_dir/rtl_after.sha256" || exit $?
required integrity_compare cmp "$log_dir/rtl_run_before.sha256" "$log_dir/rtl_after.sha256"
required final_baseline_compare cmp "$evidence_dir/rtl_before.sha256" "$log_dir/rtl_after.sha256"
printf 'OVERALL exit=%s\n' "$failed" >> "$log_dir/status.log"
cat "$log_dir/status.log"
exit "$failed"
