// System-level fault-injection testbench (TO-DO.md #7).
//
// Single-KAT-vector variant of tb_sign_trmff_top.v (like tb_sign_trmff_top_saif.v),
// with one stuck-at fault forced directly onto a real register inside a real
// signing operation, then checks whether the resulting signature still
// matches the KAT vector. Unlike flipflops/fdre_tb.v (which proves the
// majority-vote arithmetic in isolation, already established), this tests
// whether a SPECIFIC target register's TMR wiring is actually integrated
// correctly end-to-end in THIS generated netlist, and whether that
// correctness genuinely reaches the real signature output, not just the
// voter's own logic.
//
// === Configure before each run: edit the `define block directly below ===
//
// TARGET_B/C/D: which register to force (exactly one must be defined).
//   (TARGET_A / REJ_CHECK removed 2026-08-14: not worth running, consistent
//   with tutor feedback #4 scoping REJ_CHECK out of the thesis, see CLAUDE.md.)
//   B = GEN_Y's seed-expansion shift register, DUT.GEN_Y.\SEED_SIPO_reg[384]_srl7
//       (SRL16E in every variant, including full_security_design.v, so
//       PROTECTED never applies to B, see CLAUDE.md's 2026-08-14 addendum)
//   C = the signing-attempt counter, DUT.\ctrfsm1_reg[0]
//       (plain FDRE, lives directly in combined_top's own scope)
//   D = encoder's final output shift register, DUT.ENCODER.\PISO_reg[0]
//       (plain FDRE, last register before dout per TEXTE/targeted_protection.md)
//
// PROTECTED: define if the currently-loaded netlist variant wraps the
//   chosen target in a trm_fdre (forces the internal q_a redundant copy
//   instead of the already-voted Q, which would trivially "fail" the
//   masking test regardless of TMR). Leave undefined for a plain FDRE.
//   Never define this alongside TARGET_B.
//
// COMMON_MODE (added 2026-08-15, TO-DO.md follow-up): only meaningful
//   together with PROTECTED, mutually exclusive with FORCE_LONG. Forces
//   q_a AND q_b (two of the three redundant copies) to the SAME stuck
//   value simultaneously, instead of only q_a, modelling a single physical
//   event (an SEU striking two physically-adjacent configuration cells, a
//   shared clock-glitch or voltage droop, EMI) corrupting more than one
//   copy at once. Currently implemented for TARGET_D only (case 7's
//   precisely-timed `wait(state==UNLOAD_Z)` trigger makes it the cleanest
//   base to reuse; the same pattern would extend to TARGET_C identically
//   if ever wanted). Per flipflops/fdre.v's actual vote3/fault logic:
//   vote3(a,b,c) is a plain majority, so 2-of-3 copies agreeing on a wrong
//   value outvotes the one remaining correct copy regardless of which
//   copy is "right"; fault=(q_a^q_b)|(q_b^q_c) still asserts (q_c
//   disagrees), so fault_counter still sees a disagreement, but only on
//   the same cycle the wrong value is already being voted onto Q, the
//   detection does not prevent the corruption from happening.
//
// FORCE_LONG: undefined = brief force, well under fault_counter's
//   THR_100=10-cycle window, isolates "does this instance's TMR wiring
//   mask a transient glitch" from the reset path entirely.
//   defined = sustained, two-phase force (same stuck-at-1-then-stuck-at-0
//   pattern flipflops/fdre_tb.v already uses) deliberately meant to cross
//   THR_100 and confirm `fault_ctr_trigger_rst` -> `rst_IBUF` actually
//   fires in the real design, not just in the fault_counter unit test.
//   Only meaningful together with PROTECTED (an unprotected register
//   produces no `fault` signal at all, nothing to accumulate).
//
// Planned minimal matrix (5 cases, cases 1-3/TARGET_A dropped 2026-08-14,
// not worth running, see CLAUDE.md Results Log / TO-DO.md #7):
//   4. TARGET_B, (always unprotected) @ full_security_design.v      -> vulnerability
//   5. TARGET_C, PROTECTED            @ control_state_design.v      -> masking
//   6. TARGET_C, (unprotected)        @ base_design.v                -> vulnerability
//   7. TARGET_D, PROTECTED            @ output_path_design.v         -> masking
//   8. TARGET_D, (unprotected)        @ control_state_design.v       -> vulnerability
//   9. TARGET_D, PROTECTED, COMMON_MODE @ output_path_design.v       -> common-mode
//      CONFIRMED CORRUPTED 2026-08-15 (see CLAUDE.md): the initial sweep at
//      offsets 0/80/160/240 ns (relative to `state==UNLOAD_Z`) came back
//      clean, traced to a wrong timing assumption, not register safety, the
//      real first output transfer happens ~83,630 ns after UNLOAD_Z entry,
//      not within a few hundred ns of it as originally assumed. Re-run at
//      the corrected offset (`COMMON_MODE_OFFSET_NS=83600`, the file's
//      current active value) confirmed CORRUPTED: forcing q_a AND q_b
//      together defeats TMR exactly as vote3's majority logic predicts.
//
// Known scope limits, deliberate for a minimal version, not oversights:
//   - Injection timing for B/C is a fixed mid-operation delay (the
//     internal seed-expansion/rejection-sampling compute phase isn't
//     observable from this testbench's own sequencer state), not the
//     verified single most-vulnerable cycle for each register. D instead
//     triggers off this testbench's own UNLOAD_Z transition, since that
//     register's active window IS directly observable here.
//   - FORCE_LONG on TARGET_C (`define TARGET_C` + `PROTECTED` + `FORCE_LONG`,
//     on control_state_design.v / ArtixControlState) revives the dropped
//     TARGET_A reset-mechanism case, retargeted to ctrfsm1 (still in
//     scope, unlike REJ_CHECK): deliberately crosses THR_100 to confirm
//     fault_ctr_trigger_rst -> rst_IBUF fires in the real datapath, not
//     just the fault_counter_tb.v unit test. Watch the console for
//     `DUT.fault_ctr_trigger_rst -> 1`, that's the direct confirmation;
//     what happens to this testbench's own sequencer afterward (likely a
//     TIMEOUT, since a real mid-operation reset desyncs it from DUT by
//     design) is secondary to that one signal actually transitioning.
//   - TARGET_D's force is held for the whole UNLOAD_Z phase (2880 ns / 288
//     cycles), not a brief snapshot, corrected 2026-08-14 after a first
//     attempt at case 8 with only a 2-cycle force came back an
//     inconclusive MASKED (PISO_reg[0] is one bit of a 256-bit shift
//     register serialized over many cycles; a short force can miss every
//     moment that bit is actually read out), see CLAUDE.md.
//   - Every force block uses two phases with explicit literal values
//     (1'b1 then 1'b0), not a single stuck value, corrected 2026-08-14
//     (user caught this): a single stuck-at value only creates an
//     observable fault if it happens to disagree with whatever the
//     correct value would have been for this specific KAT vector, a 50/50
//     coincidence for one bit, independent of and in addition to the
//     timing concern above. An earlier version used `force sig = ~sig;`
//     twice in a row intending to flip back, but the second force reads
//     sig's already-forced value, silently re-forcing the SAME stuck
//     value, a real bug. Total duration per target is unchanged, just
//     split into two equal phases.

