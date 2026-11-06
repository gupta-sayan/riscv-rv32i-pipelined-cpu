# RV32I Processor Technical Architecture

## 1. Processor overview

This processor is a 32-bit, single-hart, single-issue, in-order RV32I design. It uses a five-stage pipeline and separate instruction/data interfaces connected to fixed-latency synchronous memories.

The design aims to make pipeline behavior explicit: memory transactions have a defined acceptance edge, dependent instructions receive the newest available value, redirects have a fixed bubble schedule, and terminal events drain older work before halting.

Its execution environment is deliberately restricted. There are no late memory faults, interrupts, MMIO effects or variable-latency transactions. These limits allow legal stores to commit in EX while preserving ordered fail-stop behavior.

This document is a technical restatement of ARCH-001 Revision C and its approved technical amendments, not a newly approved replacement specification. The original specification remains authoritative and unchanged. Required behavior is distinguished from recorded verification results; original source identities and verification references are preserved in Section 17.

### Reading order

The pipeline is introduced first, followed by instruction behavior, dependencies, control flow and memory access. Detailed pipeline packets and module interfaces appear after those concepts.

## 2. Five-stage pipeline

| Stage | Work performed |
|---|---|
| IF | Present the fetch PC, check instruction-access range and accept an instruction read or fetch-fault token. |
| ID | Decode, read registers, generate immediates, apply WB bypass and identify dependencies or terminal events. |
| EX | Forward operands, execute the ALU, resolve branches, check addresses and accept one legal data-memory transaction. |
| MEM | Format registered load data and select the next writeback value. |
| WB | Write the register file and report completion through the optional registered trace. |

```text
 PC ──> synchronous IMEM ──> ID ──> ID/EX ──> EX ──> EX/MEM ──> MEM ──> MEM/WB ──> WB
             │               ▲                ▲                  │                    │
       registered word    RF reads       forwarding muxes   load formatting       RF write
             │               ▲                ▲                                       │
      IF/ID PC/valid/fault   └── WB bypass ────┴── EX/MEM result / MEM/WB wb_data ──────┘
```

Every boundary has explicit validity. An invalid slot is a bubble, not a reserved instruction or substituted NOP.

The boundaries are IF/ID, ID/EX, EX/MEM and MEM/WB. `pipeline_regs` owns IF/ID metadata and the three later register groups. The IF/ID instruction word is physically held by the registered IMEM output.

There is no general EX hold. A load-use stall holds fetch/decode and inserts an invalid ID/EX slot while older instructions advance.

### Clock convention

`Ck` is the interval between rising edges `E(k-1)` and `Ek`.

A request accepted at `Ek` produces a new registered RAM output after that edge, during `C(k+1)`. A receiving pipeline register captures that new output no earlier than `E(k+1)`.

All signals belong to one clock domain. Bit vectors are unsigned unless the operation explicitly interprets them as signed.

## 3. Instruction set and execution environment

### Supported scope

The design accepts all 40 RV32I instruction mnemonics under this execution environment.

It does not implement:

- C, M, A, F or D extensions.
- CSR instructions, privileged trap handling, MRET or interrupts.
- An operating system, MMIO, caches or variable-latency memory.
- Runtime self-modifying code or a runtime ROM loader.

Instruction and data memories are preloaded externally.

ECALL and EBREAK are ordered terminal events. They do not invoke a privileged handler, enter EX as valid instructions or retire. There are no implied `mepc`, `mcause` or `mtvec` registers.

### Arithmetic and address semantics

Arithmetic, effective-address addition, PC-relative addition and PC+4 wrap modulo 2^32. Arithmetic overflow does not trap.

Signedness belongs to the operation, not the stored bit pattern. In particular:

- SLT/SLTI use signed comparison.
- SLTU/SLTIU use unsigned comparison.
- SLTIU first sign-extends its immediate, then compares the resulting 32-bit value as unsigned.
- Register shifts use the low five bits of the shift operand.
- Immediate shifts use `instr[24:20]`.
- SRA/SRAI propagate the sign bit.

### FENCE, HINTs and unsupported instructions

FENCE is a no-op because memory effects are single-hart, in program order and completed through the specified synchronous port. There is no device, buffer or reordering engine.

All fields other than the FENCE opcode and `funct3=000` are accepted, including nonzero `fm/pred/succ/rs1/rd`, FENCE.TSO and reserved-field combinations. FENCE has no source dependency or register write.

A future memory system with reordered or external effects must revisit this assumption.

FENCE.I, unsupported MISC-MEM encodings, CSR operations, MRET and nonexact SYSTEM words are illegal.

Recognized arithmetic HINTs with `rd=x0` execute the ordinary operation with the write suppressed. `ADDI x0,x0,0` is legal NOP. HINTs have no register or memory side effects. Loads to x0 are not removable HINTs: they still access memory and perform fault checks.

Unsupported non-FENCE reserved encodings produce the EEI ILLEGAL event.

## 4. Decode, immediates and execution controls

### Instruction fields

| Field | Bits |
|---|---|
| `opcode` | `[6:0]` |
| `rd` | `[11:7]` |
| `funct3` | `[14:12]` |
| `rs1` | `[19:15]` |
| `rs2` | `[24:20]` |
| `funct7` | `[31:25]` |

If `instr[1:0] != 2'b11`, the complete 32-bit word is illegal.

### Immediate construction

| Kind | 32-bit result |
|---|---|
| I | Sign-extend `instr[31:20]` from 12 bits. |
| S | Sign-extend `{instr[31:25],instr[11:7]}` from 12 bits. |
| B | Sign-extend `{instr[31],instr[7],instr[30:25],instr[11:8],1'b0}` from 13 bits. |
| U | `{instr[31:12],12'b0}` |
| J | Sign-extend `{instr[31],instr[19:12],instr[20],instr[30:21],1'b0}` from 21 bits. |

### Instruction legality

An unlisted field combination is illegal. Register-writing instructions suppress writes when `rd=0`.

