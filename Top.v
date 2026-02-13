module Top (
  input wire clk,
  input wire reset
);

  wire signed [15:0] a, b, c, d;

  InputDriver drv (
    .clk(clk),
    .reset(reset),
    .a(a), .b(b), .c(c), .d(d)
  );

  CustomInstrument inst (
    .clk(clk),
    .reset(reset),
    .inputa(a),
    .inputb(b),
    .inputc(c),
    .inputd(d)
  );

endmodule