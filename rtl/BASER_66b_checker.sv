/*
    Verificador de señal 1.6TBASE-R 64B/66B y conversor a 1.6TMII
    Posee los siguientes contadores:
        -> Bloques de dato recibidos
        -> Bloques de control recibidos
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
    parameter       CTRL_CHAR_PATTERN   = 7'h00                     ,   // 7 BITS Control character
    parameter       OSET_CHAR_PATTERN   = 4'hB                          // 4 BITS Ordered Set character
)
(
    /*
    *--------INPUTS---------
    */
    input  logic                        clk                         ,   // Clock input
    input  logic                        i_rst                       ,   // Asynchronous reset
    input  logic    [FRAME_WIDTH-1:0]   i_rx_coded                ,   // 64b block
    /*
    *--------OUTPUTS--------
    */
    output logic    [DATA_WIDTH-1:0]    o_txd                       ,   // Output MII Data
    output logic    [CTRL_WIDTH-1:0]    o_txc                       ,   // Output MII Control

    output logic    [31:0]              o_block_count               ,   // Total number of 66b blocks received
    output logic    [31:0]              o_data_count                ,   // Total number of 66b data blocks received
    output logic    [31:0]              o_ctrl_count                ,   // Total number of 66b control blocks received
    output logic    [31:0]              o_inv_block_count           ,   // Total number of invalid 66b blocks
    output logic    [31:0]              o_inv_sh_count                  // Total number of 66b blocks with invalid sync header
);

// MII Characters
localparam MII_IDLE  = 8'h07;
localparam MII_ERROR = 8'hFE;
localparam MII_START = 8'hFB;
localparam MII_TERM  = 8'hFD;
localparam MII_SEQ   = 8'h9C;

// BASE-R Characters
localparam CTRL_IDLE  = 7'h00;
localparam CTRL_ERROR = 7'h1E;

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
// Invalid sync header counter and flag
logic [31:0] inv_sh_count           ;
logic [31:0] next_inv_sh_count      ;

