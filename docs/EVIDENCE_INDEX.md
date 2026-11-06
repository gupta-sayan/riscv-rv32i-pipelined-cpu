# Evidence Index

This index connects technical claims to their source, execution and integrity records. Paths are repository-relative.

## Reading the index

- **Selected source:** technical source or fixture in the proposed delivery at its existing path.
- **Restricted original:** preserved historical material that is not automatically part of the technical delivery.
- **Technical derivative:** a separately identified presentation with original mappings, validation scope and explicit historical dependencies.

Restricted paths below are lookup references for authorized historical review, not promises that those paths will exist in the final delivery.

The following nine technical derivatives exist. Functional evidence remains PARTIAL; lint and implementation/integrity reconciliation passed within their defined scopes.

| Evidence group | Evidence | Manifest | Validation |
|---|---|---|---|
| Functional — PARTIAL | [Evidence](verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_EVIDENCE.json) | [Manifest](verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_MANIFEST.json) | [Validation](verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_VALIDATION.json) |
| Historical lint — validated | [Evidence](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_EVIDENCE.json) | [Manifest](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_MANIFEST.json) | [Validation](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_VALIDATION.json) |
| Implementation/integrity — validated | [Evidence](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_EVIDENCE.json) | [Manifest](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_MANIFEST.json) | [Validation](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_VALIDATION.json) |

PRE-PUSH-008F separately qualified the portable technical lint procedure: four matching configurations and 46 controls passing twice. This is new qualification, not a rerun or replacement of historical F01 acceptance.

Portable sources: [runner](verification/module17/lint_closure/fail_closed_runner/portable_runner.py), [manifest](verification/module17/lint_closure/fail_closed_runner/portable_manifest.json), [qualification suite](verification/module17/lint_closure/fail_closed_runner/test_portable_runner.py).

The PRE-PUSH-008C functional derivative is **PARTIAL**: five legacy-fingerprint entries refer to two unavailable older RTL identities (`rtl/core/pc_fetch.sv` and `rtl/core/pipeline_regs.sv`). The 18 accepted design/bench hashes and all 80 replay records reconcile. Those missing older bytes are historical dependencies, not inputs required by the current-source procedures below.

All original report, run-directory, archive and frozen-contract paths below are descriptive restricted historical lookup references, not delivered navigation or executable dependencies. Source/fixture/helper paths are selected only as specified in the final technical selection. Original raw records referenced inside JSON manifests have the same restriction.

## 1. Unit-level verification

**Established:** standalone behavior within each report’s stated scope, including conditional results and scoped lint dispositions.

**Sources:** `tb/unit/`. All 16 benches are selected. The six available module-report scopes are distinguished from the other ten benches, for which source presence alone does not establish a standalone executed result.

**Original reports:** `docs/verification/module11/REPORT.md` through `module16/REPORT.md`.

Useful entry points:

```text
docs/verification/module12/run.sh
docs/verification/module13/run_current_source.sh
docs/verification/module14/run.sh
docs/verification/module15/run.sh
docs/verification/module16/run.sh
```

The selected reproduction guide supplies the direct Module 11 command; the original report remains restricted.

**Fingerprints:** module-local `rtl_before.sha256` and later baseline files. Module 12 uses `rtl_a03_baseline.sha256`; Module 13 current-source verification uses `rtl_current_5fbb22be.sha256`.

**Delivery:** benches/checkers and current-source helpers are selected. The functional derivative supplies the scoped technical presentation; original reports remain restricted. Preserve their conditional and waiver qualifications.

**Dependency:** historical runners and current-source runners are not interchangeable.

## 2. Original full-core integration

**Tested:** 12 scenarios per trace configuration with real synchronous RAMs, architectural expectations, memory transactions, faults and retirement checks.

```text
tb/integration/tb_rv32i_core_top.sv
docs/verification/module17/INTEGRATION_TEST_PLAN.md
docs/verification/module17/run_integration.sh
```

Original run directories are under `docs/verification/module17/run_*/`. Each run’s command, status and source manifests identify its scope; the directory name alone does not establish authority.

**Delivery:** the integration bench is selected; the functional derivative contains original integration evidence. Original plans, collector and run directories are restricted.