| Opcode | Legal fields | Operation and sources |
|---|---|---|
| `0110111` | Any remaining fields | LUI; U immediate; no sources |
| `0010111` | Any remaining fields | AUIPC; PC+U; no sources |
| `1101111` | Any remaining fields | JAL; PC+J target, PC+4 link; no sources |
| `1100111` | `funct3=000` | JALR; rs1+I target with bit0 cleared; PC+4 link |
| `1100011` | `funct3=000,001,100,101,110,111` | BEQ/BNE/BLT/BGE/BLTU/BGEU; rs1 and rs2 |
| `0000011` | `funct3=000,001,010,100,101` | LB/LH/LW/LBU/LHU; rs1 |
| `0100011` | `funct3=000,001,010` | SB/SH/SW; rs1 and rs2 |
| `0010011` | `funct3=000,010,011,100,110,111` | ADDI/SLTI/SLTIU/XORI/ORI/ANDI; rs1 |
| `0010011` | `funct3=001`, `funct7=0000000` | SLLI; rs1 |
| `0010011` | `funct3=101`, `funct7=0000000/0100000` | SRLI/SRAI; rs1 |
| `0110011` | `funct3=000`, `funct7=0000000/0100000` | ADD/SUB; rs1 and rs2 |
| `0110011` | `funct3=101`, `funct7=0000000/0100000` | SRL/SRA; rs1 and rs2 |
| `0110011` | `funct3=001,010,011,100,110,111`, only `funct7=0000000` | SLL/SLT/SLTU/XOR/OR/AND; rs1 and rs2 |
| `0001111` | `funct3=000`; all other fields accepted | FENCE; no sources or WB |
| `1110011` | Exact word `0x00000073` | ECALL terminal event |
| `1110011` | Exact word `0x00100073` | EBREAK terminal event |

### Control encodings

| Control | Width | Encoding |
|---|---:|---|
| `alu_op` | 4 | `0000` ADD; `0001` SUB; `0010` AND; `0011` OR; `0100` XOR; `0101` SLL; `0110` SRL; `0111` SRA; `1000` SLT; `1001` SLTU; `1010` PASS_B; others invalid |
| `imm_kind` | 3 | `000` NONE; `001` I; `010` S; `011` B; `100` U; `101` J; others invalid |
| `op_a_sel` | 2 | `00` forwarded rs1; `01` PC; `10` ZERO; `11` invalid |
| `op_b_sel` | 2 | `00` forwarded rs2; `01` immediate; `10` constant 4; `11` invalid |
| `br_kind` | 3 | `000` NONE; `001` BEQ; `010` BNE; `011` BLT; `100` BGE; `101` BLTU; `110` BGEU; `111` invalid |
| `mem_size` | 2 | `00` BYTE; `01` HALF; `10` WORD; `11` invalid |
| `wb_sel` | 2 | `00` NONE; `01` EX_RESULT; `10` LOAD_DATA; `11` invalid |

`mem_read`, `mem_write`, `reg_write`, `uses_rs1`, `uses_rs2`, `load_unsigned`, `is_jal` and `is_jalr` are one-bit controls.

### Datapath operations

| Operation | Required computation |
|---|---|
| Load/store address | Forwarded rs1 + immediate, using the existing ALU |
| Branch comparison | Forwarded rs1 and rs2 in the branch comparator |
| Branch target | PC+B immediate |
| JAL target | PC+J immediate |
| JALR target | `(forwarded rs1 + I immediate) & 0xFFFFFFFE` |
| LUI | PASS_B of U immediate |
| AUIPC | PC+U immediate |
| Jump link | PC+4, carried in `ex_result` |
| Store payload | Independently forwarded rs2, before the ALU immediate mux |

Jump targets are local EX computations. JAL/JALR links use the single `ex_result` path; there is no additional PC+4 packet field or writeback selector.

*Technical note: Module 17 D01 closes the constant-4 operand-selector finding. It is separate from architectural D01, which specifies separate instruction/data interfaces.*

## 5. Register file and WB-to-ID bypass

The register file contains 32 registers of 32 bits, with two asynchronous read ports and one rising-edge write port.

x0 always reads zero and ignores writes. Registers x1–x31 are not reset.

WB-to-ID bypass is mandatory. When valid WB writes a nonzero destination matching an ID source, ID uses `MEM/WB.wb_data` instead of relying on technology-specific same-edge register-file behavior.

The same registered writeback value supplies register writes, WB-to-ID bypass and MEM/WB-to-EX forwarding.

### Accepted register-file interface mapping

| Canonical interface | Implemented interface |
|---|---|
| Module `regfile` | `reg_file` |
| `clk` | `clk` |
| Synchronous reset/write suppression | `rst` |
| `rs1`, `rs2` | `rs1_addr`, `rs2_addr` |
| `rs1_data`, `rs2_data` | Unchanged |
| `wb_rd` | `rd_addr` |
| `wb_data` | `rd_data` |
| `wb_we` | `rd_we` |

WB bypass remains in the top-level integration.

*Technical note: ARCH-M17-D02 accepts this mapping without changing register behavior or timing.*

## 6. Forwarding and load-use interlock

### Forwarding priority

For each source actually used by the EX instruction:

1. Examine the youngest matching valid EX/MEM producer.
2. If there is no EX/MEM match, examine MEM/WB.
3. Otherwise use the captured ID/EX operand, which may already include WB-to-ID bypass.

A producer must have register-write intent and a nonzero destination. Invalid producers and x0 never forward.

| Selector | Source |
|---|---|
| `00` | Original/bypassed ID/EX value |
| `01` | Ready EX/MEM `ex_result` |
| `10` | MEM/WB `wb_data` |
| `11` | Invalid/design-error indication |

`fwd_a_sel`, `fwd_b_sel` and `fwd_store_sel` are each two bits.

Store data uses forwarded rs2 independently of the ALU's immediate operand selection. The separate store selector is a logical contract; it does not require an additional physical mux if the implementation shares equivalent logic.

### Nonready producer handling

A matching EX/MEM load whose value is not ready must not be bypassed in favor of an older matching MEM/WB producer.

This state should be unreachable during correct legal execution. If detected:

