# Reproducing Verification Results

This guide documents entry points inspected against the existing scripts, benches and command records. None of the simulation, lint or synthesis commands below was executed during preparation of this document.

There are two different activities:

1. Replaying unchanged test fixtures with new outputs.
2. Reconstructing an exact historical acceptance environment.

A successful fixture replay is not automatically a reproduction of the original frozen acceptance contract.

## 1. Tools and prerequisites

Recorded tools:

| Tool | Recorded version |
|---|---|
| Icarus Verilog/vvp | 12.0 stable |
| Python | 3.12.3 |
| Verilator | 5.020 |
| Yosys | 0.33, git identity `2584903a060` |

The examples also use Bash, ripgrep and standard shell utilities.

The directed programs are encoded in the verification sources and saved fixtures; reproducing those simulations does not require a RISC-V cross-compiler.

Use normal Python execution for the assertion-based model anchors. Do not disable Python assertions with optimization options or `PYTHONOPTIMIZE`.

Version strings alone do not reproduce F01: it also pins executable hashes, commands, environment and source/document identities.

All paths below are repository-relative. Run commands from the repository root, or from the root of an explicitly isolated reproduction copy where required.

Before execution:

- Verify the accepted RTL and integration-bench hashes.
- Verify other fixtures, models and scripts against their relevant saved manifests.
- Preserve existing evidence.
- Do not regenerate expected values simply to make a failing test pass.
- If a required historical input is restricted or unavailable, report that dependency.

Technical evidence derivatives are indexed in [EVIDENCE_INDEX.md](EVIDENCE_INDEX.md). The functional derivative remains PARTIAL for two legacy source identities; historical records are descriptive references unless explicitly selected.

## 2. Check the accepted design identities

The following checks only the 17 RTL files and integration bench using the selected portable manifest’s actual `sources` mapping. It does not execute lint or validate the historical F01 contract.

```bash
python3 -B - <<'PY'
from pathlib import Path
import hashlib
import json

manifest_path = Path(
    "docs/verification/module17/lint_closure/"
    "fail_closed_runner/portable_manifest.json"
)
expected_manifest_hash = (
    "09f2d79a9b585759aaf7f03f90683f131f38db0675818205ba6bd2697e7aa1a4"
)

if hashlib.sha256(manifest_path.read_bytes()).hexdigest() != expected_manifest_hash:
    raise SystemExit("Portable manifest identity mismatch")

manifest = json.loads(manifest_path.read_text())
sources = {
    name: digest
    for name, digest in manifest["sources"].items()
    if name.startswith("rtl/")
    or name == "tb/integration/tb_rv32i_core_top.sv"
}

if len(sources) != 18:
    raise SystemExit("Unexpected accepted design source count")

mismatches = [
    name for name, digest in sources.items()
    if not Path(name).is_file()
    or hashlib.sha256(Path(name).read_bytes()).hexdigest() != digest
]

if mismatches:
    raise SystemExit("Design source mismatch: " + ", ".join(mismatches))

print("Accepted design hashes match: 17 RTL files and integration bench")
PY
```

The selected manifest also pins the technical lint baseline JSON. The filter above intentionally checks only the 18 design/testbench inputs. The portable runner checks the entire 19-input contract.

## 3. Full-core integration

This is the integration command from the README, with outputs outside the repository:

```bash
set -euo pipefail

run_dir="$(mktemp -d /tmp/rv32i-reproduce.XXXXXX)"
mapfile -t rtl_sources < <(rg --files rtl -g '*.sv' | sort)

iverilog -V >"$run_dir/iverilog-version.log" 2>&1
vvp -V >"$run_dir/vvp-version.log" 2>&1

for trace in 0 1; do
    iverilog -g2012 -gassertions \
        -s tb_rv32i_core_top \
        -P "tb_rv32i_core_top.TRACE_EN=$trace" \
        -o "$run_dir/integration_trace$trace.vvp" \
        tb/integration/tb_rv32i_core_top.sv \
        "${rtl_sources[@]}" \
        >"$run_dir/integration_compile$trace.log" 2>&1

    vvp "$run_dir/integration_trace$trace.vvp" \
        >"$run_dir/integration_simulation$trace.log" 2>&1

    rg -q "^PASS ALL TRACE_EN=$trace tests=12$" \
        "$run_dir/integration_simulation$trace.log"
done

printf 'Reproduction outputs: %s\n' "$run_dir"
```