// Left at case 5's config after its 2026-08-15/16 definitive re-run
// (MASKED, fully confirmed, see CLAUDE.md). Edit before the next run, same
// discipline TEXTE/settingFaultInjection.md already requires.
`define TARGET_C
`define PROTECTED
`define DECOUPLED_FULLHOLD
// `define COMMON_MODE

// Timing sweep (2026-08-15): case 9's first attempt (offset=0) came back
// MASKED, which per vote3's deterministic majority logic can only mean the
// 8-cycle force window missed PISO_reg[0]'s actual read cycle within its
// ~293 ns (~29-cycle) per-word serialization period, not that the register
// survived a common-mode fault (see CLAUDE.md). This macro shifts the same
// bounded 8-cycle (80 ns) force later relative to `state==UNLOAD_Z`, without
// touching anything else about the test. The window width (80 ns) equals
// the sweep step, so four runs at 0/80/160/240 ns cover one full ~293 ns
// word period back-to-back with no gaps and minimal overlap. Edit ONLY this
// one value between sweep runs.
//
// Swept 0/80/160/240 ns (2026-08-15): all four MASKED, identical cycle
// counts to the clean baseline, still structurally inconclusive (see
// CLAUDE.md's timing-sweep entry for the two live hypotheses: the real
// per-word window may be wider than ~293 ns for the first Z-word
// specifically, or the register's significance may not be confined to one
// recurring per-word moment at all). Left at 240 (last value tried); reset
// to 0 or pick a value beyond 320 ns before the next attempt.
`define COMMON_MODE_OFFSET_NS 83600

`timescale 1ns / 1ps
`define P 10

module tb_sign_trmff_fault_injection_top;
    reg clk = 1, rst = 1, start = 0;

    localparam [2:0] sec_lvl = 2;
    reg [1:0] mode = 2;

    localparam NUM_TV = 1;

    reg valid_i, ready_o;
    wire ready_i, valid_o;
    reg [63:0] data_i;
    wire [63:0] data_o;

    reg tb_enable = 0;

    initial begin
        tb_enable = 0;
        #200;
        tb_enable = 1;
    end

    combined_top DUT (
        clk,
        rst,
        start,
        mode,
        sec_lvl,
        valid_i,
        ready_i,
        data_i,
        valid_o,
        ready_o,
        data_o
    );

    // ---- fault injection ----
    initial begin
        wait (tb_enable == 1);

`ifdef DECOUPLED_FULLHOLD
        // Case 5 definitive re-run, diagnostic-only decoupling (2026-08-15/16):
        // precise read-timing instrumentation for ctrfsm1 was attempted
        // first via static netlist analysis and abandoned as genuinely
        // intractable, not just inconvenient (see the DECOUPLED_FULLHOLD
        // force block below for the full reasoning). This continuously
        // forces DUT.rst_IBUF to track DUT.rst_IBUF_direct only (a
        // Verilog `force` to an expression re-evaluates live, like a
        // continuous assignment, until released), the same OR term
        // `assign rst_IBUF = rst_IBUF_direct | fault_ctr_trigger_rst;`
        // documented in CLAUDE.md's trigger_rst wiring entry, minus the
        // fault_ctr_trigger_rst contribution. This is a diagnostic-only
        // change to THIS run's reset network, not to the characterized
        // design: fault_counter's own internal trigger_rst signal is left
        // completely unforced and still independently monitored below, so
        // the mechanism's own THR_100 evaluation is untouched, only its
        // effect on the datapath's actual reset is suppressed for this one
        // run, specifically so a deliberately long force (below) can span
        // ctrfsm1's entire active window without an unplanned mid-operation
        // reset desyncing this testbench's sequencer from DUT the way the
        // FORCE_LONG reset-mechanism test's force does by design.
        force DUT.rst_IBUF = DUT.rst_IBUF_direct;
