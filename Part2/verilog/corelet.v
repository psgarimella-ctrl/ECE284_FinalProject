// corelet.v : L0 + mac_array + OFIFO + SFU   (this is what goes on the FPGA)
module corelet (clk, reset, inst, data_in, ofifo_out, ofifo_valid, pmem_in, sfp_out);

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
  input  [bw*row-1:0] data_in;                    // from xmem (32 bits)
  output [psum_bw*col-1:0] ofifo_out;                  // to pmem (128 bits)
  output ofifo_valid;                       // OFIFO has a full row
  input  [psum_bw*col-1:0] pmem_in;                    // from pmem (128 bits)
  output [acc_bw*col-1:0] sfp_out;                    // final result (128 bits)

  // ---- Step 3: internal wires ----
  wire [bw*row-1:0] l0_out;                       // L0 -> mac_array           (32 bits)
  wire        l0_full, l0_ready;            // L0 flags (unused, visible in waveform)
  wire [psum_bw*col-1:0] array_out;                    // mac_array -> OFIFO        (128 bits)
  wire [col-1:0] array_valid;                  // mac_array -> OFIFO wr     (8 bits)
  wire        ofifo_full, ofifo_ready;      // OFIFO flags (unused)

  // ---- Step 4: L0 ----
  l0 #(.row(row), .bw(bw)) l0_inst (
      .clk    (clk),
      .reset  (reset),
    .in     (data_in),                         // word from xmem
    .out    (l0_out),                         // staircase output to the array
    .wr     (inst[2]),                         // l0_wr bit
    .rd     (inst[3]),                         // l0_rd bit
      .o_full (l0_full),
      .o_ready(l0_ready));

  // ---- Step 5: mac_array ----
  mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_inst (
      .clk    (clk),
      .reset  (reset),
    .in_w   (l0_out),                         // from L0
    .in_n   ({psum_bw*col{1'b0}}),                         // nothing from above: all zeros
    .inst_w (inst[1:0]),                         // 2 bits: [1]=execute, [0]=load
    .out_s  (array_out),                         // bottom-row psums
    .valid  (array_valid), .mode(inst[34]));                        // which columns are ready

  // ---- Step 6: OFIFO ----
  ofifo #(.col(col), .bw(psum_bw)) ofifo_inst (  // width = psum width
      .clk    (clk),
      .reset  (reset),
    .in     (array_out),                         // from the array
    .wr     (array_valid),                         // per-column write = array valid
    .rd     (inst[6]),                         // ofifo_rd bit
    .out    (ofifo_out),                         // corelet output to pmem
    .o_valid(ofifo_valid),                         // corelet output
      .o_full (ofifo_full),
      .o_ready(ofifo_ready));

  // ---- Step 7: SFU ----
  sfu #(.col(col), .psum_bw(psum_bw), .acc_bw(acc_bw)) sfu_inst (
      .clk    (clk),
      .reset  (reset),
    .acc    (inst[33]),                         // acc bit
    .in     (pmem_in),                         // psums from pmem
    .out    (sfp_out), .shift(inst[35]), .save_y0(inst[36]), .load_y0(inst[37]), .relu_en(inst[38]));                        // corelet output

endmodule