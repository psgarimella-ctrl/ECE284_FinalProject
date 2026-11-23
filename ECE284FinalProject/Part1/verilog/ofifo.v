// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module ofifo (clk, in, out, rd, wr, o_full, reset, o_ready, o_valid);

  parameter col  = 8;
  parameter bw = 16;

  input  clk;
  input  [col-1:0] wr;
  input  rd;
  input  reset;
  input  [bw*col-1:0] in;
  output [bw*col-1:0] out;
  output o_full;
  output o_ready;
  output o_valid;

  wire [col-1:0] empty;
  wire [col-1:0] full;
  reg  rd_en;
  
  genvar i;

  assign o_ready = ~(|full) ;
  assign o_full  = |full ;
  assign o_valid =  ~(|empty); //o-valid becomes 1 only when none of the column FIFOs are empty i.e. every column has atleast one output ready

  for (i=0; i<col ; i=i+1) begin : col_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
	 .rd_clk(clk),
	 .wr_clk(clk),
        .rd(rd_en),
        .wr(wr[i]),
        .o_empty(empty[i]),
        .o_full(full[i]),
        .in(in[bw*(i+1)-1:bw*i]),
        .out(out[bw*(i+1)-1:bw*i]),
         .reset(reset));
  end


  always @ (*) begin
     rd_en = rd & o_valid;            // pop one full row from all columns, or nothing
  end

endmodule
