/*
    Verificador de señal 1.6TBASE-R 64B/66B y conversor a 1.6TMII
    Posee los siguientes contadores:
        -> Bloques de dato recibidos
        -> Bloques de control recibidos
        -> Bloques con un patron que no coincide con el especificado en
           los parametros
        -> Bloques con un formato que no satisface la norma
        -> Bloques con un sync header invalido
*/
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
    output logic                        o_valid                         // Valid signal for 257b checker
);

// MII Characters
localparam MII_IDLE  = 8'h07;
localparam MII_START = 8'hFB;
localparam MII_TERM  = 8'hFD;
localparam MII_ERROR = 8'hFE;
localparam MII_SEQ   = 8'h9C;

// Block Type identification
localparam C_TYPE = 3'd0;
localparam S_TYPE = 3'd1;
localparam T_TYPE = 3'd2;
localparam D_TYPE = 3'd3;
localparam E_TYPE = 3'd4;
logic [2:0] rx_type;
logic [2:0] next_rx_type;

// MII Data block
logic [DATA_WIDTH-1:0] txd;
logic [DATA_WIDTH-1:0] next_txd;
// MII Control block
logic [CTRL_WIDTH-1:0] txc;
logic [CTRL_WIDTH-1:0] next_txc;

// 66b blocks
logic [FRAME_WIDTH-1:0] rx_coded;
logic [1:0] addr;
logic valid;

// Total blocks counter
logic [31:0] block_count            ;
logic [31:0] next_block_count       ;
// Data blocks counter
logic [31:0] data_count             ;
logic [31:0] next_data_count        ;
// Ctrl blocks counter
logic [31:0] ctrl_count             ;
logic [31:0] next_ctrl_count        ;

// Total invalid blocks counter and flag
logic [31:0] inv_block_count        ;
logic [31:0] next_inv_block_count   ;
// Invalid pattern counter and flag
logic [31:0] inv_pattern_count      ;
logic [31:0] next_inv_pattern_count ;
// Invalid sync header counter and flag
logic [31:0] inv_sh_count           ;
logic [31:0] next_inv_sh_count      ;
// Invalid sequence counter and flag
logic [31:0] inv_format_count       ;
logic [31:0] next_inv_format_count  ;

