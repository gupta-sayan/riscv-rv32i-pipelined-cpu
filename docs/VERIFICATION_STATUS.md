# Verification Status

The technology-independent RV32I RTL milestone was **conditionally accepted on November 5, 2026**. Target-specific FPGA/ASIC timing qualification remains deferred.

This document summarizes recorded evidence. It distinguishes historical execution, later review reruns and work that has not been established.

## Accepted source baseline

The post-R01/T01 design baseline comprises 17 production RTL files and the integration testbench. The selected [portable manifest](verification/module17/lint_closure/fail_closed_runner/portable_manifest.json) contains their unchanged identities under `sources`; the additional JSON input is the technical lint evidence baseline. Its SHA-256 is:

```text
09f2d79a9b585759aaf7f03f90683f131f38db0675818205ba6bd2697e7aa1a4
```

The original frozen F01 manifest is a restricted historical identifier, not a runnable delivery dependency.

All 18 design/testbench hashes matched during the read-only preparation of this summary. That comparison is an integrity check, not a new simulation result.

The original architecture remains authoritative; the technical architecture is its companion restatement.

## Unit-level verification

Sixteen standalone benches are present under `tb/unit/`. The integrated core is tested separately.

Available standalone reports retain these scopes:

| Module | Recorded standalone scope |
|---|---|
| Hazard controller | PASS for binary combinational behavior, including an exhaustive binary-input sweep; strict lint passed in the recorded runs. |
| Fetch controller | Conditional standalone result with an A03 source baseline; integration obligations were recorded separately. |
| Pipeline registers | Functional verification and cross-configuration checks; trace-disabled lint uses explicitly scoped waivers. Historical and current-source fingerprints differ. |
| EX event mux | PASS for standalone binary behavior and strict lint; defensive simultaneous-source behavior is not a new architectural tie-break requirement. |
| Fault controller | PASS for standalone controller behavior and strict lint; CPU integration is a separate evidence scope. |
| Writeback/trace | Functional and cross-configuration verification with nine scoped external lint waivers; enabled RTL lint remained unwaived. |

Bench sources also exist for the other ten standalone modules. File presence alone is not a result, so this summary does not assign additional independent per-module signoff from the existence of those benches.

The later full-core acceptance does not rewrite old standalone results or turn scoped-waiver results into unwaived strict-lint passes.

## Full-core and directed verification

The original integration bench runs 12 scenarios in each static trace configuration. It uses synchronous instruction/data RAMs and checks register state, memory transactions, faults and retirement behavior.

The V01–V27 campaign covers instruction legality and execution, memory lanes and boundaries, forwarding, load-use control, redirects, terminal ordering, reset and trace-mode equivalence.

It contains 169 natural programs per trace configuration. Supplemental checks cover deliberately injected diagnostic conditions and additional reset phases.

### V23 accepted-fetch supplement

The original reset coverage did not demonstrate cancellation of an instruction fetch that had already been accepted.

The supplement observes an accepted synchronous read and matching live IF/ID slot, then applies reset before the next transfer. It checks flush, restart and absence of stale effects in both trace modes.

The recorded IV01 batch passed 38 case/configuration executions: 14 V23-related checks and 24 original integration checks.

## Later complete regression

The later recorded replay contains:

| Suite | Positive case/configuration checks |
|---|---:|
| Original integration | 24 |
| V01–V27 natural programs | 338 |
| V15 original A01 supplement | 2 |
| V23 original reset supplement | 10 |
| V23 accepted-fetch reset | 2 |
| D01 selector wrappers | 2 |
| D02 actual-generator injection epochs | 6 |
| F02 positive legal/injected wrappers | 30 |
| **Total** | **414** |

These checks ran across **70 positive simulations**. All recorded positive compiles and simulations exited zero.

There were also **ten expected-negative F02 simulations**. Each exited one with its designated property failure.

The 414 checks are not 414 unique instruction programs. They include repeated programs under assertion wrappers and aggregate supplemental cases.

## F01–F08 status

| Item | Current disposition and evidence scope |
|---|---|
| **F01** | **CLOSED** through approved-warning inventory acceptance. |
| **F02** | PASS for executable assertions, positive evaluation of all 24 property IDs and ten expected-negative checks. |
| **F03** | **CLOSED** under the accepted diagnostic synthesis disposition. |
| **F04** | PASS for generic synthesis and reported structural checks in both trace configurations. |
| **F05** | **PARTIAL / DEFERRED** under FINAL-B01. |
| **F06** | PASS for the recorded complete engineering regression within its stated suite scope. |
| **F07** | PASS for historical source/evidence integrity and result reconciliation at its recorded checkpoints. |
| **F08** | PASS for reporting and package validation; not an additional correctness or timing certification. |

### Lint acceptance

| Configuration | Native exit | Warning occurrences |
|---|---:|---:|
| Core, trace disabled | 1 | 27 |
| Core, trace enabled | 1 | 5 |
| Bench, trace disabled | 1 | 49 |
| Bench, trace enabled | 1 | 27 |

