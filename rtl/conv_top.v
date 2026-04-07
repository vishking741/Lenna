`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.04.2026 17:01:50
// Design Name: 
// Module Name: conv_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module conv_top(
    input  wire        i_clk,
    input  wire [71:0] i_pixel_data,
    input  wire        i_pixel_data_valid,
    input  wire [3:0]  SW,
    output reg  [7:0]  o_convolved_data,
    output reg         o_convolved_data_valid
);

    wire [7:0] sobel_data;
    wire       sobel_valid;
    wire [7:0] generic_data;
    wire       generic_valid;


    conv_sobel sobel (
        .i_clk                 (i_clk),
        .i_pixel_data          (i_pixel_data),
        .i_pixel_data_valid    (i_pixel_data_valid),
        .o_convolved_data      (sobel_data),
        .o_convolved_data_valid(sobel_valid)
    );

    conv_generic generic (
        .i_clk                 (i_clk),
        .i_pixel_data          (i_pixel_data),
        .i_pixel_data_valid    (i_pixel_data_valid),
        .SW                    (SW[2:0]),
        .o_convolved_data      (generic_data),
        .o_convolved_data_valid(generic_valid)
    );
//check 
    always @(posedge i_clk) begin
        if (SW[3]) begin
            o_convolved_data       <= sobel_data;
            o_convolved_data_valid <= sobel_valid;
        end else begin
            o_convolved_data       <= generic_data;
            o_convolved_data_valid <= generic_valid;
        end
    end

endmodule
