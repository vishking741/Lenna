`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.04.2026 16:59:25
// Design Name: 
// Module Name: conv_sobel
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


module conv_sobel(
    input  wire        i_clk,
    input  wire [71:0] i_pixel_data,
    input  wire        i_pixel_data_valid,
    output reg  [7:0]  o_convolved_data,
    output reg         o_convolved_data_valid
);

    integer i;
    reg signed [7:0]  kernel_x [8:0];
    reg signed [7:0]  kernel_y [8:0];
    
    reg signed [16:0] mul_x [8:0];
    reg signed [16:0] mul_y [8:0];
    
    reg signed [19:0] sum_x; 
    reg signed [19:0] sum_y;
    reg               mul_valid;

    initial begin
        kernel_x[0] = -8'd1; kernel_x[1] =  8'd0; kernel_x[2] =  8'd1;
        kernel_x[3] = -8'd2; kernel_x[4] =  8'd0; kernel_x[5] =  8'd2;
        kernel_x[6] = -8'd1; kernel_x[7] =  8'd0; kernel_x[8] =  8'd1;

        kernel_y[0] = -8'd1; kernel_y[1] = -8'd2; kernel_y[2] = -8'd1;
        kernel_y[3] =  8'd0; kernel_y[4] =  8'd0; kernel_y[5] =  8'd0;
        kernel_y[6] =  8'd1; kernel_y[7] =  8'd2; kernel_y[8] =  8'd1;
    end

    always @(posedge i_clk) begin
        for(i=0; i<9; i=i+1) begin
            mul_x[i] <= kernel_x[i] * $signed({1'b0, i_pixel_data[i*8+:8]});
            mul_y[i] <= kernel_y[i] * $signed({1'b0, i_pixel_data[i*8+:8]});
        end 
        mul_valid <= i_pixel_data_valid;
    end

    reg signed [19:0] abs_x, abs_y, final_sum;
    integer j;

    always @(posedge i_clk) begin
        sum_x = 20'd0;
        sum_y = 20'd0;
        
        for(j=0; j<9; j=j+1) begin
            sum_x = sum_x + mul_x[j];
            sum_y = sum_y + mul_y[j];
        end

        abs_x = (sum_x < 0) ? -sum_x : sum_x;
        abs_y = (sum_y < 0) ? -sum_y : sum_y;
        
        final_sum = abs_x + abs_y;

        if (final_sum > 20'sd255)
            o_convolved_data <= 8'hFF;
        else if (final_sum < 20'sd0)
            o_convolved_data <= 8'h00;
        else
            o_convolved_data <= final_sum[7:0];

        o_convolved_data_valid <= mul_valid;
    end

endmodule