- Assert the combinational `fwd_nonready_error`.
- Trigger the verification assertion and capture the sticky diagnostic.
- Do not introduce a stall, replay, extra transaction or EEI exception.
- Do not define a recovery result for the erroneous execution.

`forward_unit` remains combinational and selector-only. The top level owns the forwarding data muxes and supplies EX/MEM `ex_result` and MEM/WB `wb_data`.

Its implemented inputs are:

```text
idex_valid
idex_rs1[4:0], idex_rs2[4:0]
idex_uses_rs1, idex_uses_rs2, idex_is_store
exmem_valid, exmem_rd[4:0], exmem_reg_write, exmem_result_ready
memwb_valid, memwb_rd[4:0], memwb_reg_write
```

Readiness must distinguish ready EX results from nonready loads.

*Technical notes: A01 specifies the nonready diagnostic. ARCH-M17-D02 accepts the selector-only interface and external data muxes.*

### Load-use interlock

A true load-use dependency requires:

```text
valid IF/ID instruction
&& no ID terminal event
&& valid load in ID/EX
&& ID/EX destination != x0
&& an actually used ID source matches that destination
```

The interlock holds PC and IF/ID for one cycle, holds the IMEM output, inserts an invalid ID/EX slot and allows older packets to advance.

| Cycle/edge | Load | Immediate consumer |
|---|---|---|
| C1 | IF | — |
| C2 | ID | IF |
| C3 | EX; read request before E3 | ID; dependency detected |
| E3 | RAM accepts read; load enters EX/MEM | Bubble enters ID/EX; PC and IF/ID hold |
| C4/E4 | MEM; registered load word available | Consumer decodes and enters ID/EX |
| C5 | WB; registered load value available | EX; MEM/WB forwarding supplies value |
| C6 | — | MEM |
| C7 | — | WB |

Exactly one bubble is inserted. Independent instructions do not incur a read-response hold cycle.

Stores consume base and payload, branches consume both comparison operands, and JALR consumes rs1. LUI, AUIPC, JAL, FENCE and terminal events create no false source dependencies.

There is no general EX hold, skid buffer or replay mechanism.

## 7. Branches and redirects

BEQ/BNE compare equality, BLT/BGE compare signed values, and BLTU/BGEU compare unsigned values.

JALR performs the wrapped addition, clears bit0 and then checks alignment for IALIGN=32. Taken branch and jump targets must be word-aligned.

A misaligned taken target produces INSTR_MISALIGNED at the controlling instruction's PC and does not redirect. An untaken branch does not test its unused target for an alignment fault.

An aligned target outside IMEM redirects normally. Its later fetch produces an instruction-access token at the target PC.

### Redirect ownership and priority

- `branch_unit` owns raw legal `redirect_valid` and `redirect_pc`.
- `fault_ctrl` owns `fetch_redirect_valid`, qualified by RUN state, valid EX instruction and no overriding EX fault.
- `pc_fetch` consumes the qualified redirect and target.

`fetch_redirect_valid && stop_fetch` is forbidden.

The PC update priority is:

```text
reset > eligible redirect > normal sequential advance > hold
```

An eligible redirect overrides `hold_if`. DRAIN and HALTED accept neither new fetch slots nor redirects.

### Redirect schedule

For a branch or jump resolved in EX during C3:

| Cycle/edge | Required behavior |
|---|---|
| C3 | Resolve the legal target; younger ID and IF slots are present. |
| E3 | Invalidate younger IF/ID and ID/EX entries; load target PC. |
| C4/E4 | Present and accept target fetch. |
| C5/E5 | Decode target and transfer it to ID/EX, unless it is an ID terminal event. |
| C6 | Execute a nonterminal target instruction. |

Exactly two EX bubbles follow the redirect, in C4 and C5. Untaken branches introduce no redirect bubble. An ID terminal target follows Section 10 rather than entering EX.

A speculative legal IMEM read at E3 is harmless because its slot is invalidated.

*Technical note: A03 defines fetch-boundary qualification without changing this schedule.*

## 8. Memory map and synchronous interfaces

### Fixed address map

| Region | Inclusive range | Size and permission |
|---|---|---|
| IMEM | `0x00000000–0x00003FFF` | 16 KiB, instruction fetch only |
| Reserved gap | `0x00004000–0x0000FFFF` | No access |
| DMEM | `0x00010000–0x00013FFF` | 16 KiB, data loads/stores only |
| All other addresses | Remaining addresses | No access |

Addresses are byte addresses. The reset PC is fixed at `0x00000000`. These constants are architectural choices, not arbitrary parameter overrides.

For the fixed, naturally aligned regions:

```text
imem_in_range = fetch_pc[31:14] == 18'd0
dmem_in_range = effective_addr[31:14] == 18'd4
```

The existing LSU uses equivalent inclusive range comparisons. Naturally aligned 1-, 2- and 4-byte accesses cannot cross the region boundary when their starting address is legal, so a 33-bit bounds adder is unnecessary.

Any future arbitrary base/size configuration requires overflow-safe widened bounds checking and renewed timing analysis.

### Instruction interface

| Signal | Width | Direction from core | Meaning |
|---|---:|---|---|
| `imem_addr` | 32 | Output | Candidate byte PC |
| `imem_en` | 1 | Output | Read accepted at the rising edge |
| `imem_rdata` | 32 | Input | Registered instruction word; holds when disabled |
| `fetch_issue` | 1 | Internal | Accept an instruction or token slot |
| `fetch_token_fault` | 1 | Internal | Slot is an instruction-access token |
| `ifid_valid`, `ifid_pc` | 1, 32 | Internal | Registered slot validity and PC |

`fetch_issue` and `imem_en` are different:

| Situation | Required behavior |
|---|---|
| In-range issue | Read IMEM and capture matching valid, nonfault metadata at the same edge. |
| Out-of-range issue | Do not read IMEM; capture a valid fault token and its requested PC; advance according to sequential candidate policy. |
| Load-use hold | No new issue/read; hold PC, metadata and RAM output. |
| Redirect or terminal detection | A legal speculative read may occur, but the younger slot is invalidated. |

