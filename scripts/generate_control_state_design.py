import os
import re

REPO_ROOT    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NETLISTS_DIR = os.path.join(REPO_ROOT, "netlists")

input_file  = os.path.join(NETLISTS_DIR, "base_design.v")
output_file = os.path.join(NETLISTS_DIR, "control_state_design.v")

RST_IBUF_DRIVER = (
    "  IBUF rst_IBUF_inst\n"
    "       (.I(rst),\n"
    "        .O(rst_IBUF));"
)
RST_IBUF_DRIVER_WIRED = (
    "  wire rst_IBUF_direct;\n"
    "  IBUF rst_IBUF_inst\n"
    "       (.I(rst),\n"
    "        .O(rst_IBUF_direct));\n"
    "  assign rst_IBUF = rst_IBUF_direct | fault_ctr_trigger_rst;"
)


def wire_trigger_rst_to_reset(content):
    n = content.count(RST_IBUF_DRIVER)
    if n != 1:
        raise RuntimeError(
            f"expected exactly one rst_IBUF driver in combined_top, found {n}; "
            "netlist structure changed, update RST_IBUF_DRIVER before proceeding"
        )
    return content.replace(RST_IBUF_DRIVER, RST_IBUF_DRIVER_WIRED, 1)

# Top-level control state only (no output-path modules)
TARGET_MODULES = {
    'combined_top',
}

with open(input_file, "r") as f:
    lines = f.read().split('\n')

output_lines = []

in_target_module      = False
in_trm_instance       = False
current_fault_wire    = None
fault_wires_in_module = []
clock_wire_in_module  = None
global_fault_idx      = 0

TRM_TYPES = re.compile(r'\s+trm_fd(re|se|ce|pe)\s+#\(')

for line in lines:
    stripped = line.strip()

    # Module boundary: reset per-module state
    m_decl = re.match(r'^module\s+(\w+)', line)
    if m_decl:
        in_target_module      = m_decl.group(1) in TARGET_MODULES
        fault_wires_in_module = []
        clock_wire_in_module  = None
        in_trm_instance       = False

    # Replace FDRE/FDSE only inside target modules
    if in_target_module:
        line    = re.sub(r'\bFDRE\b', 'trm_fdre', line)
        line    = re.sub(r'\bFDSE\b', 'trm_fdse', line)
        stripped = line.strip()

    # Detect start of a trm_* instance
    if TRM_TYPES.match(line):
        in_trm_instance    = True
        current_fault_wire = f'fault_wire_{global_fault_idx}'
        global_fault_idx  += 1
        fault_wires_in_module.append(current_fault_wire)

    # Capture clock wire from .C(...) on the first occurrence
    if in_trm_instance and clock_wire_in_module is None:
        m = re.search(r'\.C\(([^)]+)\)', line)
        if m:
            clock_wire_in_module = m.group(1).strip()

    # Close trm instance: insert .fault(...) before the final ));
    if in_trm_instance and stripped.endswith('));'):
        pos  = line.rindex('));')
        line = line[:pos + 1] + f',\n        .fault({current_fault_wire}));'
        in_trm_instance    = False
        current_fault_wire = None

    # Before endmodule: inject fault wires + counter (target modules only)
    if stripped == 'endmodule' and in_target_module and fault_wires_in_module:
        clk = clock_wire_in_module or 'clk_IBUF_BUFG'

        for w in fault_wires_in_module:
            output_lines.append(f'  wire {w};')

        any_fault_expr = ' | '.join(fault_wires_in_module)
        output_lines.append(f'  (* KEEP = "true" *) wire any_fault = {any_fault_expr};')
        output_lines.append(f'  (* KEEP = "true" *) wire [31:0] fault_ctr_count;')
        output_lines.append(f'  wire fault_ctr_trigger_rst;')
        output_lines.append(f'  (* DONT_TOUCH = "true" *) fault_counter #(.WIDTH(32), .THR_100(10)) fault_ctr_inst (')
        output_lines.append(f"    .clk({clk}),")
        output_lines.append(f"    .rst(1'b0),")
        output_lines.append(f'    .fault(any_fault),')
        output_lines.append(f'    .count(fault_ctr_count),')
        output_lines.append(f'    .trigger_rst(fault_ctr_trigger_rst)')
        output_lines.append(f'  );')

        fault_wires_in_module = []
        clock_wire_in_module  = None

    output_lines.append(line)

final_content = wire_trigger_rst_to_reset('\n'.join(output_lines))

with open(output_file, "w") as f:
    f.write(final_content)

print(f"Done! {global_fault_idx} fault wires generated.")
print(f"Modules protected: {sorted(TARGET_MODULES)}")
print("combined_top's fault_ctr_trigger_rst wired into rst_IBUF (genuine reset on excess fault rate).")
print(f"Output written to: {output_file}")
