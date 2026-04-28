module CustomInstrument (
    input wire clk,
    input wire reset,
    input wire [31:0] sync,
    input wire signed [15:0] inputa,
    input wire signed [15:0] inputb,
    input wire signed [15:0] inputc,
    input wire signed [15:0] inputd,
    input wire exttrig,
    output wire signed [15:0] outputa,
    output wire signed [15:0] outputb,
    output wire signed [15:0] outputc,
    output wire signed [15:0] outputd,
    input wire [31:0] control [0:15],
    output wire [31:0] status[0:15]
);
    parameter N_LOOP       = 3989;
    parameter N_TIME_BIN   = 2;
    parameter N_SW         = 4;
    parameter N_DELAY      = 100;
    parameter N_SWITCH_LEN = N_LOOP / N_TIME_BIN;   // 1994
    parameter N_MZI        = N_LOOP;
    parameter N_EXPT       = N_LOOP + N_MZI;         // 7978
    parameter BRANCH_POINT = N_LOOP;                 // = 3989
    parameter SW1_SEQUENCE = 4'b0100;
    parameter SW2_SEQUENCE = 4'b0001;

    // ── Atom cavity period (independent toggle) ───────────────────
    // Adjust N_ATOM_PERIOD to set how often atom_cavity toggles.
    parameter N_ATOM_PERIOD = 2500;

    // ── Registers ────────────────────────────────────────────────
    reg [31:0] clk_counter   = 0;
    reg [1:0]  tb_idx        = 0;
    reg [31:0] slot_counter  = 0;
    reg        sw1, sw2, sw3;

    reg        atom_cavity   = 0;   // 1-bit: independent periodic signal
    reg [15:0] photon_phase  = 0;   // 16-bit: phase in discrete multiples of pi
    reg [31:0] atom_counter  = 0;   // drives atom_cavity toggle

    // ── Combinational: sw3 window ─────────────────────────────────
    wire sw3_on_window = (clk_counter >= (N_SW-1)*N_SWITCH_LEN - N_DELAY) &&
                         (clk_counter <  N_EXPT - N_DELAY);

    // ── Sequential logic ──────────────────────────────────────────
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_counter  <= 0;
            slot_counter <= 0;
            tb_idx       <= 0;
            sw1 <= 0; sw2 <= 0; sw3 <= 0;

            atom_cavity  <= 0;
            atom_counter <= 0;
            photon_phase <= 0;
        end else begin

            // ── atom_cavity: independent periodic toggle ────────────
            if (atom_counter >= N_ATOM_PERIOD - 1) begin
                atom_counter <= 0;
                atom_cavity  <= ~atom_cavity;
            end else begin
                atom_counter <= atom_counter + 1;
            end

            // ── photon_phase accumulation at BRANCH_POINT ───────────
            // At every cycle where clk_counter == BRANCH_POINT:
            //   - if atom_cavity is HIGH  → skip (no phase added)
            //   - otherwise               → add 1 (one unit of pi)
            if (clk_counter == BRANCH_POINT) begin
                if (atom_cavity) begin
                    photon_phase <= photon_phase + 16'd1;
                end
                // else: atom_cavity high → hold phase
            end

            // ── Advance slot counter; roll tb_idx at each boundary ──
            if (slot_counter >= N_SWITCH_LEN - 1) begin
                slot_counter <= 0;
                tb_idx       <= (tb_idx >= N_SW - 1) ? 2'd0 : tb_idx + 1'd1;
            end else begin
                slot_counter <= slot_counter + 1;
            end

            // ── Full experiment cycle reset ─────────────────────────
            if (clk_counter >= N_EXPT - 1) begin
                clk_counter  <= 0;
                slot_counter <= 0;
                tb_idx       <= 0;
            end else begin
                clk_counter <= clk_counter + 1;
            end

            // ── Switch outputs ──────────────────────────────────────
            sw1 <= SW1_SEQUENCE[N_SW - 1 - tb_idx];
            sw2 <= SW2_SEQUENCE[N_SW - 1 - tb_idx];
            sw3 <= sw3_on_window;
        end
    end

    // ── Output assignments ────────────────────────────────────────
    assign outputa = sw1 ? 16'h7FFF : 16'h0000;
    assign outputb = sw2 ? 16'h7FFF : 16'h0000;
    assign outputc = sw3 ? 16'h7FFF : 16'h0000;
    assign outputd = 16'b0;

endmodule