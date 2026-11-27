# FPGA Timing Analysis

The unchanged RTL (v1) meets timing at **80 MHz** on a Spartan-7 XC7S50. Two small RTL changes driven by the timing reports (v2) raise that to **93 MHz**, with the same area and with every existing verification check still passing.

This document records the method, the measured results, the problems the reports exposed, the fixes, the verification of those fixes and one fix that was measured and rejected. The formal change record is [CHANGE_PROPOSAL_TIMING_V2.md](CHANGE_PROPOSAL_TIMING_V2.md).

## 1. Results at a glance

| Version | RTL | `TRACE_EN=0` | `TRACE_EN=1` | LUTs / FFs / block RAMs (`TRACE_EN=0`) |
|---|---|---|---|---|
| v1 | `95f032f`, unchanged | **80.0 MHz** met (12.5 ns, WNS +0.120 ns) | **71.4 MHz** met (14 ns, WNS +0.140 ns) | 1,453 / 355 / 8 |
| v2 | Fixes A + B | **93.0 MHz** met (10.75 ns, WNS +0.034 ns) | **83.3 MHz** met (12 ns, WNS +0.402 ns) | 1,460 / 356 / 8 |

Hold slack is positive in every run. The provisional 20 MHz target in the architecture is met with more than 4× margin by both versions.

## 2. Method

| Item | Value |
|---|---|
| Device | AMD Spartan-7 XC7S50, `xc7s50csga324-1` (RealDigital Urbana board) |
| Tool | Vivado 2023.2, batch mode |
| Flow | `synth_design -mode out_of_context`, `opt_design`, `place_design`, `phys_opt_design`, `route_design`, `phys_opt_design` |
| Clock | One clock on `clk`, period swept; `HD.CLK_SRC` set so clock delay and skew are estimated |
| Top | `timing_top`: `rv32i_core_top` + `dmem_sync` + `timing_imem` |
| Memories | Both inferred as block RAM (8 RAMB tiles: 16 KiB IMEM + 16 KiB DMEM) |
| Register file | Inferred as distributed LUT-RAM |

`timing_imem` reproduces `imem_sync` (registered read, output held when disabled) and adds a loader write port. Without a writer, synthesis treats the instruction memory as constant and optimizes most of the core away.

Achieved period is computed as target period − WNS. A frequency is only claimed from a run that meets timing at that period.

All scripts and recorded results are in [`docs/verification/timing/`](verification/timing/README.md).

## 3. v1: baseline measurement

### Clock sweep

The achieved period stays at about 12.3 to 12.7 ns whatever the target. Tighter targets do not let the tool recover more, so the limit is the RTL structure, not tool effort.

| Target | `TRACE_EN=0` WNS → achieved | `TRACE_EN=1` WNS → achieved |
|---|---|---|
| 10 ns (100 MHz) | −2.402 ns → 12.40 ns (80.6 MHz) | −2.585 ns → 12.59 ns (79.5 MHz) |
| 8 ns (125 MHz) | −4.666 ns → 12.67 ns (79.0 MHz) | −5.444 ns → 13.44 ns (74.4 MHz) |
| 6.67 ns (150 MHz) | −5.728 ns → 12.40 ns (80.7 MHz) | −6.444 ns → 13.11 ns (76.3 MHz) |
| 5 ns (200 MHz) | −7.285 ns → 12.29 ns (81.4 MHz) | −8.502 ns → 13.50 ns (74.1 MHz) |

Confirmation runs: 12.5 ns met (+0.120 ns) with `TRACE_EN=0`; 13 ns failed (−0.525 ns) and 14 ns met (+0.140 ns) with `TRACE_EN=1`.

The optional trace logic costs about 320 LUTs, 505 flip-flops and 0.2 to 1 ns.

### Cross-check against generic synthesis

Vivado's 355 flip-flops plus the 32 × 32 register file (1,024 bits, placed in LUT-RAM) give about 1,380 storage bits, matching the 1,380 generic sequential bits recorded by Yosys for `TRACE_EN=0`.

### v1 worst path (10 ns target, `TRACE_EN=0`)

20 logic levels (7 CARRY4), 11.9 ns, 68% routing. Source `idex_rs2_reg`, destination the synchronous reset pin of `idex_imm_reg`.