always @(*) begin
    next_block_count = block_count + 1'b1;
    next_data_count = data_count;
    next_ctrl_count = ctrl_count;
    next_inv_block_count = inv_block_count;
    next_inv_sh_count = inv_sh_count;

    // 66b block formats
    if(i_rx_coded[HDR_WIDTH - 1 : 0] == 2'b01) begin
        // Control block
        next_ctrl_count = ctrl_count + 1'b1;

        case (i_rx_coded[HDR_WIDTH +: 8])
    
            // C7 C6 C5 C4 C3 C2 C1 C0
            8'h1E: begin
                if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 8] == {8{CTRL_IDLE}}) begin
                    next_txd = {8{MII_IDLE}};
                end
                else if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 8] == {8{CTRL_ERROR}}) begin
                    next_txd = {8{MII_ERROR}};
                end
                else begin
                    next_txd = {8{MII_ERROR}};
                end

                next_txc = 8'hFF;
                // next_rx_type = C_TYPE;
            end
    
            // D7 D6 D5 D4 D3 D2 D1 S0
            8'h78: begin
                next_txd = {i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 8], MII_START};
                next_txc = 8'h01;
                // next_rx_type = S_TYPE;
            end
    
            // Z7 Z6 Z5 Z4 D3 D2 D1 O0
            8'h4B: begin
                next_txd = {32'h0000_0000, i_rx_coded[HDR_WIDTH + 8 +: 24], MII_SEQ};
                next_txc = 8'hF1;
                // next_rx_type = C_TYPE;
            end
    
            // C7 C6 C5 C4 C3 C2 C1 T0
            8'h87: begin
                next_txd[7 : 0] = MII_TERM;

                if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 15] == {7{CTRL_IDLE}}) begin
                    next_txd[DATA_WIDTH-1 : 8] = {7{MII_IDLE}};
                end
                else if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 15] == {7{CTRL_ERROR}}) begin
                    next_txd[DATA_WIDTH-1 : 8] = {7{MII_ERROR}};
                end
                else begin
                    next_txd[DATA_WIDTH-1 : 8] = {7{MII_ERROR}};
                end

                next_txc = 8'hFF;
                // next_rx_type = T_TYPE;
            end
    
            // C7 C6 C5 C4 C3 C2 T1 D0
            8'h99: begin
                next_txd[15 : 0] = {MII_TERM, i_rx_coded[HDR_WIDTH + 8 +: 8]};

                if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 22] == {6{CTRL_IDLE}}) begin
                    next_txd[DATA_WIDTH-1 : 16] = {6{MII_IDLE}};
                end
                else if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 22] == {6{CTRL_ERROR}}) begin
                    next_txd[DATA_WIDTH-1 : 16] = {6{MII_ERROR}};
                end
                else begin
                    next_txd[DATA_WIDTH-1 : 16] = {6{MII_ERROR}};
                end

                next_txc = 8'hFE;
                // next_rx_type = T_TYPE;
            end
    
            // C7 C6 C5 C4 C3 T2 D1 D0
            8'hAA: begin
                next_txd[23 : 0] = {MII_TERM, i_rx_coded[HDR_WIDTH + 8 +: 16]};

                if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 27] == {5{CTRL_IDLE}}) begin
                    next_txd[DATA_WIDTH-1 : 24] = {5{MII_IDLE}};
                end
                else if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 27] == {5{CTRL_ERROR}}) begin
                    next_txd[DATA_WIDTH-1 : 24] = {5{MII_ERROR}};
                end
                else begin
                    next_txd[DATA_WIDTH-1 : 24] = {5{MII_ERROR}};
                end
                
                next_txc = 8'hFC;
                // next_rx_type = T_TYPE;
            end
    
            // C7 C6 C5 C4 T3 D2 D1 D0
            8'hB4: begin
                next_txd[31 : 0] = {MII_TERM, i_rx_coded[HDR_WIDTH + 8 +: 24]};

                if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 36] == {4{CTRL_IDLE}}) begin
                    next_txd[DATA_WIDTH-1 : 32] = {4{MII_IDLE}};
                end
                else if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 36] == {4{CTRL_ERROR}}) begin
                    next_txd[DATA_WIDTH-1 : 32] = {4{MII_ERROR}};
                end
                else begin
                    next_txd[DATA_WIDTH-1 : 32] = {4{MII_ERROR}};
                end
                
                next_txc = 8'hF8;
                // next_rx_type = T_TYPE;
            end
    
            // C7 C6 C5 T4 D3 D2 D1 D0
            8'hCC: begin
                next_txd[39 : 0] = {MII_TERM, i_rx_coded[HDR_WIDTH + 8 +: 32]};

                if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 40] == {3{CTRL_IDLE}}) begin
                    next_txd[DATA_WIDTH-1 : 40] = {3{MII_IDLE}};
                end
                else if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 40] == {3{CTRL_ERROR}}) begin
                    next_txd[DATA_WIDTH-1 : 40] = {3{MII_ERROR}};
                end
                else begin
                    next_txd[DATA_WIDTH-1 : 40] = {3{MII_ERROR}};
                end
                
                next_txc = 8'hF0;
                // next_rx_type = T_TYPE;
            end
    
            // C7 C6 T5 D4 D3 D2 D1 D0
            8'hD2: begin
                next_txd[47 : 0] = {MII_TERM, i_rx_coded[HDR_WIDTH + 8 +: 40]};

                if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 48] == {2{CTRL_IDLE}}) begin
                    next_txd[DATA_WIDTH-1 : 48] = {2{MII_IDLE}};
                end
                else if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 48] == {2{CTRL_ERROR}}) begin
                    next_txd[DATA_WIDTH-1 : 48] = {2{MII_ERROR}};
                end
                else begin
                    next_txd[DATA_WIDTH-1 : 48] = {2{MII_ERROR}};
                end

                next_txc = 8'hE0;
                // next_rx_type = T_TYPE;
            end
    
            // C7 T6 D5 D4 D3 D2 D1 D0
            8'hE1: begin
                next_txd[55 : 0] = {MII_TERM, i_rx_coded[HDR_WIDTH + 8 +: 48]};

                if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 56] == CTRL_IDLE) begin
                    next_txd[DATA_WIDTH-1 : 56] = MII_IDLE;
                end
                else if(i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH + 27] == CTRL_ERROR) begin
                    next_txd[DATA_WIDTH-1 : 56] = MII_ERROR;
                end
                else begin
                    next_txd[DATA_WIDTH-1 : 56] = MII_ERROR;
                end

                next_txc = 8'hC0;
                // next_rx_type = T_TYPE;
            end
    
            // T7 D6 D5 D4 D3 D2 D1 D0
            8'hFF: begin
                next_txd = {MII_TERM, i_rx_coded[HDR_WIDTH + 8 +: 56]};
                next_txc = 8'h80;
                // next_rx_type = T_TYPE;
            end
    
            // Invalid format
            default: begin
                next_txd = {8{MII_ERROR}};
                next_txc = 8'hFF;
                // next_rx_type = E_TYPE;
            end
        endcase
        
    end
    else if(i_rx_coded[HDR_WIDTH - 1 : 0] == 2'b10) begin
        // Data block
        next_data_count = data_count + 1'b1;

        next_txd = i_rx_coded[FRAME_WIDTH - 1 : HDR_WIDTH];
        next_txc = 8'h00;
        // next_rx_type = D_TYPE;
    end
    else begin
        // Invalid sync header
        next_inv_block_count = inv_block_count + 1'b1;
        next_inv_sh_count = inv_sh_count + 1'b1;

        next_txd = {8{MII_ERROR}};
        next_txc = 8'hFF;
        // next_rx_type = E_TYPE;
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
        inv_sh_count <= '0;
    end
    else begin
        // // if(i_rx_coded(i) = E || i_rx_coded(i-1) = E) -> send EBLOCK_R
        // if(rx_type == E_TYPE || next_rx_type == E_TYPE) begin
        //     txd <= {8{MII_ERROR}};
        //     txc <= 8'hFF;
        // end
        // else begin
        //     txd <= next_txd;
        //     txc <= next_txc;
        // end
        txd <= next_txd;
        txc <= next_txc;

        rx_type <= next_rx_type;

        block_count <= next_block_count;
        data_count <= next_data_count;
        ctrl_count <= next_ctrl_count;
        inv_block_count <= next_inv_block_count;
        inv_sh_count <= next_inv_sh_count;
    end
end

assign o_txd = txd;
assign o_txc = txc;
assign o_block_count = block_count;
assign o_ctrl_count = ctrl_count;
assign o_data_count = data_count;
assign o_inv_block_count = inv_block_count;
assign o_inv_sh_count = inv_sh_count;

endmodule