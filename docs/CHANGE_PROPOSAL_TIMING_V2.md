# Change Proposal TIMING-V2: EX-Stage Timing Fixes

**Status:** Implemented on branch `v2-timing`; proposed for merge.
**Scope:** Two RTL files and one unit bench. No architectural behavior change for valid instructions.
**Analysis:** [TIMING_ANALYSIS.md](TIMING_ANALYSIS.md)

## 1. Motivation

F05 required quantitative timing for the forwarded-address and forwarded-branch paths and stated that negative slack requires a reviewed change proposal. Implementation on a Spartan-7 XC7S50 (Vivado 2023.2, out-of-context) found the unchanged RTL limited to 80 MHz, with the worst paths in the EX stage. This proposal records two changes that raise the limit to 93 MHz.

## 2. Changes

| ID | File | Change | Lines |
|---|---|---|---|
| TV2-A | `rtl/core/rv32i_core_top.sv` | `lsu_ex.eff_addr` driven by a dedicated adder `ex_rs1_forwarded + idex_imm` instead of `alu_result` | +2, 1 changed |
| TV2-B | `rtl/core/pipeline_regs.sv` | Four ID/EX payload blocks clear on `rst` only, not on `kill_id` or `bubble_ex` | 4 changed |
| TV2-T | `tb/unit/tb_pipeline_regs.sv` | 13 ID/EX payload checks run only for valid slots | 13 changed, +3 comment |

## 3. Constraint check (FINAL-B01)

| Restriction | TV2-A | TV2-B |
|---|---|---|
| Extra pipeline register | None | None |
| Retiming | None | None |
| EX transaction edge moved | No | No |
| Load-use, redirect or fault schedule changed | No | No |
| Forwarding priority or readiness changed | No | No |

## 4. Architecture amendments

| Change | Architecture text affected | Amendment |
|---|---|---|
| TV2-A | Module mapping (§14): `lsu_ex` takes the ALU `eff_addr`, "No second address adder"; signal owners: `eff_addr` = "Existing ALU address result" | `eff_addr` is driven by a dedicated forwarded-rs1 + immediate adder. Values for loads and stores are unchanged; the cost is one 32-bit adder. |
| TV2-B | Packet contracts (§13): "Invalid packets have `valid=0`; other fields are functionally irrelevant, though deterministic diagnostic values are preferred where practical." | No amendment needed: the contract already makes invalid-packet fields irrelevant. TV2-B gives up the *preferred* deterministic values for the ID/EX payload, because clearing them is on the critical path. |

TV2-A changes a recorded architecture decision and needs the architecture owner's approval; merging this proposal is that approval. The technical architecture has been updated with the amendment marked.

## 5. Safety argument

**TV2-A.** The decoder sets `alu_op` = ADD, `op_a_sel` = rs1 and `op_b_sel` = immediate for every load and store, so `lsu_eff_addr` is bit-identical to `alu_result` whenever `mem_read` or `mem_write` is set. For other instructions, `dmem_re` and `dmem_we` are low and the address is not used. The only observable difference is the don't-care value on the `dmem_addr` port and the unused trace address field in those cycles.

**TV2-B.** The architecture defines a bubble by its valid bit: "An invalid slot is a bubble, not a reserved instruction or substituted NOP." `idex_valid` and every control that can cause an effect (`uses_rs1/2`, `is_jal`, `is_jalr`, `mem_read`, `mem_write`, `mem_size`, `load_unsigned`, `reg_write`, `wb_sel`) still clear on kill and bubble. Every consumer of the payload (load-use hazard detection, forwarding, ALU result into EX/MEM, branch unit, LSU, EX fault mux, trace) is gated by validity before it can have an effect. The payload clear values were described by the unit bench itself as verification hygiene.

**TV2-T.** Follows from TV2-B: payload of an invalid slot is no longer a defined value. Validity and all side-effect controls remain checked every cycle. The bench still passes on the v1 RTL.

## 6. Verification

| Evidence | Result |
|---|---|
| Full regression replay (same benches, arguments and pass markers as f06), Icarus 12.0 | 414/414 positive, 10/10 expected-negative |
| 16 unit benches × 2 trace modes, Icarus 12.0 | 32/32 pass |
| `tb_pipeline_regs`, Questa 2023.4 | 5,426,477 checks, 0 failures |
| Integration bench × 2 trace modes, Questa 2023.4 | PASS ALL tests=12 |
| Verilator 5.020 `--Wall`, 4 configurations | Diagnostics identical to v1 (27 / 5 / 49 / 27) |

No expected value was regenerated. The only test change is TV2-T, disclosed above with its check-count effect (6,309,177 → 5,426,477).

## 7. Measured result

| | v1 | v2 | Change |
|---|---|---|---|
| WNS at 10 ns, `TRACE_EN=0` | −2.402 ns | −0.633 ns | +1.77 ns |
| Timing met, `TRACE_EN=0` | 80.0 MHz | 93.0 MHz | +16% |
| Timing met, `TRACE_EN=1` | 71.4 MHz | 83.3 MHz | +17% |
| LUTs / FFs / block RAMs (`TRACE_EN=0`) | 1,453 / 355 / 8 | 1,460 / 356 / 8 | +7 / +1 / 0 |

## 8. Considered and rejected

**TV2-C**, the same reset-only clearing for the EX/MEM payload, passed the full regression but gave no measurable gain (−0.698 ns against −0.633 ns at 10 ns). It was reverted. See [TIMING_ANALYSIS.md §8](TIMING_ANALYSIS.md#8-a-fix-that-was-measured-and-rejected).

## 9. Effect on recorded evidence

- The accepted v1 source identities, portable lint manifest and historical evidence are unchanged. The pinned portable runner rejects v2 sources by design; v2 lint equivalence was established by diagnostic comparison.
- `rtl/core/rv32i_core_top.sv`, `rtl/core/pipeline_regs.sv` and `tb/unit/tb_pipeline_regs.sv` have new hashes in v2.
- Historical F01–F08 dispositions describe v1 and are not rewritten. F05 now records measured timing for both versions.
