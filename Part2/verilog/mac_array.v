// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid, mode);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;
  output [col-1:0] valid;
  input mode;

  // ---- internal signals ----
  reg  [2*row-1:0]               inst_w_temp; // delayed instruction for each row (2 bits per row)
  wire [psum_bw*col*(row+1)-1:0] temp;        // 9 boxes of 128-bit psums between rows
  wire [row*col-1:0]             valid_temp;  // valid bits from every row (8 per row)

  // ---- the three assigns ----
  assign temp[psum_bw*col-1:0] = 0;                              // box 0: nothing above the top row
  assign out_s = temp[psum_bw*col*(row+1)-1 : psum_bw*col*row];  // box 8: bottom row's output
  assign valid = valid_temp[row*col-1 : row*col-col];            // only the last row's valid

  // ---- stack 8 rows ----
  genvar i;
  for (i=1; i < row+1 ; i=i+1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw)) mac_row_instance (
         .clk   (clk),
         .reset (reset),
         .in_w  (in_w[bw*i-1 : bw*(i-1)]),                          // this row's x
         .inst_w(inst_w_temp[2*i-1 : 2*(i-1)]),                     // this row's delayed instruction
         .in_n  (temp[psum_bw*col*i-1 : psum_bw*col*(i-1)]),        // box i-1 (from above)
         .out_s (temp[psum_bw*col*(i+1)-1 : psum_bw*col*i]),        // box i (going down)
         .valid (valid_temp[col*i-1 : col*(i-1)]), mode(mode)                   // this row's valid bits
      );
  end

  // ---- bucket brigade: instruction moves down one row per clock ----
  always @ (posedge clk) begin
    inst_w_temp[1:0]   <= inst_w;             // row 1
    inst_w_temp[3:2]   <= inst_w_temp[1:0];   // row 2
    inst_w_temp[5:4]   <= inst_w_temp[3:2];   // row 3
    inst_w_temp[7:6]   <= inst_w_temp[5:4];   // row 4
    inst_w_temp[9:8]   <= inst_w_temp[7:6];   // row 5
    inst_w_temp[11:10] <= inst_w_temp[9:8];   // row 6
    inst_w_temp[13:12] <= inst_w_temp[11:10]; // row 7
    inst_w_temp[15:14] <= inst_w_temp[13:12]; // row 8
  end

endmodule