Each compile and simulation must exit zero. Each configuration must report 12 passing scenarios.

The guarded block stops after a failed command; it does not run a stale executable after a failed compile. Retain all logs on failure.

## 4. Module-level entry points

The existing unit collectors write new evidence directories under their module trees. Run them only in an isolated reproduction copy.

| Suite | Existing entry point or recorded procedure |
|---|---|
| Hazard controller | Direct compile/simulation command below; the original Module 11 report is restricted and no `run.sh` exists there. |
| Fetch controller | `bash docs/verification/module12/run.sh` |
| Pipeline registers, current source | `bash docs/verification/module13/run_current_source.sh` |
| EX event mux | `bash docs/verification/module14/run.sh` |
| Fault controller | `bash docs/verification/module15/run.sh` |
| Writeback/trace | `bash docs/verification/module16/run.sh` |

An output-relocated form of the recorded hazard-controller command is:

```bash
iverilog -g2012 -Wall -s tb_hazard_ctrl \
    -o "$run_dir/hazard.vvp" \
    rtl/core/hazard_ctrl.sv tb/unit/tb_hazard_ctrl.sv \
    >"$run_dir/hazard_compile.log" 2>&1

vvp "$run_dir/hazard.vvp" >"$run_dir/hazard_simulation.log" 2>&1
```

Use the temporary directory established in Section 3, and stop if compilation fails. Check the bench’s result counters and simulator exit; not every unit bench uses the integration bench’s `PASS ALL` marker.

Other standalone benches are under `tb/unit/`:

```text
tb_alu.sv
tb_branch_unit.sv
tb_decoder.sv
tb_dmem_sync.sv
tb_forward_unit.sv
tb_imem_sync.sv
tb_imm_gen.sv
tb_load_formatter.sv
tb_lsu_ex.sv
tb_reg_file.sv
```

Their top names match their filename stems. This is an entry-point list, not a newly validated all-unit runner. For `tb_imem_sync`, supply a unique `+IMAGE="$run_dir/imem.hex"` argument to `vvp`; the bench generates that image and its default temporary filename can collide.

Preserve existing parameter choices. Some benches contain proposal or robustness checks beyond legal architectural inputs; those checks must not silently become new ISA requirements.

### Unit baseline restrictions

- Module 12 uses `rtl_a03_baseline.sha256`; its older fingerprint remains historical.
- Module 13’s excluded legacy `run.sh` pins an older source. Use the corrected selected `run_current_source.sh` for the accepted current source. Its PRE-PUSH-008B isolated validation passed.
- The two unresolved older fetch/pipeline RTL identities do not block these current runners: the selected historical fingerprint files support comparison; old RTL bytes are not loaded.
- Modules 13 and 16 use narrowly scoped standalone lint waivers. Those waivers do not apply to the full-core F01 inventory contract.
- A report or collector’s historical conditional status must remain visible.

## 5. Directed V01–V27 and the complete saved-fixture replay

The most useful existing fixture-replay entry point is:

```bash
python3 -B docs/verification/module17/lint_closure/fail_closed_runner/run_regression.py
```

**Run it only from the root of an isolated reproduction copy.** It creates a unique directory beneath that copy’s `regression_runs/` tree.

The script reads the suite enumeration from `final_campaign/scripts/f06.py` and replays existing benches. It removes the historical `common` import and initialization from that header before evaluating the enumeration. The selected `f06.py` is support data for this entry point; direct execution of `f06.py` is historical-only because its campaign dependencies are excluded. Required inputs include:

- All accepted RTL.
- Integration bench.
- V01–V27 benches and `cases.json`.
- V15 and V23 supplemental benches.
- D01/D02 benches.
- Assertion wrappers and `cpu_checker.sv`.

It does not regenerate the saved expectations or invoke frozen lint acceptance.

The recorded enumeration comprises 70 positive simulations and ten expected-negative simulations. To establish a successful new replay, inspect the newly printed evidence directory and require:

- 80 result records.
- Every `pass_` value true.
- Every compilation exit zero.
- Positive simulator exits zero.
- Negative simulator exits one with the designated marker.
- 414 positive case/configuration checks and ten expected negatives.
- Positive `PROPERTY_EVAL` observations for every ID P0–P23 across the positive assertion wrappers, with designated markers for all ten negatives.

**Do not rely on this collector’s process exit alone.** Its source records per-result outcomes without making the final process exit a complete acceptance gate.

