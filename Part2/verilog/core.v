// core.v : top level = xmem + pmem + corelet   (port names must match core_tb.v)
module core (clk, inst, ofifo_valid, D_xmem, sfp_out, reset);

  // ---- Step 1: parameters ----
  parameter bw      = 4;
  parameter psum_bw = 16;
  parameter acc_bw = 24;
  parameter col     = 8;
  parameter row     = 8;

  // ---- Step 2: ports ----
  input  clk;
  input  reset;
  input  [38:0] inst;                       // instruction bus
  input  [31:0] D_xmem;                     // testbench data for xmem (32 bits)
  output ofifo_valid;
  output [acc_bw*col-1:0] sfp_out;                    // SFU result (128 bits)

  // ---- Step 3: internal wires ----
  wire [31:0] xmem_q;                       // xmem Q      -> corelet data_in  (32 bits)
  wire [127:0] ofifo_out;                    // corelet     -> pmem D           (128 bits)
  wire [127:0] pmem_q;                       // pmem Q      -> corelet pmem_in  (128 bits)

  // ---- Step 4: activation / weight memory ----
  sram_32b_w2048 xmem (
      .CLK (clk),
    .D   (D_xmem),
    .Q   (xmem_q),
    .CEN (inst[19]),
    .WEN (inst[18]),
    .A   (inst[17:7]));

  // ---- Step 5: psum memory ----
  sram_128b_w2048 pmem (
      .CLK (clk),
    .D   (ofifo_out),
    .Q   (pmem_q),
    .CEN (inst[32]),
    .WEN (inst[31]),
    .A   (inst[30:20]));

  // ---- Step 6: compute block ----
  corelet #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row), .acc_bw(acc_bw)) corelet_inst (
      .clk         (clk),
      .reset       (reset),
    .inst        (inst),
    .data_in     (xmem_q),
    .ofifo_out   (ofifo_out),
    .ofifo_valid (ofifo_valid),
    .pmem_in     (pmem_q),
    .sfp_out     (sfp_out));

endmodule