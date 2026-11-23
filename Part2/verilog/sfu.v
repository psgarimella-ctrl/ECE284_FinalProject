// sfu.v (Part 2) : Special Function Unit
// One accumulator per column. Operations (all on the rising clock edge):
//   reset   : acc = 0, y0 = 0
//   load_y0 : acc = y0                    (start a delta frame from the stored Y0)
//   acc     : acc = acc + in              (shift = 0)
//             acc = acc + 16*in           (shift = 1, for the X0_high psums)
//   save_y0 : y0  = acc                   (store Y0 for reuse by the delta frames)
// Output:  relu_en = 1 -> ReLU(acc)       relu_en = 0 -> raw acc (Part 2)
module sfu (clk, reset, acc, shift, save_y0, load_y0, relu_en, in, out);

  parameter col     = 8;
  parameter psum_bw = 16;            // width of one psum coming from pmem
  parameter acc_bw  = 24;            // accumulator width (Y0 needs >= 18 bits)

  input  clk;
  input  reset;
  input  acc;                        // 1 = add this cycle's input
  input  shift;                      // 1 = add the input x16 (high-nibble pass)
  input  save_y0;                    // 1 = copy acc into the Y0 register
  input  load_y0;                    // 1 = copy the Y0 register into acc
  input  relu_en;                    // 1 = ReLU on the output, 0 = raw output
  input  [psum_bw*col-1:0] in;       // 8 psums from pmem (column 0 in the lowest bits)
  output [acc_bw*col-1:0]  out;      // 8 results -> sfp_out

  genvar i;

  for (i=0; i<col ; i=i+1) begin : col_num

      reg  signed [acc_bw-1:0]  acc_q;     // running sum for this column
      reg  signed [acc_bw-1:0]  y0_q;      // stored Y0 for this column
      wire signed [psum_bw-1:0] in_col;    // this column's 16-bit psum
      wire signed [acc_bw-1:0]  in_ext;    // sign-extended to acc_bw, optionally x16

      assign in_col = in[psum_bw*(i+1)-1 : psum_bw*i];

      // $signed(...) sign-extends to acc_bw bits; <<< 4 multiplies by 16 (keeps the sign)
      assign in_ext = shift ? ($signed(in_col) <<< 4) : $signed(in_col);

      // running sum
      always @ (posedge clk) begin
         if (reset)
            acc_q <= {acc_bw{1'b0}};
         else if (load_y0)
            acc_q <= y0_q;
         else if (acc)
            acc_q <= acc_q + in_ext;
      end

      // stored Y0
      always @ (posedge clk) begin
         if (reset)
            y0_q <= {acc_bw{1'b0}};
         else if (save_y0)
            y0_q <= acc_q;
      end

      // output: ReLU only when relu_en = 1 (acc_q always keeps its true value)
      assign out[acc_bw*(i+1)-1 : acc_bw*i] = (relu_en && acc_q[acc_bw-1]) ? {acc_bw{1'b0}} : acc_q;

  end

endmodule