The separate model-anchor entry point is:

```bash
python3 -B docs/verification/module17/full_campaign/scripts/check_model.py
```

It should exit zero and print:

```text
PASS ALL MODEL ANCHORS cases=12
```

The fixture-replay collector does not run this anchor command itself.

### Historical campaign generation

These excluded paths are descriptive historical orchestration references, not executable procedures supplied by the technical delivery:

| Script | Dependency and effect |
|---|---|
| `full_campaign/scripts/run_group.py N N` | Requires initialized state and predecessor status; regenerates a group’s fixtures and updates reports/dashboard. |
| `full_campaign/scripts/final_regression.py` | Replays group generation and supplements, then updates campaign state. |
| `full_campaign/scripts/run_iv01.py` | Requires existing baseline/state; runs the 38-check IV01 batch and updates status/history records. |
| `full_campaign/scripts/campaign.py` | Contains initialization and broad protected-file baseline handling. |

These paths are under `docs/verification/module17/`.

The old campaign baselines currently differ at R01, T01 and the decision register. An ordinary copy of the current tree therefore does not reconstruct that historical baseline.

Do not rewrite the protected manifests, clear state or reinitialize a preserved campaign to make its integrity gate pass. Exact historical generation requires its complete matching inputs in a separately qualified private environment.

## 6. Assertions and expected-negative tests

F02 uses:

```text
docs/verification/module17/final_campaign/tests/cpu_checker.sv
docs/verification/module17/final_campaign/tests/checked_legal.sv
docs/verification/module17/final_campaign/tests/checked_injected.sv
```

`checked_legal` wraps the integration bench. `checked_injected` wraps the D02 packet-injection bench.

| `MUTATION` | Changed checker observation | Required failure |
|---|---|---|
| 1 | Selector A | `CHECKER_FAIL P1` |
| 2 | Nonready diagnostic | `CHECKER_FAIL P4` |
| 3 | Sticky-state observation | `CHECKER_FAIL P19` |
| 4 | Hold request | `CHECKER_FAIL P8` |
| 5 | EX event-source exclusivity | `CHECKER_FAIL P9` |

Each mutation runs in both trace configurations, giving ten expected-negative simulations.

For example, this is an output-relocated form of the recorded mutation-2 invocation:

```bash
iverilog -g2012 -gassertions \
    -s checked_legal \
    -P checked_legal.TRACE_EN=1 \
    -P checked_legal.MUTATION=2 \
    -o "$run_dir/mutation2_trace1.vvp" \
    docs/verification/module17/final_campaign/tests/checked_legal.sv \
    docs/verification/module17/final_campaign/tests/cpu_checker.sv \
    tb/integration/tb_rv32i_core_top.sv \
    "${rtl_sources[@]}" \
    >"$run_dir/mutation2_compile.log" 2>&1

if vvp "$run_dir/mutation2_trace1.vvp" \
    >"$run_dir/mutation2_simulation.log" 2>&1; then
    simulation_status=0
else
    simulation_status=$?
fi

test "$simulation_status" -eq 1
rg -q 'CHECKER_FAIL P4 ' "$run_dir/mutation2_simulation.log"
```

Use the Section 3 setup and stop on compilation failure.

A crash or arbitrary exit one is not a successful negative test. The designated property marker must match.

Positive wrappers use `MUTATION=0`. The complete replay includes legal and injected positives; all 24 property IDs must have positive evaluations. Mutation failures alone do not demonstrate positive property coverage.

The original `final_campaign/scripts/f02.py` also updates historical campaign state and checks its protected baseline. It is not a current-tree standalone command.

## 7. Lint acceptance

### Qualified portable technical procedure

PRE-PUSH-008F qualified the selected `portable_runner.py`, `portable_manifest.json` and `test_portable_runner.py`. Four configurations matched complete diagnostic multisets; 46 controls passed twice (41 intended rejections and five positive controls). Historical F01 closure is separate.

The pinned tools are Verilator 5.020, its companion executable and Perl, with exact fingerprints in the portable manifest. A matching version string alone is insufficient. The controlled environment is `PATH=/usr/bin:/bin`, `LC_ALL=C`, `LANG=C`. Other tool builds are incompatible until separately qualified.

From the repository root:

```bash
set -euo pipefail
lint_parent="$(mktemp -d /tmp/rv32i-portable.XXXXXX)"
python3 -B docs/verification/module17/lint_closure/fail_closed_runner/portable_runner.py \
    all --root "$PWD" --output "$lint_parent/lint"
```

