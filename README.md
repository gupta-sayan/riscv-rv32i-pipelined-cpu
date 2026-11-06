# RV32I Five-Stage Pipelined RISC-V Processor

A 32-bit, single-issue, in-order RISC-V processor implemented in SystemVerilog. The design uses a five-stage pipeline, separate instruction and data interfaces, and synchronous memories with registered read outputs.

The technology-independent RTL milestone was **conditionally accepted on November 5, 2026**. Verification covers instruction execution, pipeline timing, forwarding, memory accesses, fault handling, reset and tracing. Generic synthesis is complete; FPGA/ASIC timing qualification remains deferred.

## Architecture at a glance

| Property | Implementation |
|---|---|
| Instruction set | RV32I: 40 instruction mnemonics under the documented execution environment |
| Pipeline | IF, ID, EX, MEM, WB |
| Integer registers | 32 × 32 bits; x0 reads zero |
| Instruction memory | 16 KiB at `0x00000000–0x00003FFF` |
| Data memory | 16 KiB at `0x00010000–0x00013FFF` |
| Memory behavior | Little-endian; fixed-latency synchronous reads |
| Data transactions | Accepted at the EX-ending rising edge |
| Dependencies | Operand forwarding, WB-to-ID bypass and one-bubble load-use interlock |
| Control transfers | Resolved in EX; exactly two EX bubbles after a legal redirect |
| Terminal events | Ordered fail-stop with an immutable fault record |
| Tracing | Optional registered retirement trace through static `TRACE_EN` |

The execution environment has no privileged mode, CSR instructions, interrupts, operating system, MMIO, caches or variable-latency memory. C, M, A, F and D extensions are not implemented.

ECALL and EBREAK terminate execution through the fail-stop mechanism. FENCE is an accepted no-op in the single-hart, strongly ordered RAM environment. FENCE.I is unsupported.

Reset starts fetching at address zero. Registers x1–x31 and RAM contents are not reset; software and the test environment initialize them before use.

## Pipeline

| Stage | Main work |
|---|---|
| IF | Present the fetch PC and accept an instruction-memory read or fetch-fault token. |
| ID | Decode, read registers, generate immediates, apply WB bypass and detect load-use dependencies or terminal instructions. |
| EX | Forward operands, execute arithmetic, resolve branches, check addresses and accept a legal data-memory transaction. |
| MEM | Select and extend registered load data, then select the next writeback value. |
| WB | Write the register file and produce the optional registered retirement trace. |

An immediate load consumer incurs **one bubble**. A legal taken redirect produces **exactly two EX-stage bubbles**. Invalid pipeline slots are explicit bubbles rather than substituted instructions.

## Run the integration simulation

The recorded simulation environment used Icarus Verilog/vvp 12.0 stable. This example also requires Bash and ripgrep.

Run from the repository root:

```bash
set -euo pipefail

run_dir="$(mktemp -d /tmp/rv32i-sim.XXXXXX)"
mapfile -t rtl_sources < <(rg --files rtl -g '*.sv' | sort)

iverilog -V >"$run_dir/iverilog-version.log" 2>&1
vvp -V >"$run_dir/vvp-version.log" 2>&1

for trace in 0 1; do
    iverilog -g2012 -gassertions \
        -s tb_rv32i_core_top \
        -P "tb_rv32i_core_top.TRACE_EN=$trace" \
        -o "$run_dir/trace$trace.vvp" \
        tb/integration/tb_rv32i_core_top.sv \
        "${rtl_sources[@]}" \
        >"$run_dir/compile$trace.log" 2>&1

    vvp "$run_dir/trace$trace.vvp" \
        >"$run_dir/simulation$trace.log" 2>&1

    rg -q "^PASS ALL TRACE_EN=$trace tests=12$" \
        "$run_dir/simulation$trace.log"
done

printf 'Simulation logs: %s\n' "$run_dir"
```

