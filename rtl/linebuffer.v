`timescale 1ns / 1ps

module linebuffer (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  i_data,
    input  wire        data_valid,
    output wire [23:0] o_data,
    input  wire        rd_data
);

    reg [7:0] buffer [639:0]; 
    reg [9:0] rdptr; 
    reg [9:0] wrptr; 

    // Write to buffer (Input side)
    always @(posedge clk) begin
        if(rst) 
            rdptr <= 10'd0;
        else if(data_valid) 
            rdptr <= (rdptr == 10'd639) ? 10'd0 : rdptr + 10'd1;
    end

    always @(posedge clk) begin
        if(data_valid) 
            buffer[rdptr] <= i_data;
    end
        
    always @(posedge clk) begin
        if(rst) 
            wrptr <= 10'd0;
        else if(rd_data) 
            wrptr <= (wrptr == 10'd639) ? 10'd0 : wrptr + 10'd1;
    end

    // This ensures we never read index 640 or 641
    wire [9:0] wr_p1 = (wrptr == 10'd639) ? 10'd0 : (wrptr + 10'd1);
    wire [9:0] wr_p2 = (wrptr == 10'd638) ? 10'd0 : 
                       (wrptr == 10'd639) ? 10'd1 : (wrptr + 10'd2);
                       
    assign o_data = {buffer[wr_p2] , buffer[wr_p1] , buffer[wrptr]}; 
     

endmodule
