# 8-bit ALU — Verilog HDL

A fully structural 8-bit Arithmetic Logic Unit implemented in Verilog HDL, simulated with ModelSim. Designed as part of the *Calculatoare Numerice* coursework at Universitatea Politehnica Timișoara.

## Operations

| `op[1:0]` | Operation | Algorithm |
|-----------|-----------|-----------|
| `00` | Addition | Ripple-carry adder |
| `01` | Subtraction | Two's complement |
| `10` | Multiplication | **Booth Radix-4** |
| `11` | Division | **Non-Restoring Division** |

## Output Format

| Operation | `result[15:0]` |
|-----------|----------------|
| ADD / SUB | Sign-extended 8-bit result in `[7:0]`, `[15:8]` = sign extension |
| MUL | Full 16-bit signed product |
| DIV | `[15:8]` = remainder, `[7:0]` = quotient |

## Flags (ADD/SUB only)

- `flag_z` — Zero
- `flag_n` — Negative
- `flag_v` — Overflow
- `flag_c` — Carry

## Module Structure

```
alu_top.v           — Top-level structural integration
├── full_adder.v    — 1-bit full adder primitive
├── adder_sub.v     — N-bit parameterized adder/subtractor
├── booth_r4_mult.v — Signed multiplier (Booth Radix-4)
├── nr_divider.v    — Signed divider (Non-Restoring)
└── control_unit.v  — FSM-based operation sequencer
```

## Features

- **Clocked design** with synchronous reset and `start`/`done` handshake
- **div_by_zero** flag for division error detection
- **Flag register** latched on result valid for ADD/SUB
- Fully modular — each arithmetic unit is independently instantiated

## Simulation

Designed and simulated using **ModelSim (VSIM)**. Testbench: `alu_tb.v`. Waveform output: `alu_tb.vcd`.

To run simulation in ModelSim:
```tcl
vlog alu_top.v alu_tb.v
vsim alu_tb
run -all
```

## Tools

- **HDL:** Verilog (IEEE 1364-2001)
- **Simulator:** ModelSim / VSIM
- **Target:** Quartus-compatible (Intel FPGA)
