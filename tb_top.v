`timescale 1ns/1ps

module tb_top;

  reg clk = 0;
  reg reset = 1;  // active low, so start high, switch to 0 to release reset

  // 312.5 MHz → 3.2 ns period
  always #1.6 clk = ~clk;

  Top dut (
    .clk(clk),
    .reset(reset)
  );

  initial begin
    // Tell the simulator to write a VCD
    $dumpfile("Driver_tp.vcd");
    $dumpvars(0, tb_top);

    // Reset pulse
    #10;
    reset = 0;

    // Run long enough to see behavior
    #100000;

    $finish;
  end

endmodule