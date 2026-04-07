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
        
    // Read from buffer (Output side to Convolution)
    always @(posedge clk) begin
        if(rst) 
            wrptr <= 10'd0;
        else if(rd_data) 
            wrptr <= (wrptr == 10'd639) ? 10'd0 : wrptr + 10'd1;
    end

//    // Safe Lookahead Logic (No Modulo %)
//    // This ensures we never read index 640 or 641
    wire [9:0] wr_p1 = (wrptr == 10'd639) ? 10'd0 : (wrptr + 10'd1);
    wire [9:0] wr_p2 = (wrptr == 10'd638) ? 10'd0 : 
                       (wrptr == 10'd639) ? 10'd1 : (wrptr + 10'd2);
                       
     assign o_data = {buffer[wr_p2] , buffer[wr_p1] , buffer[wrptr]}; // change order 
     

//   assign o_data = {buffer[wrptr] , buffer[(wrptr + 1) % 640] , buffer[(wrptr + 2) % 640]};

endmodule

//`timescale 1ns / 1ps

//module linebuffer (
//    input  wire        clk,
//    input  wire        rst,
//    input  wire [7:0]  i_data,
//    input  wire        data_valid,
//    output wire [23:0] o_data,
//    input  wire        rd_data
//);

//    reg [7:0] buffer [639:0]; 
//    reg [9:0] rdptr; 
//    reg [9:0] wrptr; 

//    // --- Write Logic (Input from Camera/Previous stage) ---
//    always @(posedge clk) begin
//        if(rst) 
//            rdptr <= 10'd0;
//        else if(data_valid) 
//            // Manual wrap at 639 to avoid expensive % math
//            rdptr <= (rdptr == 10'd639) ? 10'd0 : rdptr + 10'd1;
//    end

//    always @(posedge clk) begin
//        if(data_valid) 
//            buffer[rdptr] <= i_data;
//    end
        
//    // --- Read Logic (Output to Convolution) ---
//    always @(posedge clk) begin
//        if(rst) 
//            wrptr <= 10'd0;
//        else if(rd_data) 
//            wrptr <= (wrptr == 10'd639) ? 10'd0 : wrptr + 10'd1;
//    end

//    // --- Safe Lookahead Logic (3x3 Window) ---
//    // These wires calculate the neighbors for the convolution window
//    // and wrap back to 0 at the end of the line.
//    wire [9:0] wr_p1 = (wrptr == 10'd639) ? 10'd0 : (wrptr + 10'd1);
//    wire [9:0] wr_p2 = (wrptr == 10'd638) ? 10'd0 : 
//                       (wrptr == 10'd639) ? 10'd1 : (wrptr + 10'd2);

//    assign o_data = {buffer[wrptr], buffer[wr_p1], buffer[wr_p2]};

//endmodule

//`timescale 1ns / 1ps

//module linebuffer (
//    input  wire        clk,
//    input  wire        rst,
//    input  wire [7:0]  i_data,
//    input  wire        data_valid,
//    output wire [23:0] o_data,
//    input  wire        rd_data
//);

//    reg [7:0] buffer [639:0]; 
//    reg [9:0] rdptr; 
//    reg [9:0] wrptr; 

//    // Resetting pointers on 'rst' is critical to stop the "moving lines"
//    always @(posedge clk) begin
//        if(rst) 
//            rdptr <= 10'd0;
//        else if(data_valid) 
//            rdptr <= (rdptr == 10'd639) ? 10'd0 : rdptr + 10'd1;
//    end

//    always @(posedge clk) begin
//        if(data_valid) 
//            buffer[rdptr] <= i_data;
//    end
        
//    always @(posedge clk) begin
//        if(rst) 
//            wrptr <= 10'd0;
//        else if(rd_data) 
//            wrptr <= (wrptr == 10'd639) ? 10'd0 : wrptr + 10'd1;
//    end

//    // Use simple logic for the 3x3 window
//    wire [9:0] p1 = (wrptr == 10'd639) ? 10'd0 : wrptr + 1;
//    wire [9:0] p2 = (wrptr >= 10'd638) ? (wrptr - 10'd638) : wrptr + 2;

//    assign o_data = {buffer[wrptr], buffer[p1], buffer[p2]};

//endmodule