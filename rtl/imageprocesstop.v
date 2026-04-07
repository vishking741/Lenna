module imageprocesstop(
    input  wire       axi_clk,
    input  wire       axi_reset_n,
    // Slave interface (Input from BRAM/Camera)
    input  wire       i_data_valid,
    input  wire [7:0] i_data,
    output wire       o_data_ready,
    // Master interface (Output to VGA)
    output wire       o_data_valid,
    output wire [7:0] o_data,
    input  wire       i_data_ready,
    // Interrupt    
    output wire       o_intr,
    
    input  wire [3:0] SW
);

wire [71:0] pixel_data;
wire pixel_data_valid;
wire axis_prog_full;
wire [7:0] convolved_data;
wire convolved_data_valid;

assign o_data_ready = !axis_prog_full;    

imagecontroller IC(
    .clk(axi_clk),
    .rst(!axi_reset_n),
    .data(i_data),
    .datavalid(i_data_valid),
    .o_data(pixel_data),
    .o_datavalid(pixel_data_valid),
    .o_intr(o_intr)
  );    
  
 conv_top conv(
     .i_clk(axi_clk),
     .i_pixel_data(pixel_data),
     .i_pixel_data_valid(pixel_data_valid),
     .SW(SW[3:0]),
     .o_convolved_data(convolved_data),
     .o_convolved_data_valid(convolved_data_valid)
 ); 
 
 outputbuffer OB (
   .wr_rst_busy(),        // output wire wr_rst_busy
   .rd_rst_busy(),        // output wire rd_rst_busy
   .s_aclk(axi_clk),                  // input wire s_aclk
   .s_aresetn(axi_reset_n),            // input wire s_aresetn
   .s_axis_tvalid(convolved_data_valid),    // input wire s_axis_tvalid
   .s_axis_tready(),    // output wire s_axis_tready
   .s_axis_tdata(convolved_data),      // input wire [7 : 0] s_axis_tdata
   .m_axis_tvalid(o_data_valid),    // output wire m_axis_tvalid
   .m_axis_tready(i_data_ready),    // input wire m_axis_tready
   .m_axis_tdata(o_data),      // output wire [7 : 0] m_axis_tdata
   .axis_prog_full(axis_prog_full)  // output wire axis_prog_full
 );
 
endmodule
