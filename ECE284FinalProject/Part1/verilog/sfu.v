// sfu.v : Special Function Unit
// Accumulates psums from pmem (one row per cycle when acc=1) and applies ReLU at the output.
module sfu (clk, reset, acc, in, out);

  parameter col = 8;
  parameter psum_bw = 16;

  input  clk;
  input  reset;
  input  acc;                       // 1 = add this cycle's input (from inst[33])
  input  [psum_bw*col-1:0] in;      // 8 psums from pmem (column 0 in the lowest bits)
  output [psum_bw*col-1:0] out;     // 8 results after ReLU -> sfp_out

  genvar i;

  for (i=0; i<col ; i=i+1) begin : col_num

      reg  signed [psum_bw-1:0] acc_q;      // running sum for this column
      wire signed [psum_bw-1:0] in_col;     // this column's input psum

    assign in_col = in[psum_bw*(i+1)-1:psum_bw*i] ;                  // this column's 16-bit slice of "in"

      always @ (posedge clk) begin
         if (reset) begin
            acc_q <= 16'b0; ;                   // clear the running sum
         end
        else begin
          if (acc)
          	acc_q <= acc_q + in_col ;    // add this column's input
          else
            acc_q <= acc_q;
        end
      end

      // ReLU: negative -> 0, positive -> unchanged (output only; acc_q keeps its true value)
    assign out[psum_bw*(i+1)-1 : psum_bw*i] = acc_q[psum_bw-1]?{psum_bw{1'b0}}:acc_q ;

  end

endmodule