`endif

`ifdef TARGET_D
        // PISO_reg is only active during UNLOAD_Z; wait for this
        // testbench's own sequencer to actually reach that state instead
        // of guessing a wall-clock delay.
        wait (state == UNLOAD_Z);
`else
        // Corrected 2026-08-14 (fourth correction, found by systematically
        // re-checking every target/define combination, not just the one
        // that had already failed): the original `#50000` (landing at
        // t=50200 ns) was WRONG in the same way TARGET_D's duration was.
        // `state == UNLOAD_Z` is observed at t=20780 ns (see CLAUDE.md),
        // so `#50000` lands well INTO the output phase, not mid-compute as
        // originally assumed. ctrfsm1/GEN_Y are only relevant during the
        // rejection-sampling loop, before the algorithm ever reaches
        // output, every B/C run so far has likely injected into a phase
        // where these registers no longer matter at all. Reduced to a
        // brief settle delay instead; each target below now manages its
        // own hold duration relative to this same early starting point.
        #300;
`endif

// All force blocks below use TWO phases with EXPLICIT literal values
// (1'b1 then 1'b0), matching flipflops/fdre_tb.v's established pattern,
// not a relative inversion. Reason (2026-08-14, user caught this): a
// single stuck-at value only creates an observable fault if it happens to
// differ from whatever the correct value would have been for this
// specific KAT vector at that moment, a 50/50 coincidence for a single
// bit. An earlier version of this file used `force sig = ~sig;` twice in
// a row, intending to flip back, but the second force reads sig's
// already-forced value, so it silently re-forces the SAME stuck value
// instead of the opposite one, a real bug, not just an imprecise
// duration. Explicit literals sidestep this: whichever of 1'b1/1'b0 the
// correct value happens to be, the OTHER phase is guaranteed to disagree
// with it.

`ifdef TARGET_B
        // Corrected 2026-08-14 (fourth correction): held from right after
        // tb_enable through the ENTIRE compute phase (gated by this
        // testbench's own state reaching UNLOAD_Z, not a guessed
        // duration), same fix as TARGET_D's unprotected branch. No
        // fault_counter/THR_100 ceiling applies (always a plain SRL16E,
        // PROTECTED/FORCE_LONG never apply here), so holding this long has
        // no reset-collision risk. Phase 2 only gets the remaining bounded
        // window since the exact compute duration isn't known in advance
        // to split evenly; phase 1's long hold is the primary coverage
        // here, phase 2 is a secondary check, not symmetric with phase 1.
        $display("[%0t] TARGET_B (always unprotected, sustained, phase 1/2): forcing DUT.GEN_Y.\\SEED_SIPO_reg[384]_srl7 .Q = 1", $time);
        force DUT.GEN_Y.\SEED_SIPO_reg[384]_srl7 .Q = 1'b1;
        wait (state == UNLOAD_Z);
        $display("[%0t] TARGET_B phase 2/2: forcing = 0", $time);
        force DUT.GEN_Y.\SEED_SIPO_reg[384]_srl7 .Q = 1'b0;
        #2000;
        release DUT.GEN_Y.\SEED_SIPO_reg[384]_srl7 .Q;
