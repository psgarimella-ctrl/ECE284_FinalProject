module l0 (clk, in, out, rd, wr, o_full, reset, o_ready);

  parameter row  = 8;
  parameter bw = 4;

  input  clk;
  input  wr;
  input  rd;
  input  reset;
  input  [row*bw-1:0] in;
  output [row*bw-1:0] out;
  output o_full;
  output o_ready;

  wire [row-1:0] empty;
  wire [row-1:0] full;
  reg [row-1:0] rd_en;
  
  reg [2:0] count;
    
  genvar i;
  genvar j;

  assign o_ready = |empty; //o_ready is excecuted only when one of the FIFO slot is empty   
  assign o_full  = |full ; //o_full is asserted when any of the slots is full


  for (i=0; i<row ; i=i+1) begin : row_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
	 .rd_clk(clk),
	 .wr_clk(clk),
	 .rd(rd_en[i]),
        .wr(wr),
        .o_empty(empty[i]),
        .o_full(full[i]),
        .in(in[bw*(i+1)-1:bw*i]),
        .out(out[bw*(i+1)-1:bw*i]),
         .reset(reset));
  end

  

  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 8'b00000000;
   end
   else begin
     if (rd) begin
            rd_en <= 8'b00000001 << count;

            if (count == row-1)
                count <= 0;
            else
                count <= count + 1'b1;
        end
        else begin
            rd_en <= 8'b00000000;
            count <= count;
        end
   end
  end
endmodule