For a fault token, the held RAM word is stale and ignored. No out-of-range RAM access occurs.

The token is provisional until ID. In that same cycle, older EX fault/redirect arbitration takes precedence. Fetch does not irreversibly capture a terminal record.

### IF/ID ownership

`pc_fetch` owns the fetch PC, next-PC logic, candidate address, enable, issue and combinational fault indication.

`pipeline_regs` exclusively owns registered IF/ID PC, validity and fault metadata. `imem_sync` owns the registered instruction word. They describe the same accepted slot.

IF/ID metadata priority is reset > kill > hold > advance. No duplicate register, duplicate driver or additional pipeline cycle is permitted.

A selected RAM primitive that cannot hold its output while disabled requires an explicit buffer preserving this timing contract.

*Technical note: A02 fixes this ownership.*

### Data interface

| Signal | Width | Meaning |
|---|---:|---|
| `dmem_addr` | 32 | EX byte effective address |
| `dmem_re`, `dmem_we` | 1 each | Read/write acceptance at the EX-ending edge |
| `dmem_wmask` | 4 | Byte write strobes |
| `dmem_wdata` | 32 | Pre-shifted store payload |
| `dmem_rdata` | 32 | Registered aligned read word |

`dmem_re && dmem_we` is forbidden. At most one transaction is accepted per edge.

The word index is `((addr-0x10000)>>2)` within DMEM; address bits `[13:2]` give the equivalent index for this map.

A read updates `dmem_rdata` after the acceptance edge. The output holds when `dmem_re=0`. A store updates selected lanes at that edge. Write strobes and write data are meaningful with `dmem_we`.

There is no late error response, MMIO effect or requirement for simultaneous same-word read/write behavior.

Address, data, strobes and enables must meet setup before the EX-ending edge. No extra address register may delay acceptance.

*Technical notes: architectural D01 requires separate interfaces; D02/D02-T1 require registered reads and EX initiation; D03 requires EX acceptance for both reads and writes.*

## 9. Loads, stores and acceptance rules

### Alignment and lane handling

Alignment is checked before range/permission:

| Size | Required alignment |
|---|---|
| Byte | Any address |
| Halfword | `addr[0]=0` |
| Word | `addr[1:0]=00` |

A failed access issues neither read nor write. If both alignment and range fail, report misalignment.

Let `lane=addr[1:0]`.

| Operation | Allowed lanes | Data handling |
|---|---|---|
| LB/LBU | 0,1,2,3 | Select byte and sign/zero extend. |
| LH/LHU | 0,2 | Select halfword and sign/zero extend. |
| LW | 0 | Return full word. |
| SB | 0,1,2,3 | Mask `0001<<lane`; zero-extend `rs2[7:0]`, then shift by `8*lane`. |
| SH | 0,2 | Mask `0011<<lane`; zero-extend `rs2[15:0]`, then shift by `8*lane`. |
| SW | 0 | Mask `1111`; full rs2. |

Memory is little-endian: the lowest-addressed byte occupies word bits `[7:0]`.

Loads read the containing aligned word. MEM selects and extends the requested lane. Loads to x0 still perform the access and fault checks; only register writeback and false destination dependencies are suppressed.

Examples:

```text
LB  0x13FFF   legal
LH  0x13FFE   legal
LW  0x13FFC   legal
LW  0x13FFE   misaligned
LB  0x14000   access fault
```

### Store acceptance

The architectural predicate, evaluated before the edge, is:

```text
dmem_we =
    (state_q == RUN)
    && !rst
    && idex_valid
    && idex_mem_write
    && store_aligned
    && store_in_dmem
```

Legal decode ensures valid size and mutually exclusive read/write intent. The RTL additionally guards these conditions.

The restricted EEI guarantees that older instructions cannot later report a fault requiring cancellation of this store. That is an architectural invariant, not a synthesized `older_fault_cancel` signal.

An `already_issued` bit is unnecessary because EX is never held across another acceptance edge.

A legal older EX store commits once even when a younger ID ECALL or illegal instruction is detected. A faulting EX store does not commit. A store write and older WB retirement may occur at the same detecting edge.

Invalid slots, reset, DRAIN and HALTED cannot issue stores. There is no MEM-stage store.

## 10. Fault handling and ordered fail-stop

### Fault codes

`fault_cause` is a four-bit EEI code, not privileged RISC-V `mcause`.

| Code | Cause | Fault PC |
|---|---|---|
| `0x0` | NONE | Zero after reset and during normal run |
| `0x1` | INSTR_ACCESS | Requested PC carried by the ID fetch token |
| `0x2` | ILLEGAL | ID instruction PC |
| `0x3` | BREAKPOINT | EBREAK ID PC |
| `0x4` | ECALL | ECALL ID PC |
| `0x5` | LOAD_MISALIGNED | EX instruction PC |
| `0x6` | LOAD_ACCESS | EX instruction PC |
| `0x7` | STORE_MISALIGNED | EX instruction PC |
| `0x8` | STORE_ACCESS | EX instruction PC |
| `0x9` | INSTR_MISALIGNED | EX branch/jump PC |
| `0xA–0xF` | Reserved | Must not occur |

There is no runtime IF-misalignment event for normal sequential fetch. A misaligned taken target is caught in EX.

### Same-edge priority

1. Synchronous reset.
2. RUN EX fault.
3. RUN legal EX redirect.
4. RUN ID terminal event.
5. RUN load-use interlock.
6. RUN normal advancement.
7. DRAIN progression.
8. HALTED hold.

EX is older than ID. A legal EX redirect cancels younger ID faults and speculative fetch tokens. A younger ID event never cancels an older legal EX store.

`fault_ctrl` performs this arbitration combinationally in the detecting cycle. No additional arbitration cycle is inserted.

| Event | `kill_if` | `kill_id` | `kill_ex` | Result |
|---|---:|---:|---:|---|
| EX fault | 1 | 1 | 1 | Capture EX record; suppress faulting side effects; enter DRAIN. |
| Legal redirect | 1 | 1 | 0 | Select target; preserve redirecting EX instruction; no terminal record. |
| ID terminal | 1 | 1 | 0 | Capture ID record; preserve older EX; enter DRAIN. |