`endif

`ifdef TARGET_C
  `ifdef PROTECTED
    `ifdef FORCE_LONG
        // Reset-mechanism test (revives the dropped case 3's intent,
        // retargeted from REJ_CHECK to ctrfsm1, 2026-08-14): deliberately
        // meant to cross fault_counter's THR_100=10-cycle window and
        // confirm fault_ctr_trigger_rst -> rst_IBUF actually fires in the
        // real datapath, not just the isolated fault_counter_tb.v unit
        // test. Widened each phase from 100 to 150 ns (15 cycles instead
        // of 10) for a comfortable margin over THR_100 rather than sitting
        // right at the edge, in case ctrfsm1's real value happens to
        // change partway through a phase. Injection timing doesn't need
        // the same precision the masking tests needed: fault_counter only
        // cares whether q_a disagrees with q_b/q_c often enough, not
        // whether anything downstream is actively reading ctrfsm1 at that
        // exact moment, so starting at the shared t=500 ns point (likely
        // still during input loading, when ctrfsm1 sits at its static
        // reset value) is fine, arguably easier to reason about than the
        // masking test's narrower timing window.
        $display("[%0t] TARGET_C (protected, sustained, phase 1/2): forcing DUT.\\ctrfsm1_reg[0] .q_a = 1", $time);
        force DUT.\ctrfsm1_reg[0] .q_a = 1'b1;
        #150;
        $display("[%0t] TARGET_C phase 2/2: forcing = 0", $time);
        force DUT.\ctrfsm1_reg[0] .q_a = 1'b0;
        #150;
        release DUT.\ctrfsm1_reg[0] .q_a;
    `elsif DECOUPLED_FULLHOLD
        // Case 5 definitive re-run (2026-08-15/16). Precise read-timing
        // instrumentation for ctrfsm1 was attempted first (the approach
        // the user asked for) and abandoned as genuinely intractable, not
        // merely inconvenient: ctrfsm1's only top-level consumer
        // connection is GEN_Y's (expandmask_ext's) `E` port, wired to
        // `ctrfsm1_next`, but a full grep of control_state_design.v shows
        // no driver for `ctrfsm1_next` anywhere in the file other than the
        // `ctrfsm1_reg[N]` FDREs' own CE pins; checking `E`'s declared
        // direction inside the expandmask_ext module definition
        // (`output [0:0]E;`) resolves this: E is an OUTPUT of GEN_Y, so
        // GEN_Y drives ctrfsm1_next (some internal "advance" pulse), not
        // the other way around, GEN_Y does not read ctrfsm1's value
        // through this port at all. Separately, GEN_Y's own
        // `\ctrfsm1_reg[0]`/`_0`/`_1` input ports (same literal names as
        // the real top-level ctrfsm1_reg bits) turn out to be an unrelated
        // naming coincidence: at the actual instantiation they connect to
        // `\FSM_sequential_cstate1_reg[N]_rep_n_0` nets, i.e. GEN_Y's own
        // internal FSM state, not combined_top's ctrfsm1 counter. With no
        // RTL-grounded single read cycle identifiable from this flattened
        // netlist (expandmask_ext's own pre-synthesis RTL isn't available
        // in this repo to resolve it semantically), falls back to the
        // alternative the user pre-authorized for exactly this situation:
        // hold q_a forced across ctrfsm1's ENTIRE active window (the full
        // compute phase, gated by this testbench's own observable
        // `state==UNLOAD_Z` transition, the same technique that gave cases
        // 4/6/8 full confidence), with fault_ctr_trigger_rst decoupled from
        // rst_IBUF for this run only (see the DECOUPLED_FULLHOLD force
        // near the top of this block) so the guaranteed THR_100 crossing
        // over that long a hold doesn't desync this testbench's own
        // sequencer with an unplanned mid-operation reset. Two phases with
        // explicit literals, same coincidence-avoidance reasoning as every
        // other force block in this file.
        $display("[%0t] TARGET_C (protected, DECOUPLED full-hold, phase 1/2): forcing DUT.\\ctrfsm1_reg[0] .q_a = 1", $time);
        force DUT.\ctrfsm1_reg[0] .q_a = 1'b1;
        wait (state == UNLOAD_Z);
        $display("[%0t] TARGET_C phase 2/2: forcing = 0", $time);
        force DUT.\ctrfsm1_reg[0] .q_a = 1'b0;
        #1000;
        release DUT.\ctrfsm1_reg[0] .q_a;
    `else
        // Widened from 2 to 8 cycles total (2026-08-14, after the case 8
        // timing lesson), split into two 4-cycle phases: a partial
        // mitigation only, NOT the same fix as TARGET_D's. This target IS
        // protected, so `fault` asserts for as long as the forced value
        // differs from the real one; holding any longer risks crossing
        // fault_counter's THR_100=10-cycle window and triggering
        // trigger_rst, contaminating the masking test with an unplanned
        // reset. 8 cycles total stays safely under that ceiling but still
        // cannot guarantee spanning ctrfsm1's actual read window the way
        // TARGET_D's full-phase hold does, see CLAUDE.md. Injection point
        // corrected 2026-08-14 (fourth correction): the shared trigger
        // above settles at only t=300 ns, fine for B/C-unprotected since
        // they hold continuously through the whole compute phase
        // regardless of when it starts, but too early for this bounded,
        // brief window, likely before all input words even finish loading.
        // Added an extra mid-compute delay here specifically (compute
        // phase is ~20,580 ns end to end per the observed state==UNLOAD_Z
        // timestamp, see CLAUDE.md), still an approximate placement, not a
        // precisely verified single best cycle, same documented limitation
        // as before, just no longer guaranteed wrong (t=50200 ns, past
        // compute entirely, the original bug) nor guaranteed too early
        // (t=500 ns, likely before loading even finishes).
        #10000;
        $display("[%0t] TARGET_C (protected, brief, phase 1/2): forcing DUT.\\ctrfsm1_reg[0] .q_a = 1", $time);
        force DUT.\ctrfsm1_reg[0] .q_a = 1'b1;
        #40;
        $display("[%0t] TARGET_C phase 2/2: forcing = 0", $time);
        force DUT.\ctrfsm1_reg[0] .q_a = 1'b0;
        #40;
        release DUT.\ctrfsm1_reg[0] .q_a;
    `endif
  `else
        // Corrected 2026-08-14 (fourth correction): same fix as TARGET_B,
        // held from the shared t=300 ns starting point through the ENTIRE
        // compute phase (gated by state reaching UNLOAD_Z), not a guessed
        // duration that turned out to land in the output phase instead.
        // No fault_counter/THR_100 ceiling applies here (a plain FDRE
        // produces no `fault` signal), so holding this long has no
        // reset-collision risk.
        $display("[%0t] TARGET_C (unprotected, sustained, phase 1/2): forcing DUT.\\ctrfsm1_reg[0] .Q = 1", $time);
        force DUT.\ctrfsm1_reg[0] .Q = 1'b1;
        wait (state == UNLOAD_Z);
        $display("[%0t] TARGET_C phase 2/2: forcing = 0", $time);
        force DUT.\ctrfsm1_reg[0] .Q = 1'b0;
        #1000;
        release DUT.\ctrfsm1_reg[0] .Q;
  `endif
`endif