The accepted inventory contains 108 occurrences across 50 primary diagnostic identities.

Acceptance compares complete diagnostic records and multiplicities under pinned source, tool, command and environment identities. It is not a warning-count-only check.

The runner validation recorded 35 cases: 31 rejection cases and four positive parser cases, covering 12 required negative-control families. These are separate from the ten F02 mutation simulations.

F01 is not warning-free lint. Native warnings and exit one remain visible.

PRE-PUSH-008F separately qualified the portable technical lint procedure: four matching configurations and 46 controls passing twice. This is new qualification, not a rerun or replacement of historical F01 acceptance.

The appended [portable qualification record](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_VALIDATION.json) pins the new runner, manifest and suite. Its 41 rejection and five positive controls passed in each suite run; the four parser positives are distinct from the additional relocated-root positive.

### Assertion scope

All 24 property IDs, P0–P23, had positive evaluations. Five observation-mutation families were detected in both trace configurations.

Property evaluation counts are simulation observations, not formal proof or code/toggle coverage percentages. The negative tests do not exhaustively validate every checker predicate.

### Synthesis scope

Recorded Yosys 0.33 results:

| Trace | Generic cells | Generic sequential bits/cells |
|---|---:|---:|
| Disabled | 8,407 | 1,380 |
| Enabled | 8,799 | 1,884 |

The core’s external memory arrays were not synthesized as target RAM primitives. These counts are not FPGA utilization or ASIC area.

The original F04 run predates R01’s terminal-newline correction. It is not a newly executed synthesis result for the later source bytes.

## Later independent review reruns

A subsequent review recorded:

- Eight positive simulations containing 34 positive checks: integration, D01, D02 and accepted-fetch reset.
- Two mutation-2/P4 expected-negative checks.
- Four native lint diagnostic replays matching the saved inventories.

The lint replays relocated the output directory, so they were diagnostic reproductions rather than fresh acceptance of the complete frozen command/document contract.

That review also reconciled the saved full-regression records. It did not rerun all 414 positives, all ten mutations, the complete 35-case runner suite or Yosys synthesis.

No simulation, lint or synthesis was rerun while preparing these supporting document drafts.

## Preserved failures and corrections

Historical evidence retains:

- Subword-store oracle truncation correction.
- Redirect checking corrected for targets that terminate in ID.
- Accepted-fetch reset coverage deficiency and its supplement.
- Initial reset checking corrected to sample registered state after synchronous-reset updates.
- An F02 coverage-export failure corrected without changing assertion predicates.
- Original lint failures and rejected waiver approaches.

No confirmed functional RTL defect remained in the recorded final campaigns. This is a bounded observation, not proof that no defect exists.

## Remaining limitations

The evidence does not establish:

- Exhaustive instruction-encoding, operand or program coverage.
- Exhaustive reset-edge or X/Z behavior.
- Formal verification or netlist equivalence.
- Post-synthesis simulation.
- External ISA certification.
- FPGA/ASIC implementation or hardware testing.
- Quantitative timing, slack, WNS or Fmax.

The simulation clock period is stimulus timing, not a hardware performance result.

FINAL-B01 remains APPROVED. Before technology-specific timing acceptance, both critical paths, target constraints and memory behavior require quantitative qualification.

## Delivered evidence qualification

The PRE-PUSH-008C functional derivative is **PARTIAL**: five legacy-fingerprint entries refer to two unavailable older RTL identities (`rtl/core/pc_fetch.sv` and `rtl/core/pipeline_regs.sv`). The 18 accepted design/bench hashes and all 80 replay records reconcile. Those missing older bytes are historical dependencies, not inputs required by the current-source procedures below.

| Evidence group | Evidence | Manifest | Validation |
|---|---|---|---|
| Functional — PARTIAL | [Evidence](verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_EVIDENCE.json) | [Manifest](verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_MANIFEST.json) | [Validation](verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_VALIDATION.json) |
| Historical lint — validated | [Evidence](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_EVIDENCE.json) | [Manifest](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_MANIFEST.json) | [Validation](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_VALIDATION.json) |
| Implementation/integrity — validated | [Evidence](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_EVIDENCE.json) | [Manifest](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_MANIFEST.json) | [Validation](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_VALIDATION.json) |

This presentation preserves the difference between historical results, later review reruns, PRE-PUSH-008B source-presentation validation and the separate portable lint qualification. No additional simulation, lint or synthesis is claimed by this documentation correction.

## Historical document compatibility

The current `docs/DECISIONS.md` differs from the document pinned by the original F01 contract. The saved acceptance remains historical evidence, but the unchanged runner is expected to reject the current document baseline.

Older status files still contain pending-acceptance language. Those snapshots predate the later conditional acceptance summarized here and are not rewritten.

See `EVIDENCE_INDEX.md` for original evidence locations and delivery restrictions, and `REPRODUCING.md` for execution boundaries.