**Dependency:** the original collector is excluded because it also reads the restricted plan. Use the selected guide’s direct temporary-output simulation procedure.

## 3. D01 selector closure

**Established:** the actual EX operand-B selector supplies constant 4 for selection `10`.

```text
docs/verification/module17/d01/REPORT.md
docs/verification/module17/d01/run_ppj7sx9g/
docs/verification/module17/d01/tb_d01.sv
docs/verification/module17/final_campaign/tests/checked_d01.sv
```

The later wrapper verifies the actual core trace parameter before preserving the original selector checks.

**Fingerprint:** `docs/verification/module17/d01.tar`, listed in the package table below.

**Delivery:** sources are selected. The functional derivative retains the failed attempt, accepted selector evidence and source identities; original report/package remain restricted.

The D01 archive alone is not a substitute for its matching RTL baseline.

## 4. D02/A01 closure

**Established:** accepted interface integration and actual nonready-generator/sticky behavior through deliberate upstream packet injection.

```text
docs/verification/module17/d02_a01/REPORT.md
docs/verification/module17/d02_a01/run_uw_4x7gt/
docs/verification/module17/d02_a01/tb_d02_a01.sv
```

**Fingerprint:** `VER-M17-D02_A01_evidence.tar.gz`.

**Delivery:** bench and runner are selected. The functional derivative preserves diagnostic-injection qualifications; original report/package remain restricted.

**Limit:** injected packet states do not demonstrate that legal software naturally violates the interlock.

## 5. Directed V01–V27 campaign

**Tested:** instruction semantics, legality, lanes, boundaries, dependencies, redirects, terminal ordering, reset and both trace configurations.

```text
docs/verification/module17/full_campaign/FINAL_VERIFICATION_REPORT.md
docs/verification/module17/full_campaign/TEST_COVERAGE_MATRIX.md
docs/verification/module17/full_campaign/DEFECT_REGISTER.md
docs/verification/module17/full_campaign/tests/
docs/verification/module17/full_campaign/reference_models/rv32i.py
docs/verification/module17/full_campaign/scripts/
```

**Fingerprints:** per-attempt test-source manifests, saved generated benches/cases, campaign baseline manifests and `VER-M17-002_full_campaign.tar.gz`.

**Delivery:** model, saved fixtures and replay dependencies are selected. The functional derivative preserves coverage/corrections. Original generators, state and packages remain restricted; only `check_model.py` is selected from the historical `scripts/` directory.

**Dependency:** historical generators require initialized state and matching protected inputs. They can regenerate fixtures and update reports.

## 6. V23 accepted-fetch reset supplement

**Established:** reset cancels an already accepted instruction fetch and prevents stale effects after restart.

```text
docs/verification/module17/full_campaign/V23_IV01_SUPPLEMENTAL_REPORT.md
docs/verification/module17/full_campaign/results/v23/iv01_in4x8032/
docs/verification/module17/full_campaign/tests/v23/tb_accepted_fetch_reset.sv
```

**Fingerprint:** supplement manifests and `VER-M17-002_IV01_closure.tar.gz`.

**Delivery:** bench is selected. The functional derivative preserves the coverage gap, initial sampling failure and separate 38-check IV01 result.

The 38-check IV01 batch is not the full 414-check replay.

## 7. F01 approved-warning inventory

**Established:** exact-warning inventory acceptance for four configurations, plus fail-closed runner validation.

```text
docs/verification/module17/lint_closure/fail_closed_runner/FINAL_REPORT.md
docs/verification/module17/lint_closure/fail_closed_runner/RUNNER_TEST_REPORT.md
docs/verification/module17/lint_closure/fail_closed_runner/campaign_summary.json
docs/verification/module17/lint_closure/fail_closed_runner/approved_manifest.json
docs/verification/module17/lint_closure/fail_closed_runner/inventories/
```

**Fingerprints:** frozen manifest, runner and archive identities listed below.

**Delivery:** the lint derivative retains exact diagnostic records and complete unchanged native transcripts. Original inventory files and frozen runner are restricted. The three portable lint files are separately qualified, selected technical inputs.

