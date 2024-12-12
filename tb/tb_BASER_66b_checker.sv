`timescale 1ns/100ps

module BASER_66b_checker;
    /*
    *---------WIDTH---------
    */
    // 64/66b blocks
    parameter       DATA_WIDTH          = 64                        ;
    parameter       HDR_WIDTH           = 2                         ;
    parameter       FRAME_WIDTH         = DATA_WIDTH + HDR_WIDTH    ;
    // MII blocks
    parameter       CTRL_WIDTH          = DATA_WIDTH / 8            ;
    /*
    *------BLOCK TYPE-------
    */
    parameter       DATA_CHAR_PATTERN   = 8'hAA                     ;   // Data character
    // For Control characters, the standard specifies:
    // Idle:    0x00
    // Error:   0x1E
    parameter       CTRL_CHAR_PATTERN   = 7'h1E                     ;   // 7 BITS Control character
    parameter       OSET_CHAR_PATTERN   = 4'hF                      ;   // 4 BITS Ordered Set character
    /*
    *--------INPUTS---------
    */
    logic                        clk                         ;   // Clock input
    logic                        i_rst                       ;   // Asynchronous reset
    logic    [FRAME_WIDTH-1:0]   i_rx_coded_0                ;   // 1st 64b block
    logic    [FRAME_WIDTH-1:0]   i_rx_coded_1                ;   // 2nd 64b block
    logic    [FRAME_WIDTH-1:0]   i_rx_coded_2                ;   // 3rd 64b block
    logic    [FRAME_WIDTH-1:0]   i_rx_coded_3                ;   // 4th 64b block
    /*
    *--------OUTPUTS--------
    */
    logic    [DATA_WIDTH-1:0]    o_txd                       ;   // Output MII Data
    logic    [CTRL_WIDTH-1:0]    o_txc                       ;   // Output MII Control
    logic    [31:0]              o_block_count               ;   // Total number of 66b blocks received
    logic    [31:0]              o_data_count                ;   // Total number of 66b data blocks received
    logic    [31:0]              o_ctrl_count                ;   // Total number of 66b control blocks received
    logic    [31:0]              o_inv_block_count           ;   // Total number of invalid 66b blocks
    logic    [31:0]              o_inv_pattern_count         ;   // Total number of 66b blocks with invalid char pattern
    logic    [31:0]              o_inv_format_count          ;   // Total number of 66b blocks with invalid format
    logic    [31:0]              o_inv_sh_count              ;   // Total number of 66b blocks with invalid sync header

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        i_rst = 1'b1;
        i_rx_coded_0 = '0;
        i_rx_coded_1 = '0;
        i_rx_coded_2 = '0;
        i_rx_coded_3 = '0;

        #200;
        @(posedge clk);
        i_rx_coded_0 = 66'hA;
        i_rx_coded_1 = 66'hB;
        i_rx_coded_2 = 66'hC;
        i_rx_coded_3 = 66'hD;
        
        #200;
        @(posedge clk);
        i_rx_coded_0 = 66'hE;
        i_rx_coded_1 = 66'hF;
        i_rx_coded_2 = 66'h0;
        i_rx_coded_3 = 66'h1;
        
        #200;
        @(posedge clk);
        i_rx_coded_0 = 66'h2;
        i_rx_coded_1 = 66'h3;
        i_rx_coded_2 = 66'h4;
        i_rx_coded_3 = 66'h5;
        
        #200;
        @(posedge clk);
        $finish;
    end


    BASER_257b_checker #(
        .DATA_WIDTH(DATA_WIDTH),
        .HDR_WIDTH(HDR_WIDTH),
        .FRAME_WIDTH(FRAME_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .DATA_CHAR_PATTERN(DATA_CHAR_PATTERN),
        .CTRL_CHAR_PATTERN(CTRL_CHAR_PATTERN),
        .OSET_CHAR_PATTERN(OSET_CHAR_PATTERN)
    ) dut (
        .i_rst(i_rst),
        .i_rx_coded_0(i_rx_coded_0),
        .i_rx_coded_1(i_rx_coded_1),
        .i_rx_coded_2(i_rx_coded_2),
        .i_rx_coded_3(i_rx_coded_3),
        .o_txd(o_txd),
        .o_txc(o_txc),
        .o_block_count(o_block_count),
        .o_data_count(o_data_count),
        .o_ctrl_count(o_ctrl_count),
        .o_inv_block_count(o_inv_block_count),
        .o_inv_pattern_count(o_inv_pattern_count),
        .o_inv_format_count(o_inv_format_count),
        .o_inv_sh_count(o_inv_sh_count)
    );

endmodule