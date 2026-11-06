# Technical Decisions

This document explains the main design choices in the RV32I processor. Decision IDs connect the explanations to preserved technical records.

The processor behavior is described in `TECHNICAL_ARCHITECTURE.md`. This summary does not replace the original specification, historical decisions or verification evidence.

## 1. Separate instruction and data interfaces — D01

A shared memory port would require arbitration between instruction fetch and data access.

The processor instead exposes separate instruction and data interfaces. Fetch can proceed alongside an older instruction’s data transaction without structural port contention.

The integration environment supplies separate synchronous RAM modules. This choice does not introduce caches, independent clock domains or variable-latency interfaces.

**Limitation:** connected memories must satisfy the specified latency and output-hold contracts.

## 2. Registered synchronous memory reads — D02

Combinational and variable-latency memories lead to different pipeline timing.

The design uses fixed-latency synchronous reads. A request is accepted at a rising edge, and the registered output becomes available during the following cycle. The output holds when its read enable is low.

This gives the pipeline a defined relationship between request acceptance and data availability.

**Limitation:** a target memory primitive must preserve that behavior. If disabled reads do not hold the output, an explicit buffer must preserve the existing contract.

## 3. Initiate loads in EX — D02-T1

Starting a synchronous read only after entering MEM would delay the load result and complicate the immediate-consumer schedule.

The processor presents the effective address and accepts the read at the EX-ending edge. MEM then receives the registered word, formats it and captures the selected result into MEM/WB.

An immediate load consumer receives that registered value through MEM/WB forwarding after exactly one bubble. Independent instructions do not incur a routine read-response hold.

**Limitation:** address generation and legality checking must meet the memory’s setup requirements at the EX-ending edge.

## 4. Accept loads and stores at the same pipeline boundary — D03

Separate load/store acceptance stages would require additional arbitration and transaction bookkeeping.

Both operations are accepted at the EX-ending edge on one data-memory port. At most one transaction is accepted per edge; read and write cannot assert together. A store is not performed again in MEM.

There is no general EX hold, so an accepted instruction is not replayed across another acceptance edge. An `already_issued` flag is unnecessary.

**Limitation:** early, irreversible stores rely on the restricted fault model described below.

## 5. Restricted execution environment and ordered fail-stop — D04

A processor that allows late faults, interrupts or MMIO effects needs more machinery to preserve precise state around early stores.

This design excludes those conditions. Alignment and access errors are detected before a data transaction is accepted. Legal accepted transactions do not later report errors.

An EX fault takes priority over a legal redirect, which takes priority over an ID terminal event. One immutable fault record is captured, younger work is discarded and older instructions drain before HALTED.

An older legal EX store still commits when a younger ID instruction terminates. A faulting EX store does not commit.

**Limitation:** this is not a privileged trap implementation. Interrupts, CSR-based handlers, MMIO and late-fault memory systems are outside the baseline.

## 6. Detect forbidden nonready forwarding — A01 and A01-OWN

A matching EX/MEM load must not be bypassed in favor of an older MEM/WB value. That would select stale data.

Correct load-use control prevents this state during legal execution. If it nevertheless occurs, the combinational forwarding unit asserts `fwd_nonready_error`. A separate sticky register in `rv32i_core_top` captures the error and retains it until synchronous reset.

The diagnostic does not stall, replay, issue memory traffic or raise an EEI fault. Verification assertions observe the violation.

**Limitation:** this detects an implementation error; it does not define a recovery result for the affected instruction.

## 7. Keep IF/ID metadata with one owner — A02

A synchronous instruction word and its PC/valid/fault metadata must describe the same accepted fetch slot.

`imem_sync` owns the registered instruction word. `pipeline_regs` exclusively owns registered IF/ID PC, validity and fetch-fault metadata. `pc_fetch` owns the fetch PC and combinational request/token logic.

A legal read and its metadata are accepted at the same edge. An out-of-range candidate produces a valid token without reading RAM.

This avoids duplicate registers, drivers and unaccounted pipeline cycles.

**Limitation:** instruction output and metadata must remain aligned during holds, kills and reset.

## 8. Qualify redirects before updating the fetch PC — A03

