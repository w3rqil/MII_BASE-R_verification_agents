`timescale 1ns/100ps

module BASER_66b_checker
#(
    /*
    *---------WIDTH---------
    */
    // 64/66b blocks
    parameter       DATA_WIDTH          = 64                        ,
    parameter       HDR_WIDTH           = 2                         ,
    parameter       FRAME_WIDTH         = DATA_WIDTH + HDR_WIDTH    ,
    // MII blocks
    parameter       CTRL_WIDTH          = DATA_WIDTH / 8            ,
    /*
    *------BLOCK TYPE-------
    */
    parameter       DATA_CHAR_PATTERN   = 8'hAA                     ,   // Data character
    // For Control characters, the standard specifies:
    // Idle:    0x00
    // Error:   0x1E
    parameter       CTRL_CHAR_PATTERN   = 7'h1E                     ,   // 7 BITS Control character
    parameter       OSET_CHAR_PATTERN   = 4'hF                          // 4 BITS Ordered Set character
)
(
    /*
    *--------INPUTS---------
    */
    input  logic                        clk                         ,   // Clock input
    input  logic                        i_rst                       ,   // Asynchronous reset
    input  logic    [FRAME_WIDTH-1:0]   i_rx_coded_0                ,   // 1st 64b block
    input  logic    [FRAME_WIDTH-1:0]   i_rx_coded_1                ,   // 2nd 64b block
    input  logic    [FRAME_WIDTH-1:0]   i_rx_coded_2                ,   // 3rd 64b block
    input  logic    [FRAME_WIDTH-1:0]   i_rx_coded_3                ,   // 4th 64b block
    /*
    *--------OUTPUTS--------
    */
    output logic    [DATA_WIDTH-1:0]    o_txd                       ,   // Output MII Data
    output logic    [CTRL_WIDTH-1:0]    o_txc                       ,   // Output MII Control
    output logic    [31:0]              o_block_count               ,   // Total number of 66b blocks received
    output logic    [31:0]              o_data_count                ,   // Total number of 66b data blocks received
    output logic    [31:0]              o_ctrl_count                ,   // Total number of 66b control blocks received
    output logic    [31:0]              o_inv_block_count           ,   // Total number of invalid 66b blocks
    output logic    [31:0]              o_inv_pattern_count         ,   // Total number of 66b blocks with invalid char pattern
    output logic    [31:0]              o_inv_format_count          ,   // Total number of 66b blocks with invalid format
    output logic    [31:0]              o_inv_sh_count                  // Total number of 66b blocks with invalid sync header
);

// 66b blocks FIFO
logic [FRAME_WIDTH-1:0] rx_coded;
logic [1:0] addr;

always @(posedge clk or posedge i_rst) begin
    if(i_rst) begin
        rx_coded <= '0;
        addr <= '0;
    end
    else begin
        case (addr)
            2'd0: 
                rx_coded <= i_rx_coded_0;
            2'd1: 
                rx_coded <= i_rx_coded_1;
            2'd2: 
                rx_coded <= i_rx_coded_2;
            2'd3: 
                rx_coded <= i_rx_coded_3;
        endcase

        addr = addr + 1'b1;
    end
end

endmodule