Both compilation and simulation must succeed. Each configuration should report:

```text
PASS ALL TRACE_EN=0 tests=12
PASS ALL TRACE_EN=1 tests=12
```

The logs and generated executables stay outside the repository. This command reproduces the integration subset, not the complete historical campaign or frozen lint acceptance.

## Source organization

```text
rtl/
  core/          Pipeline integration, execution and control
  decode/        Instruction decode, immediates and register file
  memory/        Load/store checks, formatting and synchronous RAMs
tb/
  unit/          Sixteen module-level testbenches
  integration/   Full-core testbench with synchronous instruction/data RAMs
docs/
  verification/  Verification sources, fixtures, reports and evidence
```

### RTL modules

| Module | Purpose |
|---|---|
| [rv32i_core_top](rtl/core/rv32i_core_top.sv) | Integrates the core, forwarding data muxes, WB bypass and diagnostic sticky state. |
| [pc_fetch](rtl/core/pc_fetch.sv) | Owns the fetch PC, next-PC selection and fetch-slot generation. |
| [pipeline_regs](rtl/core/pipeline_regs.sv) | Owns IF/ID metadata and ID/EX, EX/MEM and MEM/WB registers. |
| [decoder](rtl/decode/decoder.sv) | Checks instruction legality and generates execution controls. |
| [imm_gen](rtl/decode/imm_gen.sv) | Builds I, S, B, U and J immediates. |
| [reg_file](rtl/decode/reg_file.sv) | Provides two asynchronous reads and one synchronous write. |
| [hazard_ctrl](rtl/core/hazard_ctrl.sv) | Detects true load-use dependencies. |
| [forward_unit](rtl/core/forward_unit.sv) | Selects the newest producer for EX operands and store data. |
| [alu](rtl/core/alu.sv) | Performs integer arithmetic, logic, shifts and comparisons. |
| [branch_unit](rtl/core/branch_unit.sv) | Compares branch operands and forms checked redirect targets. |
| [lsu_ex](rtl/memory/lsu_ex.sv) | Checks data addresses and forms qualified memory requests. |
| [ex_event_mux](rtl/core/ex_event_mux.sv) | Selects the EX fault candidate. |
| [fault_ctrl](rtl/core/fault_ctrl.sv) | Orders faults and redirects, drains older work and enters HALTED. |
| [load_formatter](rtl/memory/load_formatter.sv) | Selects load lanes and performs sign or zero extension. |
| [wb_trace](rtl/core/wb_trace.sv) | Produces functional writeback and optional registered trace outputs. |
| [imem_sync](rtl/memory/imem_sync.sv) | Implements synchronous instruction reads with disabled-cycle hold. |
| [dmem_sync](rtl/memory/dmem_sync.sv) | Implements registered data reads and byte-strobed writes. |

`rv32i_core_top` exposes memory interfaces. The integration testbench instantiates the two RAM modules around the core.

## Verification results

The verification environment combines module tests, a full-core scoreboard, an independent architectural model, directed programs, executable assertions and deliberate negative tests.

| Area | Recorded result |
|---|---|
| Original integration | 12 scenarios in each trace configuration |
| V01–V27 | Accepted directed coverage, including the V23 accepted-fetch reset supplement |
| Later complete regression | 414 positive case/configuration checks across 70 simulations |
| Assertion sensitivity | Ten expected-negative simulations with designated property failures |
| Assertion execution | All 24 checker property IDs evaluated |
| F01 lint acceptance | CLOSED through exact approved-warning inventory matching |
| F03 compatibility | CLOSED |
| Generic synthesis | Successful synthesis and structural checks in both trace configurations |

The 414 checks include repeated programs, assertion-wrapped replays and supplemental checks. They are not 414 unique programs or exhaustive ISA compliance evidence.

F01 retains the native Verilator warnings. The four configurations contain 27, 5, 49 and 27 warning occurrences, and native Verilator exits remain 1. The accepted result is an exact warning-inventory match, not warning-free lint.

