module InputDriver (
  input  wire        clk,
  input  wire        reset,
  output wire signed [15:0] a,
  output wire signed [15:0] b,
  output wire signed [15:0] c,
  output wire signed [15:0] d
);

  reg [15:0] cnt;

  always @(posedge clk) begin
    if (reset)
      cnt <= 0;
    else
      cnt <= cnt + 1;
  end

  assign a = cnt;
  assign b = -cnt;
  assign c = cnt >>> 1; // Arithmetic right shift by 1 (divide by 2). When assigning this to c, 
                      // it will be sign-extended to 16 bits, so the sign bit will be replicated.
                      // on every clk, c will be assigned the value of cnt divided by 2, with sign extension if cnt is negative.
  assign d = 16'sh7FFF;

endmodule