**Dependency:** the original contract pins source/document/tool/command/root identities. Current `docs/DECISIONS.md` does not match it. Preserve the original contract; do not silently alter it.

The saved report’s pending-closure wording is historical. Current F01 status is CLOSED.

## 8. F02 assertions and expected negatives

**Established:** positive execution of P0–P23 and detection of ten specified observation mutations.

```text
docs/verification/module17/final_campaign/ASSERTION_REPORT.md
docs/verification/module17/final_campaign/logs/F02_u7498xw9/
docs/verification/module17/final_campaign/tests/cpu_checker.sv
docs/verification/module17/final_campaign/tests/checked_legal.sv
docs/verification/module17/final_campaign/tests/checked_injected.sv
```

The later replay provides additional assertion execution records.

**Fingerprints:** wrapper/checker hashes in accepted source records; original F08 package manifest.

**Delivery:** checker/wrapper sources are selected. The functional derivative preserves designated expected-negative markers, P0–P23 observations and the coverage-export correction.

## 9. F03 diagnostic compatibility

**Established:** correct RTL diagnostic lifecycle remains required; synthesis need not retain an unconsumed sticky register.

```text
docs/verification/module17/final_campaign/A01_ARCHITECTURE_ASSESSMENT.md
```

Read that historical assessment with the later ARCH-M17-A01-SYN disposition summarized in `TECHNICAL_DECISIONS.md`.

**Delivery:** the original assessment and decision record remain restricted historical inputs. The technical decision summary carries the accepted disposition without rewriting the earlier ambiguity.

## 10. F04 generic synthesis

**Established:** generic synthesis and reported structural checks for both trace configurations.

```text
docs/verification/module17/final_campaign/SYNTHESIS_REPORT.md
docs/verification/module17/final_campaign/logs/F04_3pvhfy2g/
```

Useful files include the two `.ys` scripts, raw synthesis logs, preoptimization JSON and exported netlists.

**Fingerprints:** original F08 manifest and per-run source records.

**Delivery:** the implementation derivative includes complete root-normalized scripts/logs and validated structural extracts. Full original netlists remain restricted, fingerprinted dependencies.

**Limit:** external RAM inference, target utilization, timing and equivalence are not established. Original F04 predates R01.

## 11. F05 deferred timing

**Established:** generic topology observations and the limits of the timing assessment.

```text
docs/verification/module17/final_campaign/TIMING_REPORT.md
docs/verification/module17/final_campaign/logs/F05_mgu151rp/
docs/verification/module17/TIMING_OBLIGATIONS.md
```

**Delivery:** the implementation derivative retains FINAL-B01 and both outstanding timing-shell requirements. Original reports remain restricted.

**Status:** PARTIAL / DEFERRED. Cell-step path lengths are not quantitative timing.

## 12. F06 complete regression

**Established:** 414 positive checks across 70 simulations and ten expected negatives.

```text
docs/verification/module17/final_campaign/REGRESSION_REPORT.md
docs/verification/module17/final_campaign/logs/F06_bkc2n79b/
docs/verification/module17/lint_closure/fail_closed_runner/regression_runs/run_j30u7hai/
```

The later directory contains 80 result records, commands, logs and per-simulation source hashes.

**Delivery:** the functional derivative contains all 80 reconciled records and complete path-normalized transcripts. Its PARTIAL status concerns legacy unit-source identities, not missing replay outcomes.

**Limit:** counts include repeated programs and aggregate cases.

## 13. F07 integrity

**Established:** unchanged protected files and result reconciliation at historical checkpoints.

```text
docs/verification/module17/final_campaign/INTEGRITY_REPORT.md
docs/verification/module17/final_campaign/logs/F07_py2avkr8/
docs/verification/module17/final_campaign/evidence/protected_before.json
docs/verification/module17/final_campaign/evidence/protected_after.json
```

The original checkpoint covered 3,661 protected files. The later frozen-runner campaign recorded its own 5,947-file scope.

**Delivery:** the implementation derivative records original manifest identities and scope comparisons. Broad originals remain restricted; eventual delivery integrity still requires its own validation.

These historical counts are not a statement about every file in the current workspace.

## 14. F08 reporting and package validation