Kills outrank ordinary hold/bubble behavior at the pipeline boundaries.

A branch and a load causing a load-use dependency cannot be the same EX instruction; no additional combined redirect/load-interlock case is introduced.

### RUN, DRAIN and HALTED

At the detecting rising edge, capture a single:

```text
{fault_pc[31:0], fault_cause[3:0]}
```

The record remains unchanged until reset. There is no age tag, replacement queue or later record substitution.

The faulting instruction does not advance as valid work. Younger slots are invalidated. Older instructions continue toward WB, with no new instruction admitted to EX.

The terminal event is not retired. MEM/WB cannot introduce a late exception.

Define:

```text
drained = !idex_valid && !exmem_valid && !memwb_valid
```

`fault_ctrl` computes this combinationally from registered stage-valid bits. It does not depend on `retire_valid`.

In DRAIN, enter HALTED at the first rising edge where `drained` is already true before the edge.

| Event | Following behavior |
|---|---|
| Last older instruction retires at `Ew` | Its registered trace pulse is high in `C(w+1)`; `drained=1`; enter HALTED at `E(w+1)`, visible in `C(w+2)`. |
| Terminal captured at `Ed`, with no older valid work | DRAIN occupies `C(d+1)`; enter HALTED at `E(d+1)`, visible in `C(d+2)`. |

There is no artificial terminal-entry interval. `halted && retire_valid` is forbidden.

HALTED disables register writes, data requests and instruction fetch, and holds architectural state. Deasserting reset alone does not restart a halted processor; an active reset edge is required.

*Technical note: architectural D04 supplies the no-late-fault assumption that makes this ordering sufficient.*

## 11. Reset and startup

`rst` is active-high and synchronous. The environment must hold it high through at least one rising edge.

Before any edge with reset asserted:

- Register-file and RAM writes are suppressed.
- No instruction request is accepted.

At that edge:

- Pipeline validity, pending event state and retirement pulse clear.
- The controller becomes RUN.
- Halt, fault diagnostics and A01 sticky state clear.
- The next request PC becomes `RESET_PC=0`.

Registers x1–x31 and IMEM/DMEM contents are not reset. Images must be loaded before reset release, and software must initialize every register value it reads.

| Edge/interval | Startup behavior |
|---|---|
| E0, reset high | Empty pipeline, PC=0, RUN |
| C1 | Issue first fetch at zero |
| E1 | IMEM and matching IF/ID metadata accept; PC advances to 4 |
| C2/E2 | Decode first instruction and capture ID/EX |
| C3/E3 | Execute and capture EX/MEM |
| C4/E4 | MEM and capture MEM/WB |
| C5/E5 | First instruction may write back/retire |

An invalid static RESET_PC, including misalignment, must be rejected before simulation/synthesis. A missing memory image is a setup failure. Neither creates an unspecified runtime behavior.

## 12. Trace and A01 diagnostics

### Retirement trace

`TRACE_EN` is static at elaboration, defaults to 1 and must not be toggled during execution.

| Output | Width | Meaning |
|---|---:|---|
| `retire_valid` | 1 | Registered completion indication |
| `retire_pc`, `retire_instr` | 32 each | Completed instruction identity |
| `retire_rd`, `retire_rd_we`, `retire_rd_data` | 5, 1, 32 | Actual register write; write-enable is zero for x0/nonwriting instructions |
| `retire_mem_valid`, `retire_mem_write` | 1 each | Accepted memory operation and store indicator |
| `retire_mem_addr`, `retire_mem_wmask`, `retire_mem_wdata`, `retire_mem_rdata` | 32, 4, 32, 32 | Transaction metadata; raw word for loads |

Trace payload is interpreted with its validity flags.

An ALU instruction or store normally retires at WB in program order, although the store's memory effect occurred in EX. Faulting and terminal instructions do not retire.

`retire_valid` is registered at the WB-ending edge and observed during the following cycle, even if MEM/WB is then empty. Its relationship to HALTED is defined in Section 10.

### Disabled trace

With `TRACE_EN=0`:

- Every top-level `retire_*` output is tied to zero.
- Trace-only instruction and transaction-history retention is excluded.
- Nonfunctional `mem_write` history can be omitted where otherwise unused.
- Functional instruction data, stage validity, PCs, register identities, operands/results, load lane/size/signedness and MEM/WB `wb_data` remain as required.
- The fault controller and terminal diagnostics remain active.

Because zero trace outputs make trace-only checks insufficient, verification must also inspect internal completion/drain and register-file/memory outcomes.

### Always-on terminal diagnostics

| Output | Width | Behavior |
|---|---:|---|
| `halted` | 1 | Registered terminal state; holds until active reset |
| `fault_pc` | 32 | Captured terminal PC; stable until reset |
| `fault_cause` | 4 | Captured EEI cause; stable until reset |

### Forwarding diagnostic

`forward_unit` drives scalar combinational `fwd_nonready_error`.

A separate internal register, `fwd_nonready_sticky`, belongs to `rv32i_core_top`. At each rising edge it captures an asserted error and retains it until synchronous reset.

This diagnostic does not change architectural execution, raise an EEI fault, stall, replay or initiate memory traffic.

Correct combinational and sticky RTL behavior is required. Physical retention of an unconsumed sticky register after synthesis is not required; no additional output or preservation attribute is implied.

*Technical notes: A01 defines the diagnostic, A01-OWN assigns the sticky register to the top level, and ARCH-M17-A01-SYN accepts removal of unconsumed physical storage.*

## 13. Pipeline packet contracts

These are logical fields, not required literal SystemVerilog structures. Invalid packets have `valid=0`; other fields are functionally irrelevant, though deterministic diagnostic values are preferred where practical.

### IF/ID

| Field | Width | Purpose |
|---|---:|---|
| `valid` | 1 | Occupied slot |
| `pc` | 32 | Requested instruction/token PC |
| `fetch_fault` | 1 | Instruction-access token |
| `instr` | 32 | Registered IMEM word; ignored for a token |