Historical failures, corrected verification-infrastructure issues and expected-negative results remain part of the evidence.

## Generic synthesis

Recorded Yosys 0.33 results for `rv32i_core_top`:

| Configuration | Generic cells | Generic sequential bits/cells |
|---|---:|---:|
| `TRACE_EN=0` | 8,407 | 1,380 |
| `TRACE_EN=1` | 8,799 | 1,884 |

These counts describe generic synthesis cells. They do not establish FPGA LUT/BRAM utilization, ASIC area or physical timing. External instruction/data RAM arrays are outside the synthesized core.

The original synthesis run predates the R01 terminal-newline correction. It remains historical synthesis evidence rather than a fresh run of the later source bytes.

## Limitations and deferred work

Verification is bounded simulation. It does not establish exhaustive correctness, external ISA certification, formal proof or netlist equivalence.

No FPGA/ASIC implementation, hardware test or physical timing signoff is established. Post-synthesis simulation was not performed.

F05 remains **PARTIAL / DEFERRED** under FINAL-B01. The provisional 20 MHz target is a planning goal, not measured Fmax. Target-specific work must establish:

- Device or technology/library, tool versions and timing constraints.
- Memory inference and registered-output hold behavior.
- Timing through the forwarded load/store address path.
- Timing through branch comparison, redirect control and the fetch PC.
- Quantitative slack/WNS and documented handling of violations.

## Documentation and evidence navigation

Start with the [technical architecture](docs/TECHNICAL_ARCHITECTURE.md), a companion restatement of the approved architecture rather than a newly approved replacement specification.

The technical delivery uses the validated derivatives below. They preserve original identities and qualification limits; restricted reports and archives remain private historical records.

| Evidence group | Evidence | Manifest | Validation |
|---|---|---|---|
| Functional — PARTIAL | [Evidence](docs/verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_EVIDENCE.json) | [Manifest](docs/verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_MANIFEST.json) | [Validation](docs/verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_VALIDATION.json) |
| Historical lint — validated | [Evidence](docs/verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_EVIDENCE.json) | [Manifest](docs/verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_MANIFEST.json) | [Validation](docs/verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_VALIDATION.json) |
| Implementation/integrity — validated | [Evidence](docs/verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_EVIDENCE.json) | [Manifest](docs/verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_MANIFEST.json) | [Validation](docs/verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_VALIDATION.json) |

The PRE-PUSH-008C functional derivative is **PARTIAL**: five legacy-fingerprint entries refer to two unavailable older RTL identities (`rtl/core/pc_fetch.sv` and `rtl/core/pipeline_regs.sv`). The 18 accepted design/bench hashes and all 80 replay records reconcile. Those missing older bytes are historical dependencies, not inputs required by the current-source procedures below.

PRE-PUSH-008F separately qualified the portable technical lint procedure: four matching configurations and 46 controls passing twice. This is new qualification, not a rerun or replacement of historical F01 acceptance.

Use the [portable runner](docs/verification/module17/lint_closure/fail_closed_runner/portable_runner.py), its [technical contract](docs/verification/module17/lint_closure/fail_closed_runner/portable_manifest.json), and the [qualification suite](docs/verification/module17/lint_closure/fail_closed_runner/test_portable_runner.py). See [reproduction instructions](docs/REPRODUCING.md), [verification status](docs/VERIFICATION_STATUS.md), [evidence index](docs/EVIDENCE_INDEX.md) and [technical provenance](docs/PROVENANCE.md).

The original F01 contract remains historical-only: its frozen document fingerprints differ from the current presentation. The portable contract pins technical sources and the technical lint baseline instead. Generic synthesis remains historical, and F05 remains PARTIAL / DEFERRED.

The project records include AI-assisted architecture review and verification work. Those records do not support an exclusive human-only RTL authorship claim.
