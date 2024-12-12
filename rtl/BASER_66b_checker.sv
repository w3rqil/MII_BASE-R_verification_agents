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
    parameter       OSET_CHAR_PATTERN   = 4'hB                          // 4 BITS Ordered Set character
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
    output logic    [31:0]              o_inv_sh_count              ,   // Total number of 66b blocks with invalid sync header
    output logic                        o_valid
);

// MII blocks
logic [DATA_WIDTH-1:0] next_txd;
logic [CTRL_WIDTH-1:0] next_txc;

// 66b blocks
logic [FRAME_WIDTH-1:0] rx_coded;
logic [FRAME_WIDTH-1:0] next_rx_coded;
logic [1:0] addr;

logic [31:0] next_block_count;
logic [31:0] next_data_count;
logic [31:0] next_ctrl_count;
logic [31:0] next_inv_block_count;
logic [31:0] next_inv_pattern_count;
logic [31:0] next_inv_format_count;
logic [31:0] next_inv_sh_count;

always @(*) begin
    // 66b block formats
    if(next_rx_coded[1:0] == 2'b01) begin
        // Control block
        case (next_rx_coded[9:2])
    
            // C7 C6 C5 C4 C3 C2 C1 C0
            8'h1E: begin
            end
    
            // D7 D6 D5 D4 D3 D2 D1 S0
            8'h78: begin
            end
    
            // Z7 Z6 Z5 Z4 D3 D2 D1 O0
            8'h4B: begin
            end
    
            // C7 C6 C5 C4 C3 C2 C1 T0
            8'h87: begin
            end
    
            // C7 C6 C5 C4 C3 C2 T1 D0
            8'h99: begin
            end
    
            // C7 C6 C5 C4 C3 T2 D1 D0
            8'hAA: begin
            end
    
            // C7 C6 C5 C4 T3 D2 D1 D0
            8'hB4: begin
            end
    
            // C7 C6 C5 T4 D3 D2 D1 D0
            8'hCC: begin
            end
    
            // C7 C6 T5 D4 D3 D2 D1 D0
            8'hD2: begin
            end
    
            // C7 T6 D5 D4 D3 D2 D1 D0
            8'hE1: begin
            end
    
            // T7 D6 D5 D4 D3 D2 D1 D0
            8'hFF: begin
            end 
    
            // Invalid format
            default: begin
            end
        endcase
        
    end
    else if(next_rx_coded[1:0] == 2'b10) begin
        // Data block
    end
    else begin
        // Invalid sync header
    end
end

always @(posedge clk or posedge i_rst) begin
    if(i_rst) begin
        // Send Local Fault ordered set
        o_txd <= 64'h0000_0000_0000_009C;
        o_txc <= 8'hF1;

        o_block_count <= '0;
        o_data_count <= '0;
        o_ctrl_count <= '0;
        o_inv_block_count <= '0;
        o_inv_pattern_count <= '0;
        o_inv_format_count <= '0;
        o_inv_sh_count <= '0;
        
        o_valid <= '0;
        rx_coded <= '0;
        addr <= '0;
    end
    else begin
        // if(rx_coded = E || next_rx_coded = E) -> send EBLOCK_R

        o_block_count <= next_block_count;
        o_data_count <= next_data_count;
        o_ctrl_count <= next_ctrl_count;
        o_inv_block_count <= next_inv_block_count;
        o_inv_pattern_count <= next_inv_pattern_count;
        o_inv_format_count <= next_inv_format_count;
        o_inv_sh_count <= next_inv_sh_count;
        
        rx_coded <= next_rx_coded;
        case (addr)
            2'd0: begin
                next_rx_coded <= i_rx_coded_0;
                o_valid <= 1'b1;
            end
            2'd1: begin
                next_rx_coded <= i_rx_coded_1;
                o_valid <= 1'b0;
            end
            2'd2: 
                next_rx_coded <= i_rx_coded_2;
            2'd3: 
                next_rx_coded <= i_rx_coded_3;
        endcase

        addr = addr + 1'b1;
    end
end

assign o_txd = next_rx_coded[FRAME_WIDTH-1:2];
assign o_txc = {6'h0, next_rx_coded[1:0]};

endmodule