The logical width is 66 bits. The instruction is physically held by IMEM, while `pipeline_regs` stores the metadata atomically with it.

The instruction word is functional even when tracing is disabled. No extra instruction register may add a cycle.

### ID/EX

| Fields | Widths |
|---|---|
| `valid`, `pc`, `instr` | 1, 32, 32 |
| `rs1`, `rs2`, `rd` | 5 each |
| `rs1_value`, `rs2_value`, `imm` | 32 each |
| `alu_op`, `imm_kind` | 4, 3 |
| `op_a_sel`, `op_b_sel`, `br_kind` | 2, 2, 3 |
| `uses_rs1`, `uses_rs2` | 1 each |
| `is_jal`, `is_jalr` | 1 each |
| `mem_read`, `mem_write` | 1 each |
| `mem_size`, `load_unsigned` | 2, 1 |
| `reg_write`, `wb_sel` | 1, 2 |

Only `instr` is trace-only. Functional controls remain attached to their instruction.

ECALL, EBREAK, illegal instructions and fetch-error tokens are handled in ID and do not enter EX as valid packets.

### EX/MEM

| Fields | Widths | Purpose |
|---|---|---|
| `valid`, `pc`, `instr` | 1, 32, 32 | Instruction identity; `instr` is trace-only |
| `rd`, `reg_write`, `wb_sel` | 5, 1, 2 | Writeback intent |
| `ex_result` | 32 | ALU/LUI/AUIPC result or jump link |
| `mem_read`, `mem_write`, `mem_size`, `load_unsigned` | 1, 1, 2, 1 | Qualified memory operation/history |
| `load_lane` | 2 | Functional load address low bits |
| `mem_addr`, `mem_wdata`, `mem_wmask` | 32, 32, 4 | Optional transaction trace |

`mem_write` is history of the accepted EX store, not an active write enable. No store occurs in MEM.

Load lane, size and signedness remain functional with tracing disabled. A separate PC+4 field is unnecessary.

### MEM/WB

| Fields | Widths | Purpose |
|---|---|---|
| `valid`, `pc` | 1, 32 | Functional occupancy and source PC |
| `rd`, `reg_write` | 5, 1 | Functional write intent |
| `wb_data` | 32 | Single registered writeback value |
| `instr` | 32 | Optional trace |
| `mem_read`, `mem_write` | 1 each | Optional transaction trace |
| `mem_addr`, `mem_wdata`, `mem_wmask`, `mem_rdata` | 32, 32, 4, 32 | Optional transaction trace |

During MEM, `load_formatter` uses the registered DMEM word and EX/MEM load metadata. One combinational selection chooses formatted load data or `ex_result`; NONE/invalid selections do not authorize a write.

MEM/WB captures that single value. Register writes, WB-to-ID bypass and MEM/WB-to-EX forwarding never recompute a two-way load/result mux.

This places formatting/selection delay in MEM and reduces selection on the WB forwarding path. Both timing paths still require qualification. Optional `mem_rdata` is unformatted trace data only.

## 14. Module interfaces and signal ownership

All `clk` and `rst` ports are one bit.

| Module | Interface and responsibility |
|---|---|
| `rv32i_core_top` | Clock/reset, static trace parameter, external memory ports and trace/terminal outputs; owns integration, bypasses, forwarding data muxes and sticky diagnostic. |
| `pc_fetch` | Clock/reset, hold/stop, qualified redirect and 32-bit target; produces 32-bit address and issue/enable/fault signals. |
| `imem_sync` | Clock, enable and 32-bit address to a held registered 32-bit word. |
| `decoder` | 32-bit instruction/PC and fetch-fault input to legality, 5-bit register IDs and Section 4 controls. |
| `imm_gen` | 32-bit instruction and 3-bit kind to 32-bit immediate. |
| `reg_file` | Section 5 mapped interface; asynchronous reads and synchronous write. |
| `pipeline_regs` | Section 13 packets, candidate fetch metadata and kill/hold/bubble controls; owns boundary state. |
| `hazard_ctrl` | ID validity/event/usage/5-bit sources and EX validity/load/5-bit destination to hold/bubble. |
| `forward_unit` | Section 6 producer/source identities to three 2-bit selectors and scalar error. |
| `alu` | Two 32-bit operands and 4-bit operation to 32-bit result. |
| `branch_unit` | Forwarded 32-bit operands, PC/immediate, 3-bit branch kind and jump flags to raw redirect, 32-bit target and target-misalignment flag. |
| `lsu_ex` | ALU `eff_addr[31:0]`, forwarded store data, size/intents and valid/RUN/reset qualification to memory signals and LSU event. No second address adder. |
| `ex_event_mux` | EX validity/PC, LSU event/cause and target-misalignment input to one EX event triple. |
| `fault_ctrl` | EX/ID events, raw redirect and stage valids to qualified redirect, kills, drain/stop and terminal diagnostics. |
| `dmem_sync` | Section 8 data interface; registered reads and byte-strobed writes. |
| `load_formatter` | 32-bit word, 2-bit lane/size and unsigned flag to 32-bit result. |
| `wb_trace` | MEM/WB value/history, clock/reset/halt and static trace parameter to functional WB and registered trace. |

### Unique signal owners

| Signals | Widths | Driver and meaning |
|---|---|---|
| `ex_evt_valid/cause/pc` | 1/4/32 | `ex_event_mux`; EX fault only, not a legal redirect |
| `id_evt_valid/cause/pc` | 1/4/32 | Decoder/ID adapter; ID terminal event |
| `redirect_valid/redirect_pc` | 1/32 | `branch_unit`; raw legal candidate and target |
| `fetch_redirect_valid` | 1 | `fault_ctrl`; qualified redirect to fetch |
| `kill_if` | 1 | `fault_ctrl`; invalidate IF/ID |
| `kill_id` | 1 | `fault_ctrl`; suppress ID-to-EX transfer |
| `kill_ex` | 1 | `fault_ctrl`; suppress faulty EX packet/side effects |
| `enter_drain` | 1 | `fault_ctrl`; capture event and transition RUN→DRAIN |
| `stop_fetch` | 1 | `fault_ctrl`; block new fetch in DRAIN/HALTED |
| `drained` | 1 | `fault_ctrl`; registered-stage-valid equation |
| `hold_if` | 1 | `hazard_ctrl`; true load-use hold |
| `bubble_ex` | 1 | `hazard_ctrl`; invalid ID/EX insertion |
| `fwd_a_sel`, `fwd_b_sel`, `fwd_store_sel` | 2 each | `forward_unit`; operand/store selection |
| `fwd_nonready_error` | 1 | `forward_unit`; nonready-producer error |
| `eff_addr` | 32 | Existing ALU address result |

