# Fault-Tolerant Dilithium

Hardware sources for a Bachelor's thesis on Triple Modular Redundancy (TMR)
applied to a CRYSTALS-Dilithium digital signature hardware implementation, to
measure the resulting power, performance, and area (PPA) overhead.

Base Dilithium RTL, TMR flip-flop wrappers, and fault-counter logic are
combined and transformed by the Python scripts in `scripts/` into several
generated netlist variants (`netlists/`), each protecting a different subset
of registers with TMR. `rtl_tb/` holds the testbenches used to verify these
netlists against Known Answer Test (KAT) vectors in `KAT/`.

## Structure

- `flipflops/`: TMR flip-flop primitives (`fdre.v`, `fdse.v`), the sliding-window
  `fault_counter.v`, and their unit testbenches.
- `KAT/`: Known Answer Test vectors used to verify signing operations.
- `netlists/`: generated netlists, one per protection strategy:
  - `base_design.v`: unmodified baseline, no TMR.
  - `full_security_design.v`: every flip-flop replaced with TMR.
  - `output_path_design.v`: TMR on output-path modules only.
  - `output_path_control_state_design.v`: TMR on output-path + control-state.
  - `control_state_design.v`: TMR on control-state registers only.
- `rtl_tb/`: testbenches (KAT verification, SAIF capture, fault injection).
- `scripts/`: generator scripts that produce each `netlists/*.v` variant from
  `base_design.v` by pattern-matching and replacing `FDRE`/`FDSE` cells.

## Notes

- The testbenches in `rtl_tb/` reference KAT vectors via an absolute path
  (`C:/Jacky/bachely_jacky/KAT/...`). Find-replace this prefix with the local
  path to `KAT/` before simulating on another machine.

- The generator scripts in `scripts/` resolve paths relative to their own
  location (`__file__`), so they work from any working directory as long as
  the repo layout above is preserved.
