"""
Shared library for the single-design-wide-fault-counter architecture

This module parses a Verilog netlist's actual module/instance hierarchy and generates the wiring needed to thread every
protected module's own fault signal up to one shared fault_counter at the
design root, replacing the previous per-module fault_counter injection.

Used by generate_full_security.py, generate_output_path_design.py, and
generate_output_path_control_state_design.py. generate_control_state_design.py
is unaffected and is not touched.
"""

import re

FF_RE = re.compile(r'\bFD(RE|SE)\b')
MODULE_DECL_RE = re.compile(r'^module\s+(\w+)\b')
INST_LINE_RE = re.compile(r'^(\s+)(\w+)\s+(\\?\S+)\s*\(?\s*$')
TRM_TYPES = re.compile(r'\s+trm_fd(re|se|ce|pe)\s+#\(')


def parse_hierarchy(lines):
    """Discover every module declaration and every real (non-primitive)
    instantiation edge in a flat list of Verilog source lines.

    Returns (modules, children_of, parent_of):
      modules[name]      = (start_idx, end_idx)  0-based, inclusive of the
                            'module NAME' and 'endmodule' lines themselves.
      children_of[name]  = [{"type", "instance", "line"}, ...] (line is 1-based)
      parent_of[type]     = {"parent", "instance", "line"}

    Raises if any module type is instantiated more than once (this
    netlist's modules are Vivado-uniquified per instantiation site, so
    that should never happen; if it ever does, this architecture's
    one-parent-per-module assumption needs revisiting before proceeding).
    """
    n = len(lines)
    modules = {}
    i = 0
    while i < n:
        m = MODULE_DECL_RE.match(lines[i])
        if m:
            name = m.group(1)
            start = i
            j = i + 1
            while j < n and lines[j].rstrip('\n') != 'endmodule':
                j += 1
            if j >= n:
                raise RuntimeError(f"module {name} (line {i+1}): no endmodule found")
            modules[name] = (start, j)
            i = j + 1
        else:
            i += 1

    known = set(modules.keys())
    children_of = {name: [] for name in modules}
    parent_of = {}

    for name, (start, end) in modules.items():
        for k in range(start + 1, end):
            line = lines[k].rstrip('\n')
            if not line.strip():
                continue
            mm = INST_LINE_RE.match(line)
            if not mm:
                continue
            typ, inst = mm.group(2), mm.group(3)
            if typ in known and typ != name:
                children_of[name].append({"type": typ, "instance": inst, "line": k + 1})
                if typ in parent_of:
                    raise RuntimeError(
                        f"module {typ} instantiated more than once "
                        f"({parent_of[typ]} and parent {name} line {k+1}); "
                        "single-counter threading assumes a strict tree"
                    )
                parent_of[typ] = {"parent": name, "instance": inst, "line": k + 1}

    return modules, children_of, parent_of


def compute_needs_threading(root, children_of, own_fault_set):
    """DFS from root: needs[name] is True if name itself has its own fault
    signal (name in own_fault_set) or any descendant does."""
    needs = {}

    def dfs(name):
        result = name in own_fault_set
        for kid in children_of.get(name, []):
            if dfs(kid["type"]):
                result = True
        needs[name] = result
        return result

    dfs(root)
    return needs


def _find_header_close(out, start, end):
    for k in range(start + 1, end):
        if out[k].rstrip('\n').endswith(');'):
            return k
    raise RuntimeError(f"no header-closing ');' line found in range {start+1}-{end+1}")


def _add_output_port(out, modules, name, port_name):
    start, end = modules[name]
    k = _find_header_close(out, start, end)
    body = out[k].rstrip('\n')
    prefix = body[:-2]  # drop the trailing ');'
    out[k] = prefix + f",\n    {port_name});\n  output {port_name};\n"


def _find_close_paren(out, start_idx0):
    k = start_idx0
    while k < len(out):
        if '));' in out[k]:
            return k
        k += 1
    raise RuntimeError(f"no closing )); found starting at line {start_idx0+1}")


def _insert_port_connection(out, close_idx, port_name, wire_name):
    line = out[close_idx]
    pos = line.rindex('));')
    out[close_idx] = line[:pos + 1] + f',\n        .{port_name}({wire_name}));\n'


