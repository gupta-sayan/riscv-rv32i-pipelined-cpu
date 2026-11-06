#!/usr/bin/env bash
# Run from repository root. Keep each run, including failures, separately.
set -u -o pipefail
evidence_dir=docs/verification/module13
mkdir -p "$evidence_dir/current_source_runs/5fbb22be" || exit $?
log_dir=$(mktemp -d "$evidence_dir/current_source_runs/5fbb22be/run_XXXXXXXX") || exit $?
printf 'Evidence directory: %s\n' "$log_dir"
: > "$log_dir/status.log"
: > "$log_dir/commands.log"
failed=0
baseline="$evidence_dir/rtl_current_5fbb22be.sha256"
historical="$evidence_dir/rtl_before.sha256"
printf '%s\n' 'M17-11 current-source baseline 5fbb22be' \
    'Current SHA-256: 5fbb22be5137cbd7a9e7455ed1d76558623375fc4e89b5e8f36e7564cc620b15' \
    'Historical SHA-256: 26674469035167a196067538ab8484aa7396e19c854c7682ce1b000b3a1b6836' > "$log_dir/baseline.log" || exit $?
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
check_manifest() {
    printf '%s  rtl/core/pipeline_regs.sv\n' "$2" | cmp "$1" -
}
required current_manifest check_manifest "$baseline" 5fbb22be5137cbd7a9e7455ed1d76558623375fc4e89b5e8f36e7564cc620b15
required historical_manifest check_manifest "$historical" 26674469035167a196067538ab8484aa7396e19c854c7682ce1b000b3a1b6836
required source_before sha256sum rtl/core/pipeline_regs.sv
cp "$log_dir/source_before.log" "$log_dir/rtl_run_before.sha256" || exit $?
if run_check historical_compare cmp "$historical" "$log_dir/rtl_run_before.sha256"; then
    failed=1
else
    [[ $? -eq 1 ]] || failed=1
fi
required baseline_compare cmp "$baseline" "$log_dir/rtl_run_before.sha256"
required iverilog_version iverilog -V
required verilator_version verilator --version
if run_check compile iverilog -g2012 -Wall -s tb_pipeline_regs -o "$log_dir/pipeline_regs.vvp" rtl/core/pipeline_regs.sv tb/unit/tb_pipeline_regs.sv; then
    required simulation vvp "$log_dir/pipeline_regs.vvp"
    required elaboration python3 "$evidence_dir/check_elaboration.py" "$log_dir/pipeline_regs.vvp"
    required elaboration_modes python3 "$evidence_dir/test_elaboration_modes.py" "$log_dir/pipeline_regs.vvp" "$log_dir"
else
    failed=1
    printf 'simulation/elaboration skipped: compile failed\n' >> "$log_dir/status.log"
fi
required waiver_scope python3 "$evidence_dir/check_waiver_scope.py" "$log_dir"
required waiver_modes python3 "$evidence_dir/test_waiver_scope_modes.py" "$log_dir"
required lint_trace0_waived verilator --lint-only --Wall --top-module pipeline_regs "-GTRACE_EN=1'b0" "$evidence_dir/trace_disabled.vlt" rtl/core/pipeline_regs.sv
required lint_trace1 verilator --lint-only --Wall --top-module pipeline_regs "-GTRACE_EN=1'b1" rtl/core/pipeline_regs.sv
required lint_tb_waived verilator --lint-only --timing --Wall --timescale 1ns/1ps --top-module tb_pipeline_regs "$evidence_dir/trace_disabled.vlt" rtl/core/pipeline_regs.sv tb/unit/tb_pipeline_regs.sv
required source_after sha256sum rtl/core/pipeline_regs.sv
cp "$log_dir/source_after.log" "$log_dir/rtl_after.sha256" || exit $?
required final_current_manifest check_manifest "$baseline" 5fbb22be5137cbd7a9e7455ed1d76558623375fc4e89b5e8f36e7564cc620b15
required integrity_compare cmp "$log_dir/rtl_run_before.sha256" "$log_dir/rtl_after.sha256"
required final_baseline_compare cmp "$baseline" "$log_dir/rtl_after.sha256"
printf 'OVERALL exit=%s\n' "$failed" >> "$log_dir/status.log"
cat "$log_dir/status.log"
exit "$failed"