A raw branch decision must not redirect fetch when the processor is draining or when an older-priority EX fault wins.

`branch_unit` produces the raw legal redirect and target. `fault_ctrl` qualifies it with RUN state, valid EX instruction and absence of an overriding EX fault. `pc_fetch` consumes only the qualified redirect.

Reset has highest PC priority, followed by an eligible redirect, sequential advancement and hold. DRAIN/HALTED accept neither new fetch slots nor redirects.

**Effect:** the existing schedule remains unchanged: exactly two EX bubbles follow a legal redirect.

## 9. Preserve implemented register-file and forwarding interfaces — ARCH-M17-D02

The implemented interfaces differ from the original canonical dictionary without changing the required behavior.

The accepted mapping retains:

- `reg_file`, with `rs1_addr`, `rs2_addr`, `rd_addr`, `rd_data` and `rd_we`.
- Asynchronous register reads and synchronous writes.
- External WB-to-ID bypass.
- A combinational, selector-only `forward_unit`.
- Forwarding data muxes in the top level.
- An explicit readiness input distinguishing EX results from nonready loads.

Verification addresses bypass connectivity, readiness, forwarding muxes, store-data forwarding and the diagnostic lifecycle.

**Limitation:** interface-name reconciliation is not permission to change latency, forwarding priority or architectural semantics.

## 10. Correct the constant-4 operand selector — Module 17 D01

The EX operand-B mux must implement its defined constant-4 selection.

The resolved implementation selects `32'd4` for `op_b_sel=2'b10`. Focused evidence exercises the actual mux and preserves the selector checks. Later wrappers also confirm the core’s actual trace parameter in each build.

This finding is separate from architectural D01, which concerns memory interfaces.

**Limitation:** testing defensive behavior for the reserved selector does not make that behavior a new architectural instruction requirement.

## 11. Permit removal of an unconsumed diagnostic register — ARCH-M17-A01-SYN

Generic synthesis removes sticky state that has no architectural consumer. That observation initially required clarification.

The accepted disposition requires correct diagnostic generation, capture, retention, reset and architectural noninterference in RTL. It does not require physical retention of an unconsumed sticky register after synthesis.

No preservation attribute, new output or production RTL change is required.

**Limitation:** accepted RTL diagnostic behavior does not imply that the optimized implementation exposes the diagnostic physically.

## 12. Defer technology-specific timing qualification — FINAL-B01

Generic synthesis and logic-depth reports do not establish physical timing.

The original two timing shells were required before full integration. That deadline was missed and remains part of the record. FINAL-B01 defers the work to the technology-specific phase, before timing acceptance for that implementation.

F05 remains **PARTIAL / DEFERRED**. Required work includes target selection, constraints, memory inference, both critical-path shells, quantitative slack/WNS, reproducible reports and violation dispositions.

The provisional 20 MHz/50 ns goal is not measured performance.

**Limitation:** negative slack does not authorize another pipeline stage, silent retiming or a changed EX memory-acceptance edge.

## 13. Reconcile documentation without rewriting history — FINAL-B02

Earlier reports retain execution-time labels such as pending compatibility or failed native lint. Later dispositions must be understandable without changing those original records.

FINAL-B02 added current technical dispositions and timing obligations. It records F01 CLOSED, F03 CLOSED and the continuing F05 deferral while preserving historical reports.

**Limitation:** documentation reconciliation does not requalify the frozen F01 contract. Its original document fingerprints remain unchanged. The separately qualified portable technical contract does not require or rebaseline those documents.

PRE-PUSH-008F separately qualified the portable technical lint procedure: four matching configurations and 46 controls passing twice. This is new qualification, not a rerun or replacement of historical F01 acceptance.

See [implementation and integrity evidence](verification/module17/final_campaign/TECHNICAL_IMPLEMENTATION_EVIDENCE.json) for F03/FINAL-B01/R01/T01, [historical and portable lint validation](verification/module17/lint_closure/fail_closed_runner/TECHNICAL_LINT_VALIDATION.json), and [verification status](VERIFICATION_STATUS.md) for the functional derivative’s PARTIAL qualification.
