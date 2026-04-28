`timescale 1ns/1ps

module CustomInstrument_tb;

    // ── DUT ports ─────────────────────────────────────────────────
    reg         clk    = 0;
    reg         reset  = 1;
    reg  [31:0] sync   = 0;
    reg  signed [15:0] inputa = 0, inputb = 0, inputc = 0, inputd = 0;
    reg         exttrig = 0;
    wire signed [15:0] outputa, outputb, outputc, outputd;
    reg  [31:0] control[0:15];
    wire [31:0] status[0:15];

    // ── Parameters (mirror DUT) ───────────────────────────────────
    localparam N_LOOP        = 3989;
    localparam N_TIME_BIN    = 2;
    localparam N_SW          = 4;
    localparam N_DELAY       = 100;
    localparam N_SWITCH_LEN  = N_LOOP / N_TIME_BIN;  // 1994
    localparam N_MZI         = N_LOOP;
    localparam N_EXPT        = N_LOOP + N_MZI;        // 7978
    localparam BRANCH_POINT  = N_LOOP;                // 3989
    localparam N_ATOM_PERIOD = 2500;
    localparam N_CYCLES      = 3;  // full experiment cycles to simulate

    // ── Clock: 10 ns period ───────────────────────────────────────
    always #5 clk = ~clk;
    
    // ── DUT instantiation ─────────────────────────────────────────
    CustomInstrument #(
        .N_LOOP       (N_LOOP),
        .N_TIME_BIN   (N_TIME_BIN),
        .N_SW         (N_SW),
        .N_DELAY      (N_DELAY),
        .N_ATOM_PERIOD(N_ATOM_PERIOD)
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .sync     (sync),
        .inputa   (inputa),
        .inputb   (inputb),
        .inputc   (inputc),
        .inputd   (inputd),
        .exttrig  (exttrig),
        .outputa  (outputa),
        .outputb  (outputb),
        .outputc  (outputc),
        .outputd  (outputd),
        .control  (control),
        .status   (status)
    );

    // ── Tracking variables ────────────────────────────────────────
    integer cycle_num = 0;
    integer branch_hits      = 0;   // times we reached BRANCH_POINT
    integer phase_increments = 0;   // times phase was actually added
    integer phase_skips      = 0;   // times atom_cavity blocked the add

    reg [15:0] prev_photon_phase = 0;
    reg        prev_atom_cavity  = 0;
    reg [31:0] prev_clk_counter  = 0;

    // ── Capture internal signals via hierarchical references ──────
    wire [31:0] clk_counter  = dut.clk_counter;
    wire [15:0] photon_phase = dut.photon_phase;
    wire        atom_cavity  = dut.atom_cavity;
    wire [31:0] atom_counter = dut.atom_counter;
    wire [1:0]  tb_idx       = dut.tb_idx;
    wire [31:0] slot_counter = dut.slot_counter;

    wire expected_sw3 = (clk_counter >= (N_SW-1)*N_SWITCH_LEN - N_DELAY) &&
                         (clk_counter <  N_EXPT - N_DELAY);

    // ── Task: print a timestamped info line ───────────────────────
    task print_state(input [127:0] tag);
        $display("[%0t ns] %s | clk_ctr=%0d tb_idx=%0d slot=%0d | atom_cav=%b atom_ctr=%0d | photon_phase=%0d | sw1=%b sw2=%b sw3=%b",
            $time, tag,
            clk_counter, tb_idx, slot_counter,
            atom_cavity, atom_counter,
            photon_phase,
            outputa[15], outputb[15], outputc[15]);
    endtask

    // ── Main stimulus ─────────────────────────────────────────────
    integer i;
    initial begin
        // Initialise control
        for (i = 0; i < 16; i++) control[i] = 32'h0;

        // ── Reset pulse ───────────────────────────────────────────
        reset = 1;
        repeat(4) @(posedge clk);
        @(negedge clk);
        reset = 0;
        $display("[%0t ns] Reset released", $time);

        // ── Run for N_CYCLES complete experiment cycles ───────────
        repeat(N_CYCLES * N_EXPT) begin
            @(posedge clk);
            #1; // sample just after posedge so registered values have settled

            // ── Detect experiment cycle wrap ──────────────────────
            if (clk_counter == 0 && prev_clk_counter == N_EXPT - 1) begin
                cycle_num++;
                $display("\n━━━ Experiment cycle %0d complete ━━━", cycle_num);
                $display("    Branch hits this cycle      : tracked cumulatively");
                $display("    Total phase increments so far: %0d", phase_increments);
                $display("    Total phase skips so far     : %0d", phase_skips);
            end

            // ── Detect BRANCH_POINT ───────────────────────────────
            if (prev_clk_counter == BRANCH_POINT) begin
                branch_hits++;
                if (photon_phase != prev_photon_phase) begin
                    phase_increments++;
                    $display("[%0t ns] BRANCH_POINT: atom_cavity=%b → phase %0d→%0d (+1)",
                        $time, prev_atom_cavity, prev_photon_phase, photon_phase);
                end else begin
                    phase_skips++;
                    $display("[%0t ns] BRANCH_POINT: atom_cavity=%b → phase HELD at %0d",
                        $time, prev_atom_cavity, photon_phase);
                end
            end

            // ── Check: phase should only ever change at BRANCH_POINT ──
            if (photon_phase != prev_photon_phase && prev_clk_counter != BRANCH_POINT) begin
                $error("[%0t ns] FAIL: photon_phase changed outside BRANCH_POINT (clk_ctr=%0d, %0d→%0d)",
                    $time, prev_clk_counter, prev_photon_phase, photon_phase);
            end

            // ── Check: phase increments by at most 1 ─────────────
            if (photon_phase - prev_photon_phase > 1 && photon_phase > prev_photon_phase) begin
                $error("[%0t ns] FAIL: photon_phase jumped by >1 (clk_ctr=%0d, %0d→%0d)",
                    $time, prev_clk_counter, prev_photon_phase, photon_phase);
            end

            // ── Check: sw3 is high only in the sw3_on_window ─────
            begin

                if (outputc[15] !== expected_sw3)
                $error("[%0t ns] FAIL: sw3 mismatch at clk_ctr=%0d (got %b, expected %b)",
                    $time, prev_clk_counter, outputc[15], expected_sw3);
            end

            // ── Snapshot key moments each cycle ──────────────────
            if (clk_counter == 0    ||
                clk_counter == 1    ||
                clk_counter == BRANCH_POINT - 1 ||
                clk_counter == BRANCH_POINT     ||
                clk_counter == BRANCH_POINT + 1 ||
                clk_counter == N_EXPT - N_DELAY ||
                clk_counter == N_EXPT - 1)
                print_state("SNAP");

            // ── Save previous values ──────────────────────────────
            prev_clk_counter  <= clk_counter;
            prev_photon_phase <= photon_phase;
            prev_atom_cavity  <= atom_cavity;
        end

        // ── Final summary ─────────────────────────────────────────
        $display("\n══════════════════════════════════════════");
        $display("  Simulation complete — %0d experiment cycles", N_CYCLES);
        $display("  Total BRANCH_POINT events : %0d", branch_hits);
        $display("  Phase increments          : %0d", phase_increments);
        $display("  Phase skips (atom_cav=1)  : %0d", phase_skips);
        $display("  Final photon_phase value  : %0d × π", photon_phase);

        // ── Sanity check: increments + skips == branch_hits ──────
        if (phase_increments + phase_skips !== branch_hits)
            $error("FAIL: increments (%0d) + skips (%0d) != branch_hits (%0d)",
                phase_increments, phase_skips, branch_hits);
        else
            $display("  PASS: increments + skips == branch_hits ✓");

        $display("══════════════════════════════════════════\n");
        $finish;
    end

    // ── Waveform dump ─────────────────────────────────────────────
    initial begin
        $dumpfile("custom_instrument.vcd");
        $dumpvars(0, CustomInstrument_tb);
    end

endmodule