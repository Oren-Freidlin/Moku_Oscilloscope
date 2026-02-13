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

  input wire[13:0] control[0:15], // 16 control signals each 14 bits
  output wire[31:0] status[0:15]  // 16 status signals each 32 bits
);

  reg[12:0] counter;          // 13 bit counter
  reg[15:0] bitstream;        // 16 bitstream. 
  
  always @(posedge clk) begin
    if (reset) begin
      counter <= 13'h000;
      bitstream <= 16'h7FFF; 
    // The counter will count up from 0 to 2094, outputting 0 (high)
    end else if (counter <= 13'd2094) begin
      counter <= counter + 1'd1;
      bitstream <= 16'h0000;  
    // Now the counter counts up from 2095 to 4187, outputting 1 (low)
    end else if (counter > 13'd2094 && counter < 13'd4188) begin
      counter <= counter + 1'd1;
      bitstream <= 16'h7FFF;  
    // Reset the counter and repeat. 
    end else begin
      counter <= 13'h000;
      bitstream <= 16'h0000; 
    end
  end
  
  assign outputa = bitstream;

endmodule