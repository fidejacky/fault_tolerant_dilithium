# Flip-Flop Testbenches

All testbenches live in `flipflops/` alongside the RTL they test.
Each one targets a single module, runs a short self-checking simulation, and prints PASS/FAIL lines to the console.

---

## How to run in Vivado

1. Add the RTL source and the testbench file to the project's simulation sources.
2. Set the testbench module as the simulation top.
3. Click **Run Simulation → Run Behavioral Simulation**.
4. Check the **Tcl Console** for the printed results.

---

## `fdre_tb.v`: `trm_fdre` (D flip-flop with synchronous reset)

**DUT:** `trm_fdre`, TMR-secured version of the Xilinx `FDRE` primitive.

| Scenario | What happens |
| -------- | ------------ |
| Normal toggle | `D` toggles on every falling edge; `Q` follows after the next rising edge |
| CE disabled | `CE=0` for 100 ns - `Q` holds its value even though `D` changes |
| Reset | `R=1` for two windows - `Q` is forced to 0 regardless of `D` |
| Fault injection | `dut.q_a` is forced stuck-at-1 for 100 ns, then stuck-at-0 for 100 ns |

The `fault` output goes high whenever the three internal copies disagree.
A `fault_counter` instance (THR\_100=10) drives `trigger_rst`.
`$display` lines report `trigger_rst` before, during, and after injection.

**Retargeted (2026-08-06):** like `fault_counter_tb.v`, this testbench (and
`fdce_tb.v`/`fdpe_tb.v`/`fdse_tb.v` below) originally instantiated
`fault_counter` with the rejected popcount design's `N=1, THR_CYCLE=1`
parameters; those parameters no longer exist on the current module and were
dropped, `THR_100=10` carries over unchanged.

Clock period: **10 ns** (`always #5`). Simulation ends at **5000 ns**.

---

## `fdce_tb.v`: `trm_fdce` (D flip-flop with asynchronous clear)

**DUT:** `trm_fdce`, TMR-secured version of the Xilinx `FDCE` primitive.

| Scenario | What happens |
| -------- | ------------ |
| Normal toggle | `D` toggles on every falling edge |
| CE disabled | `CE=0` for 100 ns - `Q` holds |
| Asynchronous clear | `CLR=1` immediately forces `Q` to 0 (does not wait for clock edge) |
| Fault injection | `dut.q_a` stuck-at-1 then stuck-at-0, each for 100 ns |

Unlike `fdre`, the clear here is **asynchronous**; `Q` responds to `CLR` without waiting for a clock edge.

Clock period: **40 ns** (`always #20`). Simulation ends at **5000 ns**.

---

## `fdpe_tb.v`: `trm_fdpe` (D flip-flop with asynchronous preset)

**DUT:** `trm_fdpe`, TMR-secured version of the Xilinx `FDPE` primitive.

| Scenario | What happens |
| -------- | ------------ |
| Normal toggle | `D` toggles on every falling edge |
| CE disabled | `CE=0` for 100 ns - `Q` holds |
| Asynchronous preset | `PRE=1` immediately forces `Q` to 1 (does not wait for clock edge) |
| Fault injection | `dut.q_a` stuck-at-1 then stuck-at-0, each for 100 ns |

Mirror of `fdce_tb` but with a preset-high instead of a clear-low.

Clock period: **40 ns** (`always #20`). Simulation ends at **5000 ns**.

---

## `fdse_tb.v`: `trm_fdse` (D flip-flop with synchronous set)

**DUT:** `trm_fdse`, TMR-secured version of the Xilinx `FDSE` primitive.

| Scenario | What happens |
| -------- | ------------ |
| Normal toggle | `D` toggles on every falling edge |
| CE disabled | `CE=0` for 100 ns - `Q` holds |
| Synchronous set | `S=1` forces `Q` to 1 on the next rising edge (waits for clock) |
| Fault injection | `dut.q_a` stuck-at-1 then stuck-at-0, each for 100 ns |

Like `fdre` (synchronous control), but sets to 1 instead of clearing to 0.

Clock period: **40 ns** (`always #20`). Simulation ends at **5000 ns**.

---

## `fault_counter_tb.v`: `fault_counter`

**DUT:** `fault_counter` (OR-based, single-bit `fault` input), counts faulty
cycles using a 100-cycle sliding window and triggers a reset when the count
within that window reaches `THR_100`.

Parameters used in this testbench: **WIDTH=32**, **THR\_100=8**.

**Retargeted (2026-08-06):** this testbench previously tested an earlier,
popcount-based version of `fault_counter` (parameters `N`, `THR_CYCLE`, a
multi-bit `fault` bus), documented as the rejected alternative in
`TEXTE/fault_counter_versions.txt`. That version's per-cycle `THR_CYCLE`
check has no equivalent in the current, active `fault_counter.v`: with a
single-bit, OR-reduced `fault` input, a per-cycle count can never exceed 1,
so the old `THR_CYCLE`-based test cases were removed rather than adapted,
not merely reworded, the mechanism they tested no longer exists in this
design. The sliding-window `THR_100` tests carry over directly.

| Test | Scenario | Expected `trigger_rst` |
| ---- | -------- | ---------------------- |
| T1 | 10 idle cycles, no faults | 0 |
| T2 | 3 isolated single-cycle faults, well below THR\_100=8 within the window | 0 |
| T3a | `fault=1` held for 7 cycles (`running_total=7 < 8`) | 0 |
| T3b | `fault=1` held for 8 cycles (`running_total=8 = THR_100`) | 1 |
| T4 | Same as T3, then 108 idle cycles - old faults slide out of window | 0 |
| T5 | Sustained fault triggers reset, then `rst=1` clears `trigger_rst` | 0 after reset |

**How the sliding window works:**
The module keeps a shift register of 100 entries. Every cycle, the oldest entry is evicted and the current `fault` bit is added. Once the running total stays below THR\_100 for long enough that all the counted faults have been evicted, `trigger_rst` de-asserts, which is what T4 verifies.

**Not tested here:** an unknown (`X`) `fault` input, the specific case that
caused the X-propagation bug described in the thesis (see the author's
local project notes, "fault_counter X-propagation bug found and fixed").
This testbench was retargeted for port/parameter compatibility only; it does
not yet cover that scenario.

---

## Fault injection method

All four FF testbenches use Verilog `force` / `release` to inject faults directly onto an internal net of the DUT:

```verilog
force dut.q_a = 1'b1;   // stuck-at-1: one of the three copies is wrong
#100;
force dut.q_a = 1'b0;   // stuck-at-0
#100;
release dut.q_a;         // fault removed
```

This bypasses the flip-flop's clock and data path, simulating a physical fault injection attack (laser, particle hit).
The majority voter in each TMR module still produces a correct `Q` during the injection because 2 out of 3 copies agree.
The `fault` output goes high as soon as the three copies disagree, and `trigger_rst` follows one clock cycle later.
