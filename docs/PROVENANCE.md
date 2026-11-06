# Technical Provenance

This record describes documented technical contributions and source identities. It does not infer authorship from formatting, filenames or the appearance of code.

## Architecture and review

The processor follows ARCH-001 Revision C and the technical amendments summarized in `TECHNICAL_DECISIONS.md`.

The original architecture records Claude-assisted technical reviews and carries REV, REVA, RW and RB finding references. These are architecture-review contributions, not proof of production RTL authorship.

Some comparisons describe an older source that was not independently available for a complete diff. Those comparisons remain attributed historical observations.

## RTL implementation and accepted baseline

The accepted post-R01/T01 baseline consists of 17 RTL files and the integration testbench. Their unchanged hashes are available in the selected [portable manifest](verification/module17/lint_closure/fail_closed_runner/portable_manifest.json). The frozen F01 manifest below remains a restricted historical identity:

```text
498f80e8205c1b4a380292d3142d00586a9291768bfb82c5f0e69e1fcc95f0e8
```

The available records do not establish a complete file-by-file authorship ledger. They do not support a statement that production RTL was exclusively human-written or exclusively AI-written.

General consultation and AI-assisted verification must not be treated as evidence that an assistant designed every production module.

## Codex-assisted verification

Records explicitly document Codex-assisted work on unit verification, integration checking, directed tests, the architectural reference model, assertions, runners, lint acceptance tooling and technical reports.

The architectural model computes expectations from instruction semantics and byte-addressed memory rather than DUT decode/results. This independence concerns the oracle’s data source; it is not a claim of exclusive human authorship or exhaustive correctness.

Saved benches, fixtures, commands and source hashes identify what actually ran.

## Verification-infrastructure corrections

The recorded corrections include:

- Truncating SB/SH oracle payloads before lane shifting.
- Recognizing that a redirect target terminating in ID must not be required to enter EX.
- Adding reset coverage after an instruction fetch was actually accepted.
- Sampling registered reset effects after synchronous updates.
- Correcting F02 property-evaluation export without changing the property predicates.
- Hardening runners and preserving failed baseline/waiver experiments.

These were verification or coverage corrections. Their failed attempts remain evidence; they are not relabeled as RTL failures or removed from the history.

V15 output injection and D02 upstream packet injection are deliberate diagnostic tests. They are distinct from natural instruction execution.

## Controlled R01/T01 maintenance

The recorded Codex-assisted maintenance includes a production-RTL formatting edit and a testbench condition edit.

| Change | Exact scope |
|---|---|
| R01 | Append one terminal LF to `rtl/memory/load_formatter.sv`; 1499→1500 bytes. |
| T01 | Replace one `if(errors)` with `if(errors != 0)` in `tb/integration/tb_rv32i_core_top.sv`; 13614→13619 bytes. |

This is a material assisted source-maintenance contribution. It is not evidence of a semantic processor redesign.

The audit records no changed test expectations and preserves the original bytes.

| Source | Before SHA-256 | After SHA-256 |
|---|---|---|
| R01 RTL file | `8e0b77bc226b3ff8db10596061ed9a798fa60fc405b036df456a194e16e44194` | `562491ee4affd64ee76f593b753144bfc2812b59bc3c55f3fcc57731711ce800` |
| T01 integration bench | `ee5b4f53c3c63869dfd1115e5c1f52265e4c641cefa445949c69457a15774ec6` | `d293418f0d68adc9898495a0a3d439d5059a2ae19cba981672d67998cf8b27fe` |

The machine-readable audit is:

```text
docs/verification/module17/lint_closure/implementation/evidence/source_changes.json
```

## Traceability and presentation

Original reports, manifests and archives retain their historical identities. Later technical summaries explain subsequent dispositions without rewriting those originals.

The functional, lint and implementation derivatives have distinct identities and original-source mappings; they are not the original immutable packages. The functional derivative remains PARTIAL for two older RTL identities. See [verification status](VERIFICATION_STATUS.md).

Restricted records and private identifiers are not reproduced here. Their omission from the presentation does not erase their existence or authorize an unsupported authorship claim.

See `EVIDENCE_INDEX.md` for evidence locations, fingerprints and retention boundaries.

Later Codex-assisted evidence transformation and portable lint infrastructure preserve the original technical findings and source identities. PRE-PUSH-008F separately qualified the new technical-only lint contract; it did not rewrite historical F01 acceptance. See [portable qualification](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_VALIDATION.json) and [source-maintenance and implementation evidence](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_EVIDENCE.json).