always @(*) begin
    next_block_count = block_count + 1'b1;
    next_data_count = data_count;
    next_ctrl_count = ctrl_count;
    next_inv_block_count = inv_block_count;
    next_inv_format_count = inv_format_count;
    next_inv_pattern_count = inv_pattern_count;
    next_inv_sh_count = inv_sh_count;

    // 66b block formats
    if(rx_coded[HDR_WIDTH - 1 : 0] == 2'b01) begin
        // Control block
        next_ctrl_count = ctrl_count + 1'b1;

        case (rx_coded[HDR_WIDTH +: 8])
    
            // C7 C6 C5 C4 C3 C2 C1 C0
            8'h1E: begin
                if(rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 8] != {8{CTRL_CHAR_PATTERN}}) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end

                next_txd = rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 8];
                next_txc = 8'hFF;
                next_rx_type = C_TYPE;
            end
    
            // D7 D6 D5 D4 D3 D2 D1 S0
            8'h78: begin
                if(rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 8] != {7{DATA_CHAR_PATTERN}}) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end

                next_txd = {rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 8], MII_START};
                next_txc = 8'h01;
                next_rx_type = S_TYPE;
            end
    
            // Z7 Z6 Z5 Z4 D3 D2 D1 O0
            8'h4B: begin
                if(rx_coded[HDR_WIDTH + 8 +: 24] != {3{DATA_CHAR_PATTERN}}
                || rx_coded[HDR_WIDTH + 32 +: 4] != OSET_CHAR_PATTERN
                || rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 36] != '0) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end

                next_txd = {32'h0000_0000, rx_coded[HDR_WIDTH + 8 +: 24], MII_SEQ};
                next_txc = 8'hF1;
                next_rx_type = C_TYPE;
            end
    
            // C7 C6 C5 C4 C3 C2 C1 T0
            8'h87: begin
                if(rx_coded[HDR_WIDTH + 8 +: 7] != '0
                || rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 15] != {7{CTRL_CHAR_PATTERN}}) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end

                next_txd = {rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 15], MII_TERM};
                next_txc = 8'hFF;
                next_rx_type = T_TYPE;
            end
    
            // C7 C6 C5 C4 C3 C2 T1 D0
            8'h99: begin
                if(rx_coded[HDR_WIDTH + 8 +: 8] != DATA_CHAR_PATTERN
                || rx_coded[HDR_WIDTH + 16 +: 6] != '0
                || rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 22] != {6{CTRL_CHAR_PATTERN}}) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end

                next_txd = {rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 22], MII_TERM, rx_coded[HDR_WIDTH + 8 +: 8]};
                next_txc = 8'hFE;
                next_rx_type = T_TYPE;
            end
    
            // C7 C6 C5 C4 C3 T2 D1 D0
            8'hAA: begin
                if(rx_coded[HDR_WIDTH + 8 +: 16] != {2{DATA_CHAR_PATTERN}}
                || rx_coded[HDR_WIDTH + 22 +: 5] != '0
                || rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 27] != {5{CTRL_CHAR_PATTERN}}) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end
                
                next_txd = {rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 27], MII_TERM, rx_coded[HDR_WIDTH + 8 +: 16]};
                next_txc = 8'hFC;
                next_rx_type = T_TYPE;
            end
    
            // C7 C6 C5 C4 T3 D2 D1 D0
            8'hB4: begin
                if(rx_coded[HDR_WIDTH + 8 +: 24] != {3{DATA_CHAR_PATTERN}}
                || rx_coded[HDR_WIDTH + 32 +: 4] != '0
                || rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 36] != {4{CTRL_CHAR_PATTERN}}) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end

                next_txd = {rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 36], MII_TERM, rx_coded[HDR_WIDTH + 8 +: 24]};
                next_txc = 8'hF8;
                next_rx_type = T_TYPE;
            end
    
            // C7 C6 C5 T4 D3 D2 D1 D0
            8'hCC: begin
                if(rx_coded[HDR_WIDTH + 8 +: 32] != {4{DATA_CHAR_PATTERN}}
                || rx_coded[HDR_WIDTH + 40 +: 3] != '0
                || rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 43] != {3{CTRL_CHAR_PATTERN}}) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end

                next_txd = {rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 43], MII_TERM, rx_coded[HDR_WIDTH + 8 +: 32]};
                next_txc = 8'hF0;
                next_rx_type = T_TYPE;
            end
    
            // C7 C6 T5 D4 D3 D2 D1 D0
            8'hD2: begin
                if(rx_coded[HDR_WIDTH + 8 +: 40] != {5{DATA_CHAR_PATTERN}}
                || rx_coded[HDR_WIDTH + 48 +: 2] != '0
                || rx_coded[FRAME_WIDTH - 1 +: HDR_WIDTH + 50] != {2{CTRL_CHAR_PATTERN}}) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end

                next_txd = {rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 50], MII_TERM, rx_coded[HDR_WIDTH + 8 +: 40]};
                next_txc = 8'hE0;
                next_rx_type = T_TYPE;
            end
    
            // C7 T6 D5 D4 D3 D2 D1 D0
            8'hE1: begin
                if(rx_coded[HDR_WIDTH + 8 +: 48] != {6{DATA_CHAR_PATTERN}}
                || rx_coded[HDR_WIDTH + 56 +: 1] != '0
                || rx_coded[FRAME_WIDTH - 1 +: HDR_WIDTH + 57] != CTRL_CHAR_PATTERN      ) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end

                next_txd = {rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 57], MII_TERM, rx_coded[HDR_WIDTH + 8 +: 48]};
                next_txc = 8'hC0;
                next_rx_type = T_TYPE;
            end
    
            // T7 D6 D5 D4 D3 D2 D1 D0
            8'hFF: begin
                if(rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 8] != {7{DATA_CHAR_PATTERN}}) begin
                    next_inv_block_count = inv_block_count + 1'b1;
                    next_inv_pattern_count = inv_pattern_count + 1'b1;
                end 

                next_txd = {MII_TERM, rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 8]};
                next_txc = 8'h80;
                next_rx_type = T_TYPE;
            end
    
            // Invalid format
            default: begin
                next_inv_block_count = inv_block_count + 1'b1;
                next_inv_format_count = inv_format_count + 1'b1;

                next_txd = {8{MII_ERROR}};
                next_txc = 8'hFF;
                next_rx_type = E_TYPE;
            end
        endcase
        
    end
    else if(rx_coded[HDR_WIDTH - 1 : 0] == 2'b10) begin
        // Data block
        next_data_count = data_count + 1'b1;

        if(rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH] != {8{DATA_CHAR_PATTERN}}) begin
            next_inv_block_count = inv_block_count + 1'b1;
            next_inv_pattern_count = inv_pattern_count + 1'b1;
        end

        next_txd = rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH];
        next_txc = 8'h00;
        next_rx_type = D_TYPE;
    end
    else begin
        // Invalid sync header
        next_inv_block_count = inv_block_count + 1'b1;
        next_inv_sh_count = inv_sh_count + 1'b1;

        next_txd = {8{MII_ERROR}};
        next_txc = 8'hFF;
        next_rx_type = E_TYPE;
    end