Reset and kills outrank ordinary holds/bubbles/advancement at the appropriate boundary.

For a token, ECALL, EBREAK or illegal word, `id_evt_valid=1` and both source-usage flags are zero. Stale instruction bits cannot create a false dependency.

Legal instructions do not simultaneously generate LSU and branch-target faults; verification checks source exclusivity. No additional architectural dual-fault behavior is introduced.

Related combinational blocks may be physically combined only while preserving logical interfaces, unique drivers and timing.

## 15. Software images and verification requirements

### Software-image contract

Generate RV32I/ILP32 freestanding code, for example:

```text
-march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -nostartfiles
```

Record exact compiler/binutils versions and all active flags.

Place `.init`, `.text` and executable instructions at IMEM base zero. Data, `.rodata`, stack and `.bss` must lie within DMEM. Startup must not assume CSR or privileged trap support.

Export separate little-endian `imem.hex` and `dmem.hex` images with documented word order. Preload before reset release; initialize `.bss`, stack and every x1–x31 value read by software.

Tests normally end with ECALL/cause `0x4`, or an expected specific error. Compare final state and retirement/transaction behavior against a reference model implementing this EEI.

### Directed verification families

| ID | Required coverage and expectation |
|---|---|
| V01 | Reset/first fetch with uninitialized GPRs; first decoded PC zero and no reset retirement. |
| V02 | Register/immediate arithmetic and logic; modulo-2^32 behavior. |
| V03 | Signed/unsigned comparisons, negative immediates and extreme operands. |
| V04 | Shifts by 0/31, arithmetic sign propagation and illegal shift encodings. |
| V05 | LUI, AUIPC and PC-wrap arithmetic. |
| V06 | NOP and arithmetic HINTs; no x0 write or terminal event. |
| V07 | Nonzero/reserved FENCE fields and FENCE.TSO; accepted no-op. |
| V08 | FENCE.I, CSR, MRET, compressed-looking and all-zero/all-one illegal words. |
| V09 | Exact ECALL/EBREAK and nonexact SYSTEM encodings; correct cause/PC. |
| V10 | Every legal load lane and sign/zero-extension boundary. |
| V11 | Every legal store lane/strobe; only intended bytes change. |
| V12 | DMEM first/last addresses, crossing/out-of-range and simultaneous alignment/range failures; alignment wins. |
| V13 | Legal, misaligned and unmapped loads to x0 still access or fault. |
| V14 | EX/MEM forwarding, MEM/WB forwarding and WB-to-ID bypass. |
| V15 | Competing matches, stale MEM/WB and nonready EX/MEM; newest producer and no stale fallback. |
| V16 | Load→ALU/branch/store-data/JALR; exactly one bubble. |
| V17 | ALU→store/JALR/ALU forwarding without unnecessary bubbles. |
| V18 | All six branch comparisons, signed/unsigned, taken/untaken. |
| V19 | JAL/JALR link, bit0 clearing, taken-target misalignment and untaken-target nonfault. |
| V20 | Redirect cancellation of speculative out-of-range token; exactly two EX bubbles. |
| V21 | Last-IMEM ECALL wins over younger speculative fetch fault. |
| V22 | Older store versus younger terminal event, EX fault priority, immutable diagnostics and ALU→ECALL retirement/halt timing. |
| V23 | Reset during fetch/load/EX store, DRAIN/HALTED and bare-event halt timing; include accepted-fetch reset supplement. |
| V24 | Simultaneous rs1 EX/MEM and rs2 MEM/WB forwarding. |
| V25 | Fetch token whose stale source bits match an EX load destination; no false hold. |
| V26 | Redirect to `0xFFFFFFFC` with sequential wrap to zero; target token wins and wrapped slot has no effects. |
| V27 | Identical architectural outcomes in both trace modes, with trace outputs zero when disabled. |

### Required invariants

Verification must check:

- A write request implies a valid legal EX store.
- Read and write never assert together; requests do not repeat because an instruction is held.
- Held IF/ID state is stable.
- `imem_en` implies `fetch_issue`, in-range address and no reset.
- A fetch-fault token does not enable IMEM.
- Nonready EX/MEM loads never supply a ready value or allow stale fallback.
- x0 is never written; killed instructions never retire.
- Completion PCs follow program order except for actual legal redirects.
- Captured fault PC/cause remain unchanged until reset.
- An ID event does not cancel a legal older EX store.
- `drained` equals the registered-stage-valid equation.
- Retirement is observed after its completion edge.
- HALTED has no retirement, data request or instruction request.
- Every accepted load/store is legal and naturally aligned.
- Reset, redirect, interlock and diagnostic behavior obey their timing contracts.

With tracing disabled, internal completion and architectural-state checks remain required.

Passing results require saved logs and reproducible commands. Correcting specification text is not itself evidence of passing RTL.

## 16. Timing qualification and verified scope

### Deferred timing work

The provisional target is 20 MHz/50 ns. It is not a measured frequency guarantee.

The original architecture required two timing shells before full integration. That deadline was missed and remains recorded.

FINAL-B01 approves deferral to the technology-specific implementation phase. F05 remains **PARTIAL / DEFERRED**. Before technology-specific timing acceptance, establish:

1. Selected FPGA device or ASIC technology/library.
2. Synthesis and STA tool versions.
3. Clock definitions and timing constraints.
4. Memory primitive inference and disabled-read output hold behavior.
5. Forwarded operand → EX address generation → alignment/range checks → DMEM acceptance, write-enable/data and memory-setup timing.
6. Forwarded branch comparison → redirect control → fetch-PC-register timing.
7. Quantitative timing, path slack and WNS.
8. Reproducible scripts, complete commands, reports and violation dispositions.

