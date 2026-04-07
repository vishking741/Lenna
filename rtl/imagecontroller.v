`timescale 1ns / 1ps

module imagecontroller (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  data,
    input  wire        datavalid,
    output reg  [71:0] o_data,      // 3x3 Window (9 pixels * 8 bits)
    output wire        o_datavalid,
    output reg         o_intr
);

    // Internal Registers and Wires
    reg [9:0]  pixel_counter;
    reg [1:0]  currentwrlinebuffer;
    reg [1:0]  currentrdlinebuffer;
    reg [9:0]  rd_counter;
    reg [11:0] total_counter; 
    reg        rd_line_buffer;
    reg        state;

    wire [23:0] lb0data, lb1data, lb2data, lb3data;
    reg  [3:0]  linebufferdatavalid;
    reg  [3:0]  linebufferrddata;

    localparam IDLE = 1'b0, RD = 1'b1;

    assign o_datavalid = rd_line_buffer;

    // --- Control Logic & State Machine ---

    // Tracks total pixels available across all buffers
    always @(posedge clk) begin
        if(rst) 
            total_counter <= 12'd0;
        else begin
            if(datavalid && !rd_line_buffer) 
                total_counter <= total_counter + 12'd1;
            else if(!datavalid && rd_line_buffer) 
                total_counter <= total_counter - 12'd1;
        end 
    end

    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
            rd_line_buffer <= 1'b0;
            o_intr <= 1'b0;
        end else begin
            case(state)
                IDLE : begin
                    o_intr <= 1'b0;
                    if(total_counter >= 12'd1920) begin // 3 full lines of 640
                        state <= RD;
                        rd_line_buffer <= 1'b1;
                    end
                end
                RD : begin
                    if(rd_counter == 10'd639) begin
                        state <= IDLE;
                        rd_line_buffer <= 1'b0;
                        o_intr <= 1'b1;
                    end
                end
            endcase
        end
    end

    // --- Writing Logic ---

    // FIX: Safely wrap pixel_counter back to 0 after 639
    always @(posedge clk) begin
        if(rst) 
            pixel_counter <= 10'd0;
        else if(datavalid) 
            pixel_counter <= (pixel_counter == 10'd639) ? 10'd0 : pixel_counter + 10'd1;
    end

    // FIX: 2-bit counter naturally wraps 0, 1, 2, 3, 0...
    always @(posedge clk) begin
        if(rst) 
            currentwrlinebuffer <= 2'd0;
        else if(pixel_counter == 10'd639 && datavalid)
            currentwrlinebuffer <= currentwrlinebuffer + 2'd1;
    end

    always @(*) begin
        linebufferdatavalid = 4'b0000;
        linebufferdatavalid[currentwrlinebuffer] = datavalid; 
    end

    // --- Reading Logic ---

    // FIX: Safely wrap rd_counter back to 0 after 639
    always @(posedge clk) begin
        if(rst) 
            rd_counter <= 10'd0;
        else if(rd_line_buffer) 
            rd_counter <= (rd_counter == 10'd639) ? 10'd0 : rd_counter + 10'd1;
    end

    // FIX: 2-bit counter naturally wraps 0, 1, 2, 3, 0...
    always @(posedge clk) begin
        if(rst) 
            currentrdlinebuffer <= 2'd0;
        else if(rd_counter == 10'd639 && rd_line_buffer) 
            currentrdlinebuffer <= currentrdlinebuffer + 2'd1;
    end

    // Data Routing Mux (Circular Selection)
    always @(*) begin
        case(currentrdlinebuffer)
            2'd0: o_data = {lb2data, lb1data, lb0data};
            2'd1: o_data = {lb3data, lb2data, lb1data};
            2'd2: o_data = {lb0data, lb3data, lb2data};
            2'd3: o_data = {lb1data, lb0data, lb3data};
            default: o_data = 72'h0;
        endcase
    end

    // Read Enable Signal Routing
    always @(*) begin
        case(currentrdlinebuffer)
            2'd0: linebufferrddata = {1'b0, 1'b1, 1'b1, 1'b1} & {4{rd_line_buffer}};
            2'd1: linebufferrddata = {1'b1, 1'b1, 1'b1, 1'b0} & {4{rd_line_buffer}};
            2'd2: linebufferrddata = {1'b1, 1'b1, 1'b0, 1'b1} & {4{rd_line_buffer}};
            2'd3: linebufferrddata = {1'b1, 1'b0, 1'b1, 1'b1} & {4{rd_line_buffer}};
            default: linebufferrddata = 4'b0000;
        endcase
    end

    // --- Line Buffer Instantiations ---

    linebuffer lb0 (.clk(clk), .rst(rst), .i_data(data), .data_valid(linebufferdatavalid[0]), .o_data(lb0data), .rd_data(linebufferrddata[0]));
    linebuffer lb1 (.clk(clk), .rst(rst), .i_data(data), .data_valid(linebufferdatavalid[1]), .o_data(lb1data), .rd_data(linebufferrddata[1]));
    linebuffer lb2 (.clk(clk), .rst(rst), .i_data(data), .data_valid(linebufferdatavalid[2]), .o_data(lb2data), .rd_data(linebufferrddata[2]));
    linebuffer lb3 (.clk(clk), .rst(rst), .i_data(data), .data_valid(linebufferdatavalid[3]), .o_data(lb3data), .rd_data(linebufferrddata[3]));

endmodule
