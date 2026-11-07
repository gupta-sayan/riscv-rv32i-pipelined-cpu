# RV32I Five-Stage Pipelined RISC-V Processor

A 32-bit, single-issue, in-order CPU implemented in **SystemVerilog**, with an **IF → ID → EX → MEM → WB** pipeline and separate synchronous instruction and data memories.

The design makes pipeline control explicit: newest-producer operand forwarding, WB-to-ID bypass, a one-bubble load-use interlock, EX-stage memory acceptance, and exactly two EX bubbles after a legal redirect. Ordered fail-stop control drains older work before halting and preserves an immutable fault record. Optional retirement tracing supports architectural checking.

The technology-independent RTL milestone was conditionally accepted on November 5, 2026. Verification combines unit tests, full-core simulation, directed programs, an architectural reference model, executable assertions and deliberate negative controls. **Generic synthesis is complete; FPGA/ASIC implementation and physical timing qualification remain deferred.**

**Start with the architecture:** [Pipeline diagram and control-flow details](docs/PIPELINE_DIAGRAM.md) · [Technical architecture](docs/TECHNICAL_ARCHITECTURE.md) · [Reproduce the results](docs/REPRODUCING.md) · [Verification status](docs/VERIFICATION_STATUS.md)

### Pipeline overview

```mermaid
flowchart LR
    IF["IF — fetch"] --> ID["ID — decode"] --> EX["EX — execute"] --> MEM["MEM — memory"] --> WB["WB — writeback"]
```

This is a conceptual stage sequence, not a cycle-accurate datapath drawing. Instruction and data memories have registered outputs, and actual control, forwarding and fault paths are shown in the [detailed diagram](docs/PIPELINE_DIAGRAM.md).

### Key engineering challenges

- **Data hazards:** implement newest-producer EX/MEM-versus-MEM/WB forwarding and a single-bubble load-use interlock without forwarding unavailable load data.
- **Control hazards:** qualify EX-stage redirects against older faults and younger ID terminal events; preserve the defined two-bubble redirect behavior.
- **Synchronous memory timing:** align fetch metadata with registered IMEM output and accept qualified data-memory transactions at the EX-ending edge.
- **Verification credibility:** distinguish directed simulation, expected-negative controls and assertion observations from exhaustive proof; retain auditable evidence and reproducible current-source commands.

## Results at a glance

| Area | Implemented or recorded scope |
|---|---|
| Instruction support | 40 RV32I mnemonics within the restricted execution environment below |
| Production RTL | 17 SystemVerilog modules |
| Unit verification | 16 standalone testbenches; individual outcomes and waivers retain their documented scope |
| Core integration | 12 scenarios in each static `TRACE_EN` configuration; 24 scenario/configuration checks |
| Directed verification | V01–V27, including V15 diagnostics and V23 accepted-fetch reset supplements |
| Positive regression | 414 case/configuration checks across 70 positive simulations |
| Negative controls | 10 expected-negative assertion simulations, accepted only on designated failure markers |
| Assertion observations | All 24 property IDs, P0–P23, positively evaluated in simulation |
| Portable lint | 4 exact-diagnostic configurations; 46 qualification controls passed twice |
| Historical F01 lint | CLOSED by approved-warning inventory matching; native exits 1, warning counts 27/5/49/27 |
| Generic Yosys synthesis | 8,407 cells (`TRACE_EN=0`); 8,799 cells (`TRACE_EN=1`) |
| Technology-specific timing | F05 **PARTIAL / DEFERRED**; no physical timing signoff |

The 414 checks include repeated programs, assertion-wrapped replays and supplements; they are not 414 unique programs. Assertion evaluation is simulation evidence, not exhaustive formal verification or external ISA certification. Lint acceptance retains the warnings and requires complete diagnostic matching, not merely matching counts.

## Architecture and execution environment

| Stage | Main responsibility |
|---|---|
| IF | Present the PC; accept a synchronous instruction read or fetch-fault token. |
| ID | Decode, read registers, generate immediates, apply WB bypass and detect load-use dependencies or terminal events. |
| EX | Forward operands, execute arithmetic, resolve branches, check addresses and accept legal data-memory transactions. |
| MEM | Format the registered load response and select the next writeback value. |
| WB | Write the register file and produce optional registered retirement tracing. |