Negative slack requires a reviewed change proposal. It does not authorize an extra pipeline register, silent retiming or a changed EX transaction edge.

No replacement calendar deadline or implementation schedule is established here.

### Recorded verification scope

The technology-independent milestone was conditionally accepted on November 5, 2026.

D01 selector closure, ARCH-M17-D02 and V01–V27 are accepted within their documented scopes. F01 is CLOSED under approved-warning inventory acceptance. F03 is CLOSED. FINAL-B01 is APPROVED, and FINAL-B02 documentation reconciliation is IMPLEMENTED.

The recorded later regression contains 414 positive case/configuration checks and ten expected-negative checks. These are bounded executed checks, not unique-program counts or exhaustive proof.

Generic synthesis succeeded in both trace configurations. It does not establish physical RAM inference, device utilization, netlist equivalence, hardware behavior or timing closure.

The recorded 68/65 generic cell-step path lengths are topology observations, not delay, slack or Fmax.

## 17. Design rationale and provenance

| Design choice | Rationale and continuing cost |
|---|---|
| Separate instruction/data interfaces | Avoid IF/data-port arbitration; require separate logical ports. |
| Registered synchronous reads | Predictable fixed latency; require output hold. |
| EX load initiation | One-bubble immediate consumer; longer EX timing path. |
| Unified EX load/store acceptance | One transaction per edge; requires early store-safety reasoning. |
| Restricted fail-stop EEI | Simpler than privileged traps or deferred-store machinery; excludes late faults and MMIO. |
| ID handling of fetch tokens | Avoid irrevocable speculative faults and later record replacement. |
| One immutable terminal record | Avoid age-tagged replacement machinery. |
| Fixed 16 KiB regions | Simple legality checks; limited configurability. |
| Jump link in `ex_result` | Avoid another WB source and packet field. |
| EX branch resolution | Centralize forwarded comparisons; incur two redirect bubbles. |

The technical baseline is ARCH-001 Revision C with A01/A01-OWN/A02/A03, ARCH-M17-D02, ARCH-M17-A01-SYN and FINAL-B01. Historical RW, REVA, REV and RB identifiers remain traceability records rather than independent verification results.

The original architecture records Claude-assisted reviews, and project records document AI-assisted verification. This document makes no exclusive human or AI implementation-authorship claim.

Reviewer-reported older interfaces included `dmem_en` versus current `dmem_re`, older write-mask naming, instruction-misalignment cause `1` versus current `0x9`, and ECALL cause `5` versus current `0x4`. These are reported comparisons, not a verified diff of an unavailable older source. Additional historical assignments must not be guessed.

The normative ISA reference is *RV32I Base Integer Instruction Set, Version 2.1*. This document preserves the project's restricted EEI and does not claim external ISA certification.

### Preserved source identities

These hashes identify preserved originals, not replacement documents. Original specification, decision-register and frozen-contract references are restricted historical identifiers, not delivered files:

| Original record/source | SHA-256 |
|---|---|
| `docs/ARCHITECTURE.md` | `529d37628f2d87dc8f9b030d7e2182122e29d25ed416e2ce04a21c984e3b8b98` |
| `docs/DECISIONS.md` at documentation implementation | `49c5582e8fd12dec6d3706ee439c3ba88b786a5591c016f8b858a217030c4d13` |
| Frozen F01 `approved_manifest.json` | `498f80e8205c1b4a380292d3142d00586a9291768bfb82c5f0e69e1fcc95f0e8` |
| Post-R01 `rtl/memory/load_formatter.sv` | `562491ee4affd64ee76f593b753144bfc2812b59bc3c55f3fcc57731711ce800` |
| Post-T01 `tb/integration/tb_rv32i_core_top.sv` | `d293418f0d68adc9898495a0a3d439d5059a2ae19cba981672d67998cf8b27fe` |

The frozen F01 manifest records all 17 accepted RTL hashes and the integration-bench hash. R01 adds only a terminal LF to `load_formatter.sv`; T01 changes only the integration bench's error-count condition to an explicit nonzero comparison.

### Technical verification references

| Evidence group | Evidence | Manifest | Validation |
|---|---|---|---|
| Functional — PARTIAL | [Evidence](verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_EVIDENCE.json) | [Manifest](verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_MANIFEST.json) | [Validation](verification/module17/final_campaign/TECHNICAL_FUNCTIONAL_VALIDATION.json) |
| Historical lint — validated | [Evidence](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_EVIDENCE.json) | [Manifest](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_MANIFEST.json) | [Validation](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_VALIDATION.json) |
| Implementation/integrity — validated | [Evidence](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_EVIDENCE.json) | [Manifest](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_MANIFEST.json) | [Validation](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_VALIDATION.json) |

The PRE-PUSH-008C functional derivative is **PARTIAL**: five legacy-fingerprint entries refer to two unavailable older RTL identities (`rtl/core/pc_fetch.sv` and `rtl/core/pipeline_regs.sv`). The 18 accepted design/bench hashes and all 80 replay records reconcile. Those missing older bytes are historical dependencies, not inputs required by the current-source procedures below.

PRE-PUSH-008F separately qualified the portable technical lint procedure: four matching configurations and 46 controls passing twice. This is new qualification, not a rerun or replacement of historical F01 acceptance.

[Portable source and lint contract](verification/module17/lint_closure/fail_closed_runner/portable_manifest.json); [reproduction guide](REPRODUCING.md); [technical decisions](TECHNICAL_DECISIONS.md); [provenance](PROVENANCE.md).

Original `docs/ARCHITECTURE.md`, `docs/DECISIONS.md` and frozen F01 records remain restricted historical citations. Their identities above are preserved; they are not ordinary delivery links. The technical derivatives retain D01/D02, V01–V27, accepted-fetch reset, assertion, synthesis, timing and source-maintenance traceability. They do not rewrite the originals or establish physical timing signoff.