`ifdef TARGET_D
  `ifdef PROTECTED
    `ifdef COMMON_MODE
        // Common-mode fault test (2026-08-15): forces q_a AND q_b together
        // instead of only q_a, see the COMMON_MODE header comment above for
        // the mechanism. Same 8-cycle (40+40 ns) bound as the single-copy
        // case below and the same reasoning (fault still asserts here too,
        // same reset-risk ceiling), so a MASKED result carries the same
        // "timing miss, not confirmed-safe" caveat already documented for
        // case 7; a CORRUPTED result is fully decisive regardless of
        // duration, same principle established for cases 5-8 (see
        // CLAUDE.md). `COMMON_MODE_OFFSET_NS` (defined near the top of this
        // file) shifts the start of this window relative to
        // `state==UNLOAD_Z`, for the timing sweep described there; case 9's
        // offset=0 attempt (2026-08-15) came back MASKED, structurally
        // inconclusive, not yet swept further.
        #(`COMMON_MODE_OFFSET_NS);
        $display("[%0t] TARGET_D (protected, COMMON_MODE, offset=%0dns, phase 1/2): forcing DUT.ENCODER.\\PISO_reg[0] .q_a AND .q_b = 1", $time, `COMMON_MODE_OFFSET_NS);
        force DUT.ENCODER.\PISO_reg[0] .q_a = 1'b1;
        force DUT.ENCODER.\PISO_reg[0] .q_b = 1'b1;
        #40;
        $display("[%0t] TARGET_D COMMON_MODE phase 2/2: forcing q_a/q_b = 0", $time);
        force DUT.ENCODER.\PISO_reg[0] .q_a = 1'b0;
        force DUT.ENCODER.\PISO_reg[0] .q_b = 1'b0;
        #40;
        release DUT.ENCODER.\PISO_reg[0] .q_a;
        release DUT.ENCODER.\PISO_reg[0] .q_b;
    `else
        // Case 7 RE-RUN (2026-08-15/16, TO-DO high-priority follow-up):
        // originally triggered right at `state==UNLOAD_Z` (t=20,780 ns)
        // with only an 8-cycle (80 ns) window, which the case-9 common-mode
        // investigation later proved is NOT PISO_reg[0]'s real read window,
        // that window is a ~83,630 ns dead zone before real streaming ever
        // starts (see CLAUDE.md's "Common-mode test confirmed CORRUPTED"
        // entry). Reusing that entry's confirmed offset
        // (COMMON_MODE_OFFSET_NS=83600 ns) makes this window's overlap with
        // the real read cycle a settled, thrice-confirmed fact (the
        // unprotected CALIBRATE_BRIEF sweep, the COMMON_MODE test, and the
        // testbench's own $display-instrumented first-transfer timestamp
        // all independently confirm it), not an assumption, so a MASKED
        // result at this offset is now fully conclusive, not merely
        // suggestive the way the original t=20,780 ns attempt was.
        #(`COMMON_MODE_OFFSET_NS);
        $display("[%0t] TARGET_D (protected, brief, offset=%0dns, phase 1/2): forcing DUT.ENCODER.\\PISO_reg[0] .q_a = 1", $time, `COMMON_MODE_OFFSET_NS);
        force DUT.ENCODER.\PISO_reg[0] .q_a = 1'b1;
        #40;
        $display("[%0t] TARGET_D phase 2/2: forcing = 0", $time);
        force DUT.ENCODER.\PISO_reg[0] .q_a = 1'b0;
        #40;
        release DUT.ENCODER.\PISO_reg[0] .q_a;
    `endif
  `else
    `ifdef CALIBRATE_BRIEF
        // Calibration sweep (2026-08-15, TO-DO #13 follow-up): brief 80 ns
        // (8-cycle) unprotected force at COMMON_MODE_OFFSET_NS, reusing the
        // same offset macro and duration as the common-mode test's sweep.
        // Purpose: the common-mode sweep (offsets 0/80/160/240 ns,
        // PROTECTED, on secure_output_path) came back clean across the
        // board, structurally ambiguous per the vote3 argument. This runs
        // the IDENTICAL windows against the UNPROTECTED register instead
        // (ArtixControlState, where ENCODER/PISO_reg carries no trm_fdre),
        // where there is no reset-risk ceiling and no vote3 ambiguity: a
        // MASKED result here means the real read window is simply
        // somewhere else, ruling in favor of hypothesis (1) in CLAUDE.md's
        // timing-sweep entry; a CORRUPTED result here (contrasted with the
        // clean common-mode sweep at the identical offset) would instead
        // point at something specific to the COMMON_MODE force path itself,
        // worth re-checking. No fault_counter/THR_100 ceiling applies (a
        // plain FDRE produces no `fault` signal), so later calibration
        // sweeps can freely extend past 240 ns with no reset-collision
        // risk, unlike the common-mode test's bounded window.
        #(`COMMON_MODE_OFFSET_NS);
        $display("[%0t] TARGET_D (unprotected, CALIBRATE_BRIEF, offset=%0dns, phase 1/2): forcing DUT.ENCODER.\\PISO_reg[0] .Q = 1", $time, `COMMON_MODE_OFFSET_NS);
        force DUT.ENCODER.\PISO_reg[0] .Q = 1'b1;
        #40;
        $display("[%0t] TARGET_D CALIBRATE_BRIEF phase 2/2: forcing = 0", $time);
        force DUT.ENCODER.\PISO_reg[0] .Q = 1'b0;
        #40;
        release DUT.ENCODER.\PISO_reg[0] .Q;
    `else
        // Corrected 2026-08-14 (second correction): the original 2880 ns
        // (assumed 1 cycle/word) was wrong. Actual timing, computed from
        // real observed timestamps (UNLOAD_Z entered at 20,780 ns, $finish
        // at 109,670 ns, 303 total output words): ~29.3 cycles/word, so
        // the Z-phase alone is ~84,490 ns, not 2880 ns, the original fix
        // covered only ~3.4% of the real window. No fault_counter/THR_100
        // ceiling applies here (a plain FDRE produces no `fault` signal),
        // so this can be extended aggressively with no reset-collision
        // risk: now held for 44,000 ns per phase (88,000 ns total),
        // covering essentially the entire remaining operation up to just
        // before $finish.
        $display("[%0t] TARGET_D (unprotected, sustained, phase 1/2): forcing DUT.ENCODER.\\PISO_reg[0] .Q = 1", $time);
        force DUT.ENCODER.\PISO_reg[0] .Q = 1'b1;
        #44000;
        $display("[%0t] TARGET_D phase 2/2: forcing = 0", $time);
        force DUT.ENCODER.\PISO_reg[0] .Q = 1'b0;
        #44000;
        release DUT.ENCODER.\PISO_reg[0] .Q;
    `endif
  `endif
`endif

        $display("[%0t] fault released", $time);
    end

    // ---- reset-path observability (FORCE_LONG / reset-test cases only) ----
`ifdef FORCE_LONG
    initial begin
        forever begin
            @(DUT.fault_ctr_trigger_rst);
            $display("[%0t] DUT.fault_ctr_trigger_rst -> %0b, DUT.rst_IBUF -> %0b",
                      $time, DUT.fault_ctr_trigger_rst, DUT.rst_IBUF);
        end
    end
`endif
`ifdef DECOUPLED_FULLHOLD
    // Same watcher as FORCE_LONG's, confirming fault_counter's own THR_100
    // logic still asserts trigger_rst internally even though rst_IBUF is
    // forced to ignore it for this run (see the DECOUPLED_FULLHOLD force
    // near the top of the fault-injection initial block).
    initial begin
        forever begin
            @(DUT.fault_ctr_trigger_rst);
            $display("[%0t] DUT.fault_ctr_trigger_rst -> %0b, DUT.rst_IBUF -> %0b (decoupled: rst_IBUF tracks rst_IBUF_direct only)",
                      $time, DUT.fault_ctr_trigger_rst, DUT.rst_IBUF);
        end
    end
`endif

    // ---- KAT-checking sequencer, same as tb_sign_trmff_top_saif.v, plus
    // an explicit mismatch counter and a final verdict line ----
  localparam
    START     = 4'd0,
    LOAD_RHO  = 4'd1,
    LOAD_MLEN = 4'd2,
    LOAD_TR   = 4'd3,
    LOAD_M    = 4'd4,
    LOAD_K    = 4'd5,
    LOAD_S1   = 4'd6,
    LOAD_S2   = 4'd7,
    LOAD_T0   = 4'd8,
    UNLOAD_Z  = 4'd9,
    UNLOAD_H  = 4'd10,
    UNLOAD_C  = 4'd11;

  reg [4:0] state;
  integer ctr, c = 0, start_time;
  integer mismatch_count = 0;

  reg [0:18431] z_2 [NUM_TV-1:0];
  reg [0:671]   h_2 [NUM_TV-1:0];
  reg [0:255]   c_2 [NUM_TV-1:0];

  reg [0:3300*8-1] m_2    [NUM_TV-1:0];
  reg [0:15]       mlen_2 [NUM_TV-1:0];
  reg [0:255]      k_2    [NUM_TV-1:0];
  reg [0:255]      tr_2   [NUM_TV-1:0];
  reg [0:255]      rho_2  [NUM_TV-1:0];
  reg [0:13311]    t0_2   [NUM_TV-1:0];
  reg [0:3071]     s1_2   [NUM_TV-1:0];
  reg [0:3071]     s2_2   [NUM_TV-1:0];

  initial begin
    $readmemh("C:/Jacky/bachely_jacky/KAT/zs_2.txt",   z_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/h_2.txt",    h_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/c_2.txt",    c_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/rho_2.txt",  rho_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/m_2.txt",    m_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/mlen_2.txt", mlen_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/k_2.txt",    k_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/tr_2.txt",   tr_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/t0_2.txt",   t0_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/s1_2.txt",   s1_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/s2_2.txt",   s2_2);

    ctr   = 0;
    state = START;
    start = 0;
  end

  always @(posedge clk) begin
    if (!tb_enable) begin
        data_i  <= 0;
        valid_i <= 0;
        ready_o <= 0;
        start   <= 0;
        rst     <= 1;
    end
    else begin
        rst     <= 0;
        data_i  <= 0;
        valid_i <= 0;
        ready_o <= 0;
        start   <= 0;

        case(state)
        START: begin
            start_time <= $time;

            if (ctr == 0) begin
                rst <= 1;
            end

            if (ctr < 2) begin
                ctr    <= ctr + 1;
            end else begin
                ctr <= 0;
                start <= 1;
                state  <= LOAD_RHO;
            end
        end
        LOAD_RHO: begin
            data_i  <= rho_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 3) begin
                    state  <= LOAD_MLEN;
                    ctr    <= 0;
                    data_i  <= {48'd0, mlen_2[c]};
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= rho_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_MLEN: begin
            data_i  <= {48'd0, mlen_2[c]};
            valid_i <= 1;

            if (ready_i) begin
                state  <= LOAD_TR;
                ctr    <= 0;
                data_i <= tr_2[c][(0)*64+:64];
            end
        end
        LOAD_TR: begin
            data_i  <= tr_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 3) begin
                    state  <= LOAD_M;
                    ctr    <= 0;
                    data_i <= m_2[c][(0)*64+:64];
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= tr_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_M: begin
            data_i  <= m_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if ((ctr+1)*8 >= mlen_2[c]) begin
                    state  <= LOAD_K;
                    ctr    <= 0;
                    data_i <= k_2[c][(0)*64+:64];
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= m_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_K: begin
            data_i  <= k_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 3) begin
                    state  <= LOAD_S1;
                    data_i <= s1_2[c][(0)*64+:64];
                    ctr    <= 0;
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= k_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_S1: begin
            data_i  <= s1_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 47) begin
                    state  <= LOAD_S2;
                    data_i <= s2_2[c][(0)*64+:64];
                    ctr    <= 0;
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= s1_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_S2: begin
            data_i  <= s2_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 47) begin
                    state  <= LOAD_T0;
                    data_i <= t0_2[c][(ctr+1)*64+:64];
                    ctr    <= 0;
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= s2_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_T0: begin
            data_i  <= t0_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 207) begin
                    state  <= UNLOAD_Z;
                    ctr    <= 0;
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= t0_2[c][(ctr+1)*64+:64];
                end
            end
        end
        UNLOAD_Z: begin
            ready_o <= 1;
            if (valid_o) begin
`ifdef CALIBRATE_BRIEF
                // Instrumentation (2026-08-15, TO-DO #13 follow-up): the
                // calibration sweep (offsets 0/80/160/240 ns, all MASKED,
                // see CLAUDE.md) proved the real transfer moment for the
                // first few Z-words isn't in that window at all. Print the
                // actual $time of each of the first 5 valid_o transfers
                // directly, ground truth instead of another guess.
                if (ctr < 5)
                    $display("[%0t] UNLOAD_Z transfer ctr=%0d, data_o=%h", $time, ctr, data_o);
`endif
                if (data_o !== z_2[c][ctr*64+:64]) begin
                    $display("[Z, %d] Error: Expected %h, received %h", ctr, z_2[c][ctr*64+:64], data_o);
                    mismatch_count = mismatch_count + 1;
                end

                ctr <= ctr + 1;

                if (ctr == 288-1) begin
                    ctr <= 0;
                    state <= UNLOAD_H;
                end
            end
        end
        UNLOAD_H: begin
            ready_o <= 1;
            if (valid_o) begin
                if (data_o != h_2[c][ctr*64+:64]) begin
                    $display("[H, %d] Error: Expected %h, received %h", ctr, h_2[c][ctr*64+:64], data_o);
                    mismatch_count = mismatch_count + 1;
                end

                ctr <= ctr + 1;

                if (ctr == 10) begin
                    ctr <= 0;
                    state <= UNLOAD_C;
                end
            end
        end
        UNLOAD_C: begin
            ready_o <= 1;
            if (valid_o) begin
                if (data_o != c_2[c][ctr*64+:64]) begin
                    $display("[C, %d] Error: Expected %h, received %h", ctr, c_2[c][ctr*64+:64], data_o);
                    mismatch_count = mismatch_count + 1;
                end

                ctr <= ctr + 1;

                if (ctr == 3) begin
                    ctr <= 0;
                    state <= START;
                    c <= c + 1;
                    $display("SG2[%d] completed in %d clock cycles", c, ($time-start_time)/10);

                    if (c == NUM_TV-1) begin
                        if (mismatch_count == 0)
                            $display("VERDICT: MASKED (signature correct, %0d mismatches)", mismatch_count);
                        else
                            $display("VERDICT: CORRUPTED (signature wrong, %0d mismatches)", mismatch_count);
                        $display("Testbench Done.");
                        $finish;
                    end
                end
            end
        end
        endcase
    end
  end

  always #(`P/2) clk = ~clk;

  // Safety timeout: a mid-operation reset (FORCE_LONG cases, by design,
  // see header comment) can desync this sequencer from DUT and hang
  // forever waiting for a handshake that never arrives; stop instead of
  // running indefinitely. A normal single-KAT-vector run completes in
  // ~110,000 ns.
  //
  // Widened 2026-08-14 from 2,000,000 ns to 20,000,000 ns (10x) after
  // case 6 (sustained TARGET_C corruption) hit the original timeout
  // without completing, to check whether the algorithm is genuinely stuck
  // forever or just needs far more cycles (repeated rejection-sampling
  // attempts on a corrupted seed) than normal. Paired with the heartbeat
  // monitor below so this doesn't need to be watched blindly: if
  // ctrfsm1's value is still changing between heartbeats, that's real
  // progress, not a deadlock, worth interrupting the run manually once
  // that's visible rather than waiting out the full 20 ms if it's clearly
  // still working, see CLAUDE.md.
  initial begin
    #20_000_000;
    $display("VERDICT: TIMEOUT (did not complete, %0d mismatches so far)", mismatch_count);
    $finish;
  end

  // Heartbeat (2026-08-14, added alongside the widened timeout above):
  // prints ctrfsm1's current value every 500,000 ns so a genuine deadlock
  // (frozen value) can be distinguished from slow-but-real progress
  // (still changing) within minutes, without waiting for the full
  // extended timeout to elapse.
  initial begin
    forever begin
      #500_000;
      $display("[%0t] HEARTBEAT: ctrfsm1=%0d, state=%0d, valid_o=%0b, ready_i=%0b",
                $time, DUT.ctrfsm1, state, valid_o, ready_i);
    end
  end

endmodule
`undef P
