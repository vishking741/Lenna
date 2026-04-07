`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.04.2026 16:31:57
// Design Name: 
// Module Name: conv_generic
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


module conv_generic(
    input  wire        i_clk,
    input  wire [71:0] i_pixel_data,
    input  wire        i_pixel_data_valid,
    input  wire [2:0]  SW,
    output reg  [7:0]  o_convolved_data,
    output reg         o_convolved_data_valid
);

    reg signed [7:0]  kernel [8:0];
    reg [4:0]         div_val, div_reg; 
    reg signed [15:0] mul_data [8:0];   
    reg signed [19:0] sumdataval; 
    reg               mulvalid;
    integer i;

    always @(*) begin
        div_val = 5'd1; 
        case(SW)
            3'b000: begin // Identity (Raw)
                kernel[0]=0;  kernel[1]=0;  kernel[2]=0;
                kernel[3]=0;  kernel[4]=1;  kernel[5]=0;
                kernel[6]=0;  kernel[7]=0;  kernel[8]=0;
            end
            3'b001: begin // Box Blur 
                for(i=0; i<9; i=i+1) kernel[i] = 8'd1;
                div_val = 5'd9; // Sum is 9
            end
            3'b010: begin // -ve identity 
                kernel[0]=0;  kernel[1]=0;  kernel[2]=0;
                kernel[3]=0;  kernel[4]=-1;  kernel[5]=0;
                kernel[6]=0;  kernel[7]=0;  kernel[8]=0;
            end
            3'b011: begin // Sharpen
                kernel[0]= 0; kernel[1]=-1; kernel[2]= 0;
                kernel[3]=-1; kernel[4]= 5; kernel[5]=-1;
                kernel[6]= 0; kernel[7]=-1; kernel[8]= 0;
            end
            3'b100: begin // Edge Detection
                kernel[0]=-1; kernel[1]=-1; kernel[2]=-1;
                kernel[3]=-1; kernel[4]= 8; kernel[5]=-1;
                kernel[6]=-1; kernel[7]=-1; kernel[8]=-1;
            end
            3'b101: begin // Prewitt
                kernel[0]=-1; kernel[1]= 0; kernel[2]= 1;
                kernel[3]=-1; kernel[4]= 0; kernel[5]= 1;
                kernel[6]=-1; kernel[7]= 0; kernel[8]= 1;
            end
            3'b110: begin // Motion Blur
                kernel[0]= 0; kernel[1]= 0; kernel[2]= 1;
                kernel[3]= 0; kernel[4]= 1; kernel[5]= 0;
                kernel[6]= 1; kernel[7]= 0; kernel[8]= 0; 
                div_val = 5'd3;
            end
            3'b111: begin // Emboss
                kernel[0]=-2; kernel[1]=-1; kernel[2]= 0;
                kernel[3]=-1; kernel[4]= 1; kernel[5]= 1;
                kernel[6]= 0; kernel[7]= 1; kernel[8]= 2;
            end
        endcase
    end

    always @(posedge i_clk) begin
        for(i=0; i<9; i=i+1) begin
            mul_data[i] <= kernel[i] * $signed({1'b0, i_pixel_data[i*8+:8]});
        end 
        mulvalid <= i_pixel_data_valid;
        div_reg  <= div_val; 
    end

    always @(*) begin
        sumdataval = 20'sd0;
        for(i=0; i<9; i=i+1) begin
            sumdataval = sumdataval + mul_data[i];
        end
    end

    reg signed [19:0] div_result;
    always @(posedge i_clk) begin
        div_result = sumdataval / $signed({1'b0, div_reg});

        if (div_result > 20'sd255)
            o_convolved_data <= 8'hFF;
        else if (div_result < 20'sd0)
            o_convolved_data <= 8'h00;
        else
            o_convolved_data <= div_result[7:0];

        o_convolved_data_valid <= mulvalid;
    end

endmodule