//================================================================================
//DIGITAL IMAGE PROCESSOR: 15-BIT SWITCH HIERARCHY DOCUMENTATION
//================================================================================

//Total Bus: SW[14:0]

//--------------------------------------------------------------------------------
//1. MASTER OUTPUT CONTROL (Visibility Tier)
//--------------------------------------------------------------------------------
//These switches act as a final gate before the BRAM. 
//If a switch is LOW (0), that color channel will be black on the screen.

//[SW 14] : BLUE  Channel Enable (1 = ON, 0 = DARK)
//[SW 13] : GREEN Channel Enable (1 = ON, 0 = DARK)
//[SW 12] : RED   Channel Enable (1 = ON, 0 = DARK)

//--------------------------------------------------------------------------------
//2. COLOR CHANNEL PROCESSING (Filter Tier)
//--------------------------------------------------------------------------------
//Each 4-bit block controls how that specific color is calculated.

//A. RED CHANNEL (SW[3:0])
//   [SW 3]   : Mode Select (0 = Generic Filter, 1 = SOBEL Edge Detection)
//   [SW 2:0] : Generic Filter Type (Only active if SW[3] is 0)
//              000: Identity (Raw)  010: Sharpen      100: Emboss
//              001: Gaussian Blur   011: Mean Blur     ... (up to 8)

//B. GREEN CHANNEL (SW[7:4])
//   [SW 7]   : Mode Select (0 = Generic Filter, 1 = SOBEL Edge Detection)
//   [SW 6:4] : Generic Filter Type (Only active if SW[7] is 0)

//C. BLUE CHANNEL (SW[11:8])
//   [SW 11]  : Mode Select (0 = Generic Filter, 1 = SOBEL Edge Detection)
//   [SW 10:8]: Generic Filter Type (Only active if SW[11] is 0)

//--------------------------------------------------------------------------------
//3. COMMON CONFIGURATION EXAMPLES
//--------------------------------------------------------------------------------

//* FULL SOBEL (Black & White style):
//  - Set SW[14:12] = 111 (All channels on)
//  - Set SW[11], SW[7], SW[3] = 1 (All channels Sobel mode)
  
//* NIGHT VISION EFFECT:
//  - Set SW[14:12] = 010 (Only Green channel ON)
//  - Set SW[7] = 1 (Sobel) or 0 (with a Blur filter on SW[6:4])

//* COLOR SWAP/FILTERING:
//  - Turn off Red (SW[12]=0) to see how the image looks in Cyan (Blue+Green).
//  - Apply Blur to Green only to create a soft-focus center.
//================================================================================

`timescale 1ns / 1ps
`default_nettype none

module image_processing_wrapper (
    input  wire        i_pclk,
    input  wire        i_rstn_pclk,
    input  wire        i_vsync,       
    input  wire        i_href,        
    input  wire        i_cam_wr,
    input  wire [11:0] i_cam_data,   
    input  wire [14:0] SW, 
    
    output wire        o_bram_wr,
    output reg  [18:0] o_bram_addr,
    output wire [11:0] o_bram_data    
);

    wire [7:0] r_in = {i_cam_data[11:8], 4'b1111};
    wire [7:0] g_in = {i_cam_data[7:4],  4'b1111};
    wire [7:0] b_in = {i_cam_data[3:0],  4'b1111};

    wire [7:0] r_out_8, g_out_8, b_out_8;
    wire r_valid, g_valid, b_valid;
    wire intr_r , intr_g , intr_b;
    wire intr_all;

    wire data_valid = i_cam_wr; 

    imageprocesstop process_red   (.axi_clk(i_pclk), .axi_reset_n(i_rstn_pclk), .i_data_valid(data_valid), .i_data(r_in), .o_data_valid(r_valid), .o_data(r_out_8), .i_data_ready(1'b1) , .o_intr(intr_r) , .SW(SW[3:0]));
    imageprocesstop process_green (.axi_clk(i_pclk), .axi_reset_n(i_rstn_pclk), .i_data_valid(data_valid), .i_data(g_in), .o_data_valid(g_valid), .o_data(g_out_8), .i_data_ready(1'b1) , .o_intr(intr_g) , .SW(SW[7:4]));
    imageprocesstop process_blue  (.axi_clk(i_pclk), .axi_reset_n(i_rstn_pclk), .i_data_valid(data_valid), .i_data(b_in), .o_data_valid(b_valid), .o_data(b_out_8), .i_data_ready(1'b1) , .o_intr(intr_b) , .SW(SW[11:8]));

    wire [3:0] final_r = (SW[12]) ? r_out_8[7:4] : 4'h0;
    wire [3:0] final_g = (SW[13]) ? g_out_8[7:4] : 4'h0;
    wire [3:0] final_b = (SW[14]) ? b_out_8[7:4] : 4'h0;

    assign o_bram_data = {final_r, final_g, final_b};
    assign intr_all = intr_g & intr_b & intr_r;
    assign o_bram_wr   = (r_valid & g_valid & b_valid )| intr_all;
    
    reg vsync_reg;
    always @(posedge i_pclk) vsync_reg <= i_vsync;
    
    wire vsync_falling_edge = (vsync_reg == 1'b1) && (i_vsync == 1'b0);

    always @(posedge i_pclk) begin
        if (!i_rstn_pclk) begin
            o_bram_addr <= 0;
        end else if (vsync_falling_edge) begin
            o_bram_addr <= 0;
        end else if (o_bram_wr) begin
            o_bram_addr <= (o_bram_addr == 307199) ? 0 : o_bram_addr + 1;
        end
    end

endmodule

