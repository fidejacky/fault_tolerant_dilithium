import os

from single_counter_lib import generate_single_counter_netlist, wire_trigger_rst_to_reset

REPO_ROOT    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NETLISTS_DIR = os.path.join(REPO_ROOT, "netlists")

input_file  = os.path.join(NETLISTS_DIR, "base_design.v")
output_file = os.path.join(NETLISTS_DIR, "full_security_design.v")

with open(input_file, "r") as f:
    content = f.read()

final_content, n_fault_wires, n_own_fault_modules = generate_single_counter_netlist(
    content, target_modules=None
)
final_content = wire_trigger_rst_to_reset(final_content)

with open(output_file, "w") as f:
    f.write(final_content)

print(f"Done! {n_fault_wires} fault wires generated across {n_own_fault_modules} protected modules.")
print("Single design-wide fault_counter at combined_top, wired into rst_IBUF.")
print(f"Output written to: {output_file}")