**Established:** report preparation, package integrity and recorded payload validation.

```text
docs/verification/module17/final_campaign/FINAL_ENGINEERING_REPORT.md
docs/verification/module17/final_campaign/evidence/FINAL_MANIFEST_20261104T232215Z.sha256
docs/verification/module17/final_campaign/PACKAGE_VALIDATION_20261104T232215Z.json
```

**Fingerprint:** the original F08 archive listed below.

**Delivery:** the immutable original remains private. The implementation derivative independently reconciles archive payload hashes without delivering the restricted archive.

A package-validation PASS is not another functional or timing signoff.

## 15. Current status, source maintenance and later review

```text
docs/verification/module17/CURRENT_STATUS.md
docs/verification/module17/lint_closure/implementation/SOURCE_CHANGE_AUDIT.md
docs/verification/module17/lint_closure/implementation/evidence/source_changes.json
docs/reviews/final_acceptance/REVIEW_VALIDATION_AND_INTEGRITY.md
```

The source-change JSON is selected unchanged and supports the R01/T01 technical record. The other paths in this group are restricted historical lookup references.

`VERIFICATION_STATUS.md` supplies the technical current-state summary. The original status snapshot predates final conditional acceptance.

The source-change audit identifies R01/T01 exactly. The later review records the 34-positive/two-negative subset and four diagnostic replays; it does not claim a complete rerun.

## Key immutable identities

| Record | SHA-256 |
|---|---|
| Original `docs/ARCHITECTURE.md` | `529d37628f2d87dc8f9b030d7e2182122e29d25ed416e2ce04a21c984e3b8b98` |
| Frozen F01 manifest | `498f80e8205c1b4a380292d3142d00586a9291768bfb82c5f0e69e1fcc95f0e8` |
| Frozen F01 runner | `a3021fea88eaba782f4cb108741df98957753630ff0f408e471f4e4e92409ac1` |

## Principal original packages — restricted retention

| Exact original path | SHA-256 |
|---|---|
| `docs/verification/module17/d01.tar` | `6ee68a3d983a83ece3316fb5c01886c69c36baf4451d21053193792009626b12` |
| `VER-M17-D02_A01_evidence.tar.gz` | `d4e12715d936ed79f26aa68f697fd9ab57bac23ff628da12062ece734126c21a` |
| `VER-M17-002_full_campaign.tar.gz` | `a279dcbbe6896decc4c528fd46d742377e5feb31600fefad085618e379c3bc71` |
| `VER-M17-002_IV01_closure.tar.gz` | `cc1ece0e7cf34198b2e17b4ae14d81ff148a5b97aa487fa54b405bd21c3f609f` |
| `docs/verification/module17/final_campaign/VER-M17-003_evidence_20261104T232215Z.tar.gz` | `bfc5bcff099c1ce3dc7873cdf25183e6efdae738685d9f23ed1572a191193d6b` |
| `docs/verification/module17/lint_closure/fail_closed_runner/VER-M17-003-F01-RUNNER_EVIDENCE.tar.gz` | `7b4442ec1d375df351277a8abfc0c19eb958b35145bd40e35164cd0d6fe78bbc` |

These packages are preserved originals, not approved delivery selections. Their technical dependencies and restricted contents must be accounted for before selecting a complete delivery evidence set.

A derivative must retain technical findings, failures, source identities and reproduction limits, have a distinct hash/manifest, and provide a validated mapping to its original. Redacting or repacking an original under its existing identity is not acceptable.

## Portable qualification and checkpoint identities

The appended `portable_qualification` record in selected `TECHNICAL_LINT_VALIDATION.json` preserves all earlier validation fields. The implementation manifest records that validation file’s earlier checkpoint hash; it is not the current validation-file identity. The exact earlier bytes are retained externally by PRE-PUSH-008F. Original runtime qualification evidence is referenced externally, not promised as part of this repository. New portable runs create independently identified outputs.

Use the source check in `REPRODUCING.md` with the pinned portable manifest for accepted-source reproduction. The two unavailable older RTL versions remain historical limitations; current Module 12 and Module 13 runners require their selected fingerprint text files, not those old source bytes.