end

always @(posedge clk or posedge i_rst) begin
    if(i_rst) begin
        // // Send Local Fault ordered set
        // o_txd <= {{7{8'h00}}, MII_SEQ};
        // o_txc <= 8'hF1; // Mismo valor que el generador

        txd <= '0;
        txc <= '0;

        block_count <= '0;
        data_count <= '0;
        ctrl_count <= '0;
        inv_block_count <= '0;
        inv_pattern_count <= '0;
        inv_format_count <= '0;
        inv_sh_count <= '0;
        
        valid <= '0;
        addr <= '0;
    end
    else begin
        // if(rx_coded(i) = E || rx_coded(i-1) = E) -> send EBLOCK_R
        if(rx_type == E_TYPE || next_rx_type == E_TYPE) begin
            txd <= {8{MII_ERROR}};
            txc <= 8'hFF;
        end
        else begin
            txd <= next_txd;
            txc <= next_txc;
        end
        rx_type <= next_rx_type;

        block_count <= next_block_count;
        data_count <= next_data_count;
        ctrl_count <= next_ctrl_count;
        inv_block_count <= next_inv_block_count;
        inv_pattern_count <= next_inv_pattern_count;
        inv_format_count <= next_inv_format_count;
        inv_sh_count <= next_inv_sh_count;
        
        case (addr)
            2'd0: begin
                rx_coded <= i_rx_coded_0;
                o_valid <= 1'b1;
            end
            2'd1: begin
                rx_coded <= i_rx_coded_1;
                o_valid <= 1'b0;
            end
            2'd2: 
                rx_coded <= i_rx_coded_2;
            2'd3: 
                rx_coded <= i_rx_coded_3;
        endcase

        addr <= addr + 1'b1;
    end
end

assign o_txd = txd;
assign o_txc = txc;
assign o_block_count = block_count;
assign o_ctrl_count = ctrl_count;
assign o_data_count = data_count;
assign o_inv_block_count = inv_block_count;
assign o_inv_format_count = inv_format_count;
assign o_inv_pattern_count = inv_pattern_count;
assign o_inv_sh_count = inv_sh_count;
assign o_valid = valid;

endmodule