| Segment | RTL | About |
|---|---|---|
| Clock-to-out + forwarding select | `forward_unit` register-number compares → `fwd_b_sel` | 3.0 ns |
| Forwarding and operand muxes | `ex_rs2_forwarded` → `alu_operand_b` | 2.25 ns |
| 32-bit add | ALU adder carry chain | 1.9 ns |
| **ALU result mux** | `case (alu_op)` output selection | **2.0 ns** |
| Range/alignment check → fault | `lsu_ex` → `ex_event_mux` → `ex_evt_valid` | 1.7 ns |
| **Kill fan-out** | `fault_ctrl` → `kill_id` (fanout 71) → ID/EX reset pins | **1.05 ns** |

Other path groups at 10 ns: DMEM enable pins −2.332 ns (19 levels), DMEM address pins −1.605 ns, IMEM enable −0.969 ns, fetch-PC register −1.509 ns. IMEM address pins met (+5.916 ns): the address comes straight from the `fetch_pc` register.

This path is the first of the two paths the architecture named for qualification (forwarded operand → address generation → range/alignment checks → DMEM acceptance), extended through fault ordering.

## 4. Problems found

**Problem 1: the load/store address waits for the whole ALU.** `lsu_ex` took its effective address from `alu_result`. A load or store address is always rs1 + immediate, but it waited for the ALU's result mux (shifts, logic operations, comparisons), about 2 ns that a memory access never needs. That delay sits on both the DMEM enable path and the fault path.

**Problem 2: a kill clears far more than it needs to.** On a kill or bubble, `pipeline_regs` cleared the entire ID/EX register: PC, register numbers, operand values, immediate and ALU/branch controls, about 150 flip-flops. The clear rides on one high-fanout control net at the very end of the longest path, and in seven of the eight sweep runs the worst endpoint was a pipeline-register reset pin. The architecture defines a bubble by its valid bit; the cleared values were not consumed.

## 5. Fixes

**Fix A: dedicated address adder** (`rtl/core/rv32i_core_top.sv`).

```systemverilog
logic [31:0] lsu_eff_addr; // v2 fix A: dedicated address adder
assign lsu_eff_addr = ex_rs1_forwarded + idex_imm;
...
lsu_ex u_lsu_ex (
    .eff_addr(lsu_eff_addr),   // was: .eff_addr(alu_result)
```

Every load and store decodes to ALU ADD with `op_a_sel` = rs1 and `op_b_sel` = immediate, so `lsu_eff_addr` equals `alu_result` whenever `mem_read` or `mem_write` is set. Cost: one 32-bit adder.

**Fix B: clear only what a bubble needs** (`rtl/core/pipeline_regs.sv`). Four ID/EX payload blocks change `if (rst || kill_id || bubble_ex)` to `if (rst)`:

| Block | Registers |
|---|---|
| Instruction identity and register addresses | `idex_pc`, `idex_rs1`, `idex_rs2`, `idex_rd` |
| Register values and immediate | `idex_rs1_value`, `idex_rs2_value`, `idex_imm` |
| ALU and branch control | `idex_alu_op`, `idex_imm_kind`, `idex_op_a_sel`, `idex_op_b_sel`, `idex_br_kind` |
| Trace instruction (`TRACE_EN=1`) | `idex_instr` |

Still cleared on kill and bubble: `idex_valid`, `uses_rs1`, `uses_rs2`, `is_jal`, `is_jalr`, `mem_read`, `mem_write`, `mem_size`, `load_unsigned`, `reg_write`, `wb_sel`. Load-use detection, forwarding, the LSU, the EX fault mux, redirect qualification and trace all gate on validity first.

Neither fix adds a pipeline register, retimes logic or moves the EX transaction edge, so both stay inside the FINAL-B01 restrictions. The cycle-level behavior of every valid instruction is unchanged.

