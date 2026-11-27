# Timing study files

Out-of-context Vivado flow and recorded results for the analysis in [`docs/TIMING_ANALYSIS.md`](../../TIMING_ANALYSIS.md).

| File | Purpose |
|---|---|
| `timing.tcl` | One run: synth, place, route and reports at a given period and `TRACE_EN` |
| `sweep.sh` | Runs `timing.tcl` at 10, 8, 6.67 and 5 ns in both trace modes |
| `timing_top.sv` | Timing-only wrapper: `rv32i_core_top` + `dmem_sync` + `timing_imem` |
| `timing_imem.sv` | Timing-only IMEM: `imem_sync` behavior plus a loader write port, so synthesis keeps a real RAM |
| `results/*.csv` | Every recorded run (period, trace, WNS, WHS, LUTs, FFs, block RAMs) |
| `tools/regress_replay.py` | Out-of-tree replay of the f06 regression item list with Icarus; writes only to `/tmp` |
| `tools/lint_compare.sh` | Runs the portable lint runner's four Verilator commands and prints normalized warnings |

The wrapper files are not production RTL and are not part of the accepted source identities.

## Reproduce

Requires Vivado 2023.2 on `PATH`. Outputs go to the directory you pass, never into the repository.

```bash
# One run: 10 ns, TRACE_EN=0
vivado -mode batch -nojournal -source docs/verification/timing/timing.tcl \
  -tclargs 10 0 "$PWD" /tmp/timing_runs/p10_t0

# Full sweep
docs/verification/timing/sweep.sh /tmp/timing_runs
```

Each run writes `timing_summary.rpt`, `path_worst.rpt`, `path_dmem_addr.rpt`, `path_dmem_ctrl.rpt`, `path_imem_addr.rpt`, `path_imem_ctrl.rpt`, `path_fetch_pc.rpt` and `util_route.rpt`, and appends one line to `results.csv` in the parent output directory.

## Result files

| File | RTL | Contents |
|---|---|---|
| `v1_baseline_results.csv` | `95f032f` (v1) | 8-run sweep, then confirmations at 12.5, 13 and 14 ns |
| `v2_fixAB_results.csv` | v2 (fixes A + B) | 10 ns and 12.5 ns, `TRACE_EN=0` |
| `v2_fixABC_REVERTED_results.csv` | v2 + fix C | 10 ns, `TRACE_EN=0`; fix C was reverted |
| `v2_fixAB_confirmed_results.csv` | v2 (fixes A + B) | Confirmations at 10.75 ns (`TRACE_EN=0`) and 12 ns (`TRACE_EN=1`) |

Columns: `period_ns, trace_en, wns_ns, whs_ns, luts, ffs, ramb`. Raw Vivado reports are kept outside the repository.