The child output path must not already exist and must be outside the project root. The runner accepts `all`, `core_trace0`, `core_trace1`, `bench_trace0` or `bench_trace1`. It can infer the root from its script location; the explicit `--root` above avoids ambiguity.

Acceptance requires runner exit zero and JSON `status="PASS"`, correct source/tool/command/environment identities, native exit one, empty stdout, complete well-framed stderr and exact diagnostic multisets. Expected warning counts are 27/5/49/27, but counts alone are insufficient. Rejection exits two; unexpected implementation/environment errors exit three.

To repeat the qualification suite, use an isolated technical copy and a fresh external child path:

```bash
python3 -B docs/verification/module17/lint_closure/fail_closed_runner/test_portable_runner.py \
    --root "$PWD" --output "$lint_parent/qualification"
```

Require exit zero, `qualification.json` status PASS, all four native configurations matched, 46 controls with no failures, and unchanged isolated input trees. The suite includes actual CLI checks and explicitly identified offline diagnostic/metadata/timeout injections. It does not rerun the historical control suite.

The selected technical lint validation contains the appended portable qualification and external artifact-index identity. Original qualification raw logs remain external dependencies; a new run creates its own logs and identities.

### Historical-only F01 contract

The original frozen runner, manifest and inventories remain restricted historical inputs. They pin 58 source/document identities, tool binaries/version, complete commands, environment and the original working root.

Current `docs/DECISIONS.md` differs from that frozen document identity. The original invocation of `runner.py all` is therefore historical-only and is not supplied as a runnable technical-delivery command. It creates evidence even on preflight rejection.

Do not alter the original fingerprints or warning inventories. Portable technical qualification does not replace, rebaseline or reopen historical F01 CLOSED acceptance. Neither procedure is warning-free lint.

## 8. Generic synthesis

The saved F04 scripts contain fixed output paths. Do not execute an original saved script blindly: changing the current directory does not necessarily relocate its outputs.

The following transcribes the existing F04 pass sequence with generated scripts and outputs relocated to the Section 3 temporary directory:

```bash
for trace in 0 1; do
    cat >"$run_dir/synth_trace$trace.ys" <<EOF
read_verilog -sv ${rtl_sources[*]}
chparam -set TRACE_EN $trace rv32i_core_top
hierarchy -check -top rv32i_core_top
proc
flatten
write_json $run_dir/preopt_trace$trace.json
opt
check -assert
synth -top rv32i_core_top -flatten -noabc
check -assert
stat
write_json $run_dir/netlist_trace$trace.json
write_verilog -noattr $run_dir/netlist_trace$trace.v
EOF

    yosys -s "$run_dir/synth_trace$trace.ys" \
        >"$run_dir/synthesis_trace$trace.log" 2>&1
done
```

Review the generated scripts before execution. This output relocation is not a new synthesis result or a promise of identical resource counts.

The recorded runs exited zero and reported no structural problems. Preserve the complete logs and inspect warnings and `check -assert` outcomes.

The selected top excludes external IMEM/DMEM arrays. This procedure supplies no target technology, clock constraints or STA, and therefore no physical timing signoff.

The original F04 input predates R01’s formatting change. Exact historical byte-level reproduction requires its matching source baseline; a run using current accepted bytes is a new run.

## 9. Exit interpretation and evidence retention

| Observation | Interpretation |
|---|---|
| Compiler nonzero | Build failed; do not simulate an old executable. |
| Positive simulation zero plus expected checks/marker | Successful result for that bench/configuration. |
| Negative simulation one plus designated property marker | Expected violation detected. |
| Native Verilator one | Expected only within the fully matched inventory contract; not sufficient alone. |
| Frozen runner rejection | Contract/context mismatch or acceptance failure; preserve reason and logs. |
| Generic synthesis zero | Inspect structural checks and logs; not equivalence or timing proof. |
| Collector zero | Does not necessarily mean all collected stages passed. |
| Timeout, missing tool or malformed output | Failure requiring investigation, not PASS. |

For every new evidence run retain tool identities, actual arguments, source hashes, compile and execution exits, complete logs and expected-outcome checks.

Keep historical records unchanged. Regenerated fixtures, relocated commands and new document baselines must be identified as new reproduction contexts rather than silently substituted for original evidence.