Fix A amends a recorded architecture decision: the original module mapping specified the ALU result as the effective address with "no second address adder", an area choice. Fix B needs no amendment: the packet contract already states that invalid-packet fields are functionally irrelevant, with deterministic values only "preferred where practical". Both are recorded in the [change proposal](CHANGE_PROPOSAL_TIMING_V2.md#4-architecture-amendments).

## 6. Verification of v2

| Check | Tool | Result |
|---|---|---|
| Full regression (f06 item list: integration, V01–V27, supplements, D01, D02, F02) | Icarus 12.0 | 414/414 positive, 10/10 expected-negative, 80 simulations |
| All 16 unit benches, both trace modes | Icarus 12.0 | 32/32 pass (after the bench update below) |
| `tb_pipeline_regs` | Questa 2023.4 | 5,426,477 checks, 0 failures |
| Integration bench, both trace modes | Questa 2023.4 | PASS ALL tests=12 (× 2) |
| `--Wall` lint, four portable-runner configurations | Verilator 5.020 | 27 / 5 / 49 / 27 warnings, diagnostics identical to v1 (line numbers normalized) |

**Unit-bench contract change.** The 414-check regression does not include the unit benches. Running them showed `tb_pipeline_regs` failing on v2, because its reference model expected bubbled ID/EX payload to be zero, which is exactly what fix B removes. The bench now checks the 13 payload fields only for valid slots; `idex_valid` and every side-effect control are still checked every cycle. Checks drop from 6,309,177 to 5,426,477. The updated bench still passes on the v1 RTL.

**Observable side effect of fix A.** For non-memory instructions, the `dmem_addr` port and the unused trace memory-address field now carry different don't-care values. `dmem_re`, `dmem_we` and `retire_mem_valid` are low in those cycles, and no check depends on those values.

**Integrity note.** The portable lint manifest pins the v1 source hashes, so the pinned runner rejects v2 by design. v2 lint was compared by running the same four commands with the same tool version and diffing the diagnostics. The historical evidence and manifests are unchanged.

## 7. v2 results

At 10 ns with `TRACE_EN=0`, WNS improved from −2.402 ns to −0.633 ns (1.77 ns recovered, about 80.6 → 94 MHz achievable). Confirmation runs:

| Config | Period | WNS | WHS | LUTs | FFs | Block RAMs |
|---|---|---|---|---|---|---|
| `TRACE_EN=0` | 12.5 ns (80 MHz) | +0.260 ns | +0.113 ns | 1,451 | 355 | 8 |
| `TRACE_EN=0` | 10.75 ns (93.0 MHz) | +0.034 ns | +0.140 ns | 1,460 | 356 | 8 |
| `TRACE_EN=1` | 12 ns (83.3 MHz) | +0.402 ns | +0.034 ns | 1,759 | 862 | 8 |

## 8. A fix that was measured and rejected

After A and B, the worst endpoint moved to `exmem_ex_result_reg/R`: `kill_ex` clearing the EX/MEM payload. **Fix C** applied the same idea to EX/MEM (payload cleared on reset only; `exmem_valid`, `exmem_reg_write` and `exmem_mem_read` still cleared on kill). It passed the full regression, but timing did not improve: WNS −0.698 ns against −0.633 ns, within run-to-run variation. The new worst endpoint was `ifid_pc_reg/R`.

Removing one clear only moved the endpoint to the next one. The delay is in the shared front half of the path (forwarding, add, check, fault or redirect decision), and the kill must still reach the valid bits. Fix C was reverted; it is not in v2.

## 9. Remaining limiter

After A and B, the worst path is the second path the architecture named: forwarded branch comparison → redirect qualification → fetch kill. It is about 10.6 ns, nearly equal to the LSU/fault path, with 76% of its delay in routing.

| Segment | Arrival | About |
|---|---|---|
| Clock-to-out + forwarding compare (`memwb_rd` match, fanout 99) | 4.72 ns | 3.15 ns |
| Forwarding mux → `ex_rs1_forwarded` (fanout 12) | 6.06 ns | 1.34 ns |
| Branch comparison in `branch_unit` (4 CARRY4) | 8.91 ns | 2.85 ns |
| Taken → `redirect_pc` gating (fanout 33) | 9.96 ns | 1.06 ns |
| `fault_ctrl` redirect qualification | 10.86 ns | 0.90 ns |
| `kill_if` fan-out → IF/ID registers (fanout 34) | 11.75 ns | 0.9 ns + setup |

A possible next step (not implemented): make `redirect_pc` independent of `branch_taken`, since `redirect_valid` already qualifies it. That changes the `branch_unit` interface contract checked by `tb_branch_unit` and needs its own review. Reaching 100 MHz would require shortening both near-equal paths.

## 10. Limitations

- Out-of-context implementation: no board I/O, approximate clock source. The figures must be re-confirmed in a board-level design.
- The 93 MHz pass has a small margin (+0.034 ns); another seed, placement or tool version can vary by a similar amount.
- One implementation per configuration; no seed or strategy exploration.
- No post-implementation simulation or netlist equivalence check.
- No hardware test yet.