The register file has 32 × 32-bit registers; x0 always reads zero. IMEM occupies 16 KiB at `0x00000000–0x00003FFF`; DMEM occupies 16 KiB at `0x00010000–0x00013FFF`. Both use fixed-latency synchronous reads and hold their outputs when disabled. Data transactions are accepted at the EX-ending rising edge.

Reset starts fetching at address zero. Registers x1–x31 and RAM contents are not reset; software and the test environment initialize them before use.

This single-hart, little-endian execution environment has no privileged mode, CSR instructions, interrupts, operating system, MMIO, caches or variable-latency memory. C, M, A, F and D extensions are not implemented. ECALL and EBREAK terminate through ordered fail-stop control. FENCE is an accepted no-op in the strongly ordered RAM environment; FENCE.I is unsupported. See the [architecture](docs/TECHNICAL_ARCHITECTURE.md) for exact instruction, fault, reset and timing contracts.

## Run the integration simulation

Run from the repository root using Bash, ripgrep and Icarus Verilog/vvp 12.0 stable:

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

## Synthesis and remaining work

Recorded generic Yosys 0.33 synthesis of `rv32i_core_top` passed structural checks in both static trace configurations:

| Configuration | Generic cells | Generic sequential bits/cells |
|---|---:|---:|
| `TRACE_EN=0` | 8,407 | 1,380 |
| `TRACE_EN=1` | 8,799 | 1,884 |

External IMEM/DMEM arrays are outside the synthesized core. These are technology-independent cell counts, not FPGA LUT/BRAM utilization, ASIC area, power or measured Fmax. The original F04 run predates the R01 terminal-newline correction and remains historical evidence for its recorded source baseline.

F05 remains **PARTIAL / DEFERRED** under FINAL-B01. The provisional 20 MHz target is a planning goal, not demonstrated performance. Target implementation must establish device/library selection, clock and I/O constraints, synchronous RAM inference and output-hold behavior, and quantitative slack/WNS for the forwarded address-to-memory-acceptance and branch-to-fetch-PC paths.

No FPGA/ASIC implementation, hardware test, physical timing signoff, post-synthesis simulation or netlist equivalence has been established.

## Reproducibility and evidence

The [reproduction guide](docs/REPRODUCING.md) documents saved-fixture replay, model anchors, unit entry points, expected-negative acceptance, portable lint and generic synthesis commands, including tool and output-isolation requirements. The direct command above exercises only the integration subset.

The [evidence index](docs/EVIDENCE_INDEX.md) links the functional, lint and implementation/integrity derivatives and their manifests and validation records. These are technical presentations of preserved historical records, not replacements for the originals.

The functional derivative remains **PARTIAL**: five legacy-fingerprint entries refer to two unavailable older RTL identities (`pc_fetch.sv` and `pipeline_regs.sv`). The 18 accepted RTL/integration source identities and all 80 saved regression records reconcile. The missing older bytes are historical dependencies, not inputs to accepted-current-source reproduction.

Historical F01 remains CLOSED under its frozen approved-warning inventory contract. Its private historical inputs prevent reconstructing that original acceptance from this package alone. The separately qualified [portable lint procedure](docs/verification/module17/lint_closure/fail_closed_runner/portable_runner.py) uses a technical-only contract; it is neither a rerun nor a replacement of historical F01.

## Source guide

```text
rtl/core/         Pipeline integration, execution and control
rtl/decode/       Instruction decode, immediates and register file
rtl/memory/       Load/store checks, formatting and synchronous RAMs
tb/unit/         Sixteen standalone module testbenches
tb/integration/  Full-core testbench and external synchronous RAM instances
docs/            Architecture, reproduction guide and qualified evidence
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

## Engineering contributions

The project engineer led design decisions and technical reviews. Recorded contributions include AI-assisted consultation and architecture review, Codex-assisted verification and tooling, and controlled source-maintenance work. The records do not establish exclusive human or AI authorship of production RTL. See [technical provenance](docs/PROVENANCE.md) for the supported contribution scope and source fingerprints, and [technical decisions](docs/TECHNICAL_DECISIONS.md) for design rationale.