def generate_single_counter_netlist(content, target_modules=None, root='combined_top', thr_100=10):
    """Transform base_design.v-style content into a single-shared-counter
    TMR netlist.

    target_modules: set of module type names whose FDRE/FDSE get replaced
      with trm_fdre/trm_fdse. If None, every module containing at least one
      FDRE/FDSE is targeted (the full_security_design.v case).

    Returns the transformed content (a single string).
    """
    lines = content.splitlines(keepends=True)

    modules, children_of, parent_of = parse_hierarchy(lines)

    if target_modules is None:
        target_modules = {
            name for name, (s, e) in modules.items()
            if any(FF_RE.search(l) for l in lines[s:e + 1])
        }

    out = list(lines)

    fault_wires_in_module = {}
    clock_wire_in_module = {}

    cur_module = None
    in_target_module = False
    in_trm_instance = False
    current_fault_wire = None
    fw_this_module = []
    clk_this_module = None
    global_fault_idx = 0

    for idx in range(len(out)):
        line = out[idx]
        m_decl = MODULE_DECL_RE.match(line)
        if m_decl:
            cur_module = m_decl.group(1)
            in_target_module = cur_module in target_modules
            fw_this_module = []
            clk_this_module = None
            in_trm_instance = False

        if in_target_module:
            new_line = re.sub(r'\bFDRE\b', 'trm_fdre', line)
            new_line = re.sub(r'\bFDSE\b', 'trm_fdse', new_line)
            if new_line != line:
                out[idx] = new_line
                line = new_line

        stripped = line.strip()

        if TRM_TYPES.match(line):
            in_trm_instance = True
            current_fault_wire = f'fault_wire_{global_fault_idx}'
            global_fault_idx += 1
            fw_this_module.append(current_fault_wire)

        if in_trm_instance and clk_this_module is None:
            mclk = re.search(r'\.C\(([^)]+)\)', line)
            if mclk:
                clk_this_module = mclk.group(1).strip()

        if in_trm_instance and stripped.endswith('));'):
            pos = line.rindex('));')
            out[idx] = line[:pos + 1] + f',\n        .fault({current_fault_wire}));\n'
            in_trm_instance = False
            current_fault_wire = None

        if stripped == 'endmodule' and cur_module in target_modules and fw_this_module:
            fault_wires_in_module[cur_module] = list(fw_this_module)
            clock_wire_in_module[cur_module] = clk_this_module or 'clk_IBUF_BUFG'

    own_fault_set = set(fault_wires_in_module.keys())
    needs = compute_needs_threading(root, children_of, own_fault_set)

    if not needs.get(root):
        raise RuntimeError(
            "no protected flip-flops found anywhere under the design root; "
            "nothing to count"
        )

    for name, ok in needs.items():
        if not ok or name == root:
            continue
        info = parent_of.get(name)
        if info is None:
            raise RuntimeError(f"module {name} needs threading but has no parent recorded")
        close_idx = _find_close_paren(out, info["line"] - 1)
        _insert_port_connection(out, close_idx, 'module_fault', f'mf_{name}')
        _add_output_port(out, modules, name, 'module_fault')

    for name, ok in needs.items():
        if not ok:
            continue
        terms = list(fault_wires_in_module.get(name, []))
        wire_decls = [f'  wire {w};' for w in fault_wires_in_module.get(name, [])]
        for kid in children_of.get(name, []):
            ctype = kid['type']
            if needs.get(ctype):
                wname = f'mf_{ctype}'
                terms.append(wname)
                wire_decls.append(f'  wire {wname};')

        expr = ' | '.join(terms)
        start, end = modules[name]

        if name == root:
            clk = clock_wire_in_module.get(name, 'clk_IBUF_BUFG')
            insertion = wire_decls + [
                f'  (* KEEP = "true" *) wire design_any_fault = {expr};',
                f'  (* KEEP = "true" *) wire [31:0] fault_ctr_count;',
                f'  wire fault_ctr_trigger_rst;',
                f'  (* DONT_TOUCH = "true" *) fault_counter #(.WIDTH(32), .THR_100({thr_100})) fault_ctr_inst (',
                f'    .clk({clk}),',
                f"    .rst(1'b0),",
                f'    .fault(design_any_fault),',
                f'    .count(fault_ctr_count),',
                f'    .trigger_rst(fault_ctr_trigger_rst)',
                f'  );',
            ]
        else:
            insertion = wire_decls + [
                f'  (* KEEP = "true" *) assign module_fault = {expr};',
            ]

        out[end] = '\n'.join(insertion) + '\n' + out[end]

    return ''.join(out), global_fault_idx, len(own_fault_set)


def wire_trigger_rst_to_reset(content):
    """Wire the single shared fault_ctr_trigger_rst (now always produced at
    the root, combined_top) into rst_IBUF, same technique as every prior
    per-module-counter generator script used."""
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
    n = content.count(RST_IBUF_DRIVER)
    if n != 1:
        raise RuntimeError(
            f"expected exactly one rst_IBUF driver in combined_top, found {n}; "
            "netlist structure changed, update RST_IBUF_DRIVER before proceeding"
        )
    return content.replace(RST_IBUF_DRIVER, RST_IBUF_DRIVER_WIRED, 1)
