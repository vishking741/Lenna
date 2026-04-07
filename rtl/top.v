module top
    (   input wire i_top_clk,
        input wire i_top_rst,
        
        input wire  i_top_cam_start, 
        output wire o_top_cam_done, 
        
        input  wire [14:0] SW, 
        
        // I/O to camera
        input wire       i_top_pclk, 
        input wire [7:0] i_top_pix_byte,
        input wire       i_top_pix_vsync,
        input wire       i_top_pix_href,
        output wire      o_top_reset,
        output wire      o_top_pwdn,
        output wire      o_top_xclk,
        output wire      o_top_siod,
        output wire      o_top_sioc,
        
        // I/O to VGA 
        output wire [3:0] o_top_vga_red,
        output wire [3:0] o_top_vga_green,
        output wire [3:0] o_top_vga_blue,
        output wire       o_top_vga_vsync,
        output wire       o_top_vga_hsync
    );
    
    // --- Internal Wires ---
    wire [11:0] raw_cam_data;
    wire        raw_cam_wr;
    
    wire [11:0] proc_pix_data;
    wire [18:0] proc_pix_addr;
    wire        proc_pix_wr;

    wire [11:0] o_bram_pix_data;
    wire [18:0] o_bram_pix_addr; 
            
    // Reset synchronizers
    reg r1_rstn_top_clk,    r2_rstn_top_clk;
    reg r1_rstn_pclk,       r2_rstn_pclk;
    reg r1_rstn_clk25m,     r2_rstn_clk25m; 
    wire w_clk25m; 
    
    clk_wiz_1 clock_gen (
        .clk_in1(i_top_clk),
        .clk_out1(w_clk25m),
        .clk_out2(o_top_xclk)
    );
    
    wire w_rst_btn_db; 
    localparam DELAY_TOP_TB = 240_000; 
    debouncer #( .DELAY(DELAY_TOP_TB) ) top_btn_db (
        .i_clk(i_top_clk),
        .i_btn_in(~i_top_rst),
        .o_btn_db(w_rst_btn_db)
    ); 
    
    always @(posedge i_top_clk or negedge w_rst_btn_db) begin
        if(!w_rst_btn_db) {r2_rstn_top_clk, r1_rstn_top_clk} <= 0; 
        else              {r2_rstn_top_clk, r1_rstn_top_clk} <= {r1_rstn_top_clk, 1'b1}; 
    end 
    always @(posedge w_clk25m or negedge w_rst_btn_db) begin
        if(!w_rst_btn_db) {r2_rstn_clk25m, r1_rstn_clk25m} <= 0; 
        else              {r2_rstn_clk25m, r1_rstn_clk25m} <= {r1_rstn_clk25m, 1'b1}; 
    end
    always @(posedge i_top_pclk or negedge w_rst_btn_db) begin
        if(!w_rst_btn_db) {r2_rstn_pclk, r1_rstn_pclk} <= 0; 
        else              {r2_rstn_pclk, r1_rstn_pclk} <= {r1_rstn_pclk, 1'b1}; 
    end 
    
    // --- 1. FPGA-Camera Interface ---
    cam_top #( .CAM_CONFIG_CLK(100_000_000) ) OV7670_cam (
        .i_clk(i_top_clk),
        .i_rstn_clk(r2_rstn_top_clk),
        .i_rstn_pclk(r2_rstn_pclk),
        .i_cam_start(i_top_cam_start),
        .o_cam_done(o_top_cam_done), 
        .i_pclk(i_top_pclk),
        .i_pix_byte(i_top_pix_byte), 
        .i_vsync(i_top_pix_vsync), 
        .i_href(i_top_pix_href),
        .o_reset(o_top_reset),
        .o_pwdn(o_top_pwdn),
        .o_siod(o_top_siod),
        .o_sioc(o_top_sioc), 
        .o_pix_wr(raw_cam_wr),          // Captured write enable
        .o_pix_data(raw_cam_data),      // Captured 12-bit data
        .o_pix_addr()                   // Address ignored; wrapper re-generates it
    );

    // --- 2. Image Processing Wrapper (The New Block) ---
    image_processing_wrapper process (
        .i_pclk(i_top_pclk),
        .i_rstn_pclk(r2_rstn_pclk),
        .i_vsync(i_top_pix_vsync),
        .i_href(i_top_pix_href),
        .i_cam_wr(raw_cam_wr),
        .i_cam_data(raw_cam_data),
        .SW(SW[14:0]),
        .o_bram_wr(proc_pix_wr),        // Delayed signals to BRAM
        .o_bram_addr(proc_pix_addr),
        .o_bram_data(proc_pix_data)
    );
    
    // --- 3. BRAM Frame Buffer ---
    mem_bram #( .WIDTH(12), .DEPTH(640*480) ) pixel_memory (
        .i_wclk(i_top_pclk),
        .i_wr(proc_pix_wr),             // Use processed write enable
        .i_wr_addr(proc_pix_addr),      // Use processed address
        .i_bram_data(proc_pix_data),    // Use processed data
        .i_bram_en(1'b1),
        .i_rclk(w_clk25m),
        .i_rd(1'b1),
        .i_rd_addr(o_bram_pix_addr), 
        .o_bram_data(o_bram_pix_data)
    );
     
    // --- 4. VGA Interface ---
    wire X, Y;
    vga_top display_interface (
        .i_clk25m(w_clk25m),
        .i_rstn_clk25m(r2_rstn_clk25m), 
        .o_VGA_x(X),
        .o_VGA_y(Y), 
        .o_VGA_vsync(o_top_vga_vsync),
        .o_VGA_hsync(o_top_vga_hsync), 
        .o_VGA_video(),
        .o_VGA_red(o_top_vga_red),
        .o_VGA_green(o_top_vga_green),
        .o_VGA_blue(o_top_vga_blue), 
        .i_pix_data(o_bram_pix_data), 
        .o_pix_addr(o_bram_pix_addr)
    );
    
endmodule
