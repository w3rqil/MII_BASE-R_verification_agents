`timescale 1ns/100ps

module BASER_257b_checker
#(
    /*
    *---------WIDTH---------
    */
    // 64/66b blocks
    parameter int   DATA_WIDTH          = 64                            ,
    parameter int   HDR_WIDTH           = 2                             ,
    parameter int   FRAME_WIDTH         = DATA_WIDTH + HDR_WIDTH        ,
    // 256/257b blocks
    parameter int   TC_DATA_WIDTH       = 4 * DATA_WIDTH                ,   // Without header
    parameter int   TC_HDR_WIDTH        = 1                             ,   // 1 bit sync header
    parameter int   TC_WIDTH            = TC_DATA_WIDTH + TC_HDR_WIDTH  ,
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
    input  logic                        clk                 ,   // Clock input
    input  logic                        i_rst               ,   // Asynchronous reset
    input  logic    [TC_WIDTH-1:0]      i_rx_xcoded         ,   // Received data
    /*
    *--------OUTPUTS--------
    */
    output logic    [FRAME_WIDTH-1:0]   o_rx_coded_0        ,   // 1st 64b block
    output logic    [FRAME_WIDTH-1:0]   o_rx_coded_1        ,   // 2nd 64b block
    output logic    [FRAME_WIDTH-1:0]   o_rx_coded_2        ,   // 3rd 64b block
    output logic    [FRAME_WIDTH-1:0]   o_rx_coded_3        ,   // 4th 64b block
    output logic    [31:0]              o_block_count       ,   // Total number of 257b blocks received
    output logic    [31:0]              o_data_count        ,   // Total number of 257b blocks with all 64b data block received
    output logic    [31:0]              o_ctrl_count        ,   // Total number of 257b blocks with at least one 64b control block received
    output logic    [31:0]              o_inv_block_count       // Total number of invalid blocks
);

    // 1st 64b block
    logic [FRAME_WIDTH-1:0] rx_coded_0      ;
    logic [FRAME_WIDTH-1:0] next_rx_coded_0 ;
    // 2nd 64b block
    logic [FRAME_WIDTH-1:0] rx_coded_1      ;
    logic [FRAME_WIDTH-1:0] next_rx_coded_1 ;
    // 3rd 64b block
    logic [FRAME_WIDTH-1:0] rx_coded_2      ;
    logic [FRAME_WIDTH-1:0] next_rx_coded_2 ;
    // 4th 64b block
    logic [FRAME_WIDTH-1:0] rx_coded_3      ;
    logic [FRAME_WIDTH-1:0] next_rx_coded_3 ;

    // Payload of the four 64b blocks
    logic [TC_DATA_WIDTH-1:0] rx_payloads   ;
    logic [TC_DATA_WIDTH-1:0] next_rx_payloads   ;

    // Total blocks counter
    logic [31:0] block_count            ;
    logic [31:0] next_block_count       ;
    // Data blocks counter
    logic [31:0] data_count             ;
    logic [31:0] next_data_count        ;
    // Ctrl blocks counter
    logic [31:0] ctrl_count             ;
    logic [31:0] next_ctrl_count        ;
    // Total invalid blocks counter
    logic [31:0] inv_block_count        ;
    logic [31:0] next_inv_block_count   ;


    /* More counters to use later */

    // Invalid data blocks counter
    logic [31:0] inv_data_block_count;
    logic [31:0] next_inv_data_block_count;
    // Invalid ctrl blocks counter
    logic [31:0] inv_ctrl_block_count;
    logic [31:0] next_inv_ctrl_block_count;
    // Invalid sync header counter
    logic [31:0] inv_sh_count;
    logic [31:0] next_inv_sh_count;
    // Invalid sequence counter
    logic [31:0] inv_sequence_count;
    logic [31:0] next_inv_sequence_count;

    
    // Flag of first 64b ctrl block received in the 257b block
    logic        first_ctrl_block_flag;
    // Flag of invalid 64b block detected
    logic        inv_block_flag;

    always @(*) begin
        // Increase total block counter every clock positive edge
        next_block_count = block_count + 'd1;
        first_ctrl_block_flag = 1'b0;
        inv_block_flag = 1'b0;

        // Detected all data blocks
        if(i_rx_xcoded[0]) begin
            // Increase data block counter
            next_data_count = data_count + 'd1;
            next_ctrl_count = ctrl_count;

            // Valid block verification logic
            if(i_rx_xcoded[1 +: TC_DATA_WIDTH] != {32{DATA_CHAR_PATTERN}}) begin
                inv_block_flag = 1'b1;
            end

            // Assign the next four 64b blocks
            next_rx_coded_0 = {i_rx_xcoded[    DATA_WIDTH :                  TC_HDR_WIDTH], 2'b10};
            next_rx_coded_1 = {i_rx_xcoded[2 * DATA_WIDTH :     DATA_WIDTH + TC_HDR_WIDTH], 2'b10};
            next_rx_coded_2 = {i_rx_xcoded[3 * DATA_WIDTH : 2 * DATA_WIDTH + TC_HDR_WIDTH], 2'b10};
            next_rx_coded_3 = {i_rx_xcoded[4 * DATA_WIDTH : 3 * DATA_WIDTH + TC_HDR_WIDTH], 2'b10};
        end

        // Detected at least one ctrl block
        else begin
            // Increase control block counter
            next_data_count = data_count;
            next_ctrl_count = ctrl_count + 'd1;

            // If there's Not a sync header '0' and next 4 bits '1111'
            if(i_rx_xcoded[4:1] != 4'b1111) begin

                // Analize the four 64b frames
                for(int i = 0; i < 4; i++) begin
    
                    // Data frame
                    if(i_rx_xcoded[i+1]) begin
    
                        // There is no ctrl frame found yet
                        if(first_ctrl_block_flag == 1'b0) begin
    
                            // The frame has to be all Data characters
                            if(i_rx_xcoded[5 + DATA_WIDTH * i +: DATA_WIDTH] != {8{DATA_CHAR_PATTERN}}) begin
                                inv_block_flag = 1'b1;
                            end
    
                            next_rx_payloads[DATA_WIDTH * i +: DATA_WIDTH] = i_rx_xcoded[5 + DATA_WIDTH * i +: DATA_WIDTH];
                        end
    
                        // There is a ctrl frame found before
                        else begin
    
                            // The frame has to be all Data characters
                            if(i_rx_xcoded[1 + DATA_WIDTH * i +: DATA_WIDTH] != {8{DATA_CHAR_PATTERN}}) begin
                                inv_block_flag = 1'b1;
                            end
                            
                            next_rx_payloads[DATA_WIDTH * i +: DATA_WIDTH] = i_rx_xcoded[1 + DATA_WIDTH * i +: DATA_WIDTH];
                        end
                    end
    
                    // Ctrl frame
                    else begin
    
                        // It is the first ctrl frame found
                        if(first_ctrl_block_flag == 1'b0) begin
                            first_ctrl_block_flag = 1'b1;
    
                            // Ctrl frame formats
                            case (i_rx_xcoded[5 + DATA_WIDTH * i +: 4])
    
                                // C7 C6 C5 C4 C3 C2 C1 C0
                                4'h1: begin
                                    if(i_rx_xcoded[9 + DATA_WIDTH * i +: 56] != {8{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                    
                                    // Assign missing block type nibble
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'hE;
                                end
    
                                // D7 D6 D5 D4 D3 D2 D1 S0
                                4'h7: begin
                                    if(i_rx_xcoded[9 + DATA_WIDTH * i +: 56] != {7{DATA_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'h8;
                                end
    
                                // Z7 Z6 Z5 Z4 D3 D2 D1 O0
                                4'h4: begin
                                    if(i_rx_xcoded[9  + DATA_WIDTH * i +: 24] != {3{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[33 + DATA_WIDTH * i +:  4] != OSET_CHAR_PATTERN
                                    || i_rx_xcoded[37 + DATA_WIDTH * i +: 28] != '0                      ) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'hB;
                                end
    
                                // C7 C6 C5 C4 C3 C2 C1 T0
                                4'h8: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +:  7] != '0
                                    || i_rx_xcoded[16 + DATA_WIDTH * i  +: 49] != {7{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'h7;
                                end
    
                                // C7 C6 C5 C4 C3 C2 T1 D0
                                4'h9: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +:  8] != DATA_CHAR_PATTERN
                                    || i_rx_xcoded[17 + DATA_WIDTH * i  +:  6] != '0
                                    || i_rx_xcoded[23 + DATA_WIDTH * i  +: 42] != {6{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'h9;
                                end
    
                                // C7 C6 C5 C4 C3 T2 D1 D0
                                4'hA: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 16] != {2{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[25 + DATA_WIDTH * i  +:  5] != '0
                                    || i_rx_xcoded[30 + DATA_WIDTH * i  +: 35] != {5{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'hA;
                                end
    
                                // C7 C6 C5 C4 T3 D2 D1 D0
                                4'hB: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 24] != {3{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[33 + DATA_WIDTH * i  +:  4] != '0
                                    || i_rx_xcoded[37 + DATA_WIDTH * i  +: 28] != {4{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'h4;
                                end
    
                                // C7 C6 C5 T4 D3 D2 D1 D0
                                4'hC: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 32] != {4{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[41 + DATA_WIDTH * i  +:  3] != '0
                                    || i_rx_xcoded[46 + DATA_WIDTH * i  +: 21] != {3{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'hC;
                                end
    
                                // C7 C6 T5 D4 D3 D2 D1 D0
                                4'hD: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 40] != {5{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[49 + DATA_WIDTH * i  +:  2] != '0
                                    || i_rx_xcoded[51 + DATA_WIDTH * i  +: 14] != {2{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'h2;
                                end
    
                                // C7 T6 D5 D4 D3 D2 D1 D0
                                4'hE: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 48] != {6{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[57 + DATA_WIDTH * i  +:  1] != '0
                                    || i_rx_xcoded[58 + DATA_WIDTH * i  +:  7] != CTRL_CHAR_PATTERN      ) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'h1;
                                end
    
                                // T7 D6 D5 D4 D3 D2 D1 D0
                                4'hF: begin
                                    if(i_rx_xcoded[9 + DATA_WIDTH * i +: 56] != {7{DATA_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'hF;
                                end 
    
                                // Invalid format
                                default: begin
                                    inv_block_flag = 1'b1;
                                                                                      
                                    next_rx_payloads[4 + DATA_WIDTH * i +: 4] = 4'h0;
                                end
                            endcase
    
                            // Assign payload
                            next_rx_payloads[DATA_WIDTH * i +: 4]       = i_rx_xcoded[5 + DATA_WIDTH * i +: 4]  ;
                            next_rx_payloads[8 + DATA_WIDTH * i +: 56]  = i_rx_xcoded[9 + DATA_WIDTH * i +: 56] ;
                        end
    
                        // It is not the first ctrl frame found
                        else begin
                            
                            // Ctrl frame formats
                            case (i_rx_xcoded[1 + DATA_WIDTH * i +: 8])
    
                                // C7 C6 C5 C4 C3 C2 C1 C0
                                8'h1E: begin
                                    if(i_rx_xcoded[9 + DATA_WIDTH * i +: 56] != {8{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // D7 D6 D5 D4 D3 D2 D1 S0
                                8'h78: begin
                                    if(i_rx_xcoded[9 + DATA_WIDTH * i +: 56] != {7{DATA_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // Z7 Z6 Z5 Z4 D3 D2 D1 O0
                                8'h4B: begin
                                    if(i_rx_xcoded[9  + DATA_WIDTH * i +: 24] != {3{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[33 + DATA_WIDTH * i +:  4] != OSET_CHAR_PATTERN
                                    || i_rx_xcoded[37 + DATA_WIDTH * i +: 28] != '0                      ) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // C7 C6 C5 C4 C3 C2 C1 T0
                                8'h87: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +:  7] != '0
                                    || i_rx_xcoded[16 + DATA_WIDTH * i  +: 49] != {7{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // C7 C6 C5 C4 C3 C2 T1 D0
                                8'h99: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +:  8] != DATA_CHAR_PATTERN
                                    || i_rx_xcoded[17 + DATA_WIDTH * i  +:  6] != '0
                                    || i_rx_xcoded[23 + DATA_WIDTH * i  +: 42] != {6{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // C7 C6 C5 C4 C3 T2 D1 D0
                                8'hAA: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 16] != {2{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[25 + DATA_WIDTH * i  +:  5] != '0
                                    || i_rx_xcoded[30 + DATA_WIDTH * i  +: 35] != {5{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // C7 C6 C5 C4 T3 D2 D1 D0
                                8'hB4: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 24] != {3{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[33 + DATA_WIDTH * i  +:  4] != '0
                                    || i_rx_xcoded[37 + DATA_WIDTH * i  +: 28] != {4{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // C7 C6 C5 T4 D3 D2 D1 D0
                                8'hCC: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 32] != {4{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[41 + DATA_WIDTH * i  +:  3] != '0
                                    || i_rx_xcoded[46 + DATA_WIDTH * i  +: 21] != {3{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // C7 C6 T5 D4 D3 D2 D1 D0
                                8'hD2: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 40] != {5{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[49 + DATA_WIDTH * i  +:  2] != '0
                                    || i_rx_xcoded[51 + DATA_WIDTH * i  +: 14] != {2{CTRL_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // C7 T6 D5 D4 D3 D2 D1 D0
                                8'hE1: begin
                                    if(i_rx_xcoded[ 9 + DATA_WIDTH * i  +: 48] != {6{DATA_CHAR_PATTERN}}
                                    || i_rx_xcoded[57 + DATA_WIDTH * i  +:  1] != '0
                                    || i_rx_xcoded[58 + DATA_WIDTH * i  +:  7] != CTRL_CHAR_PATTERN      ) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end
    
                                // T7 D6 D5 D4 D3 D2 D1 D0
                                8'hFF: begin
                                    if(i_rx_xcoded[9 + DATA_WIDTH * i +: 56] != {7{DATA_CHAR_PATTERN}}) begin
                                        inv_block_flag = 1'b1;
                                    end
                                end 
    
                                // Invalid format
                                default: begin
                                    inv_block_flag = 1'b1;
                                end
                            endcase
                        
                            // Assign payload
                            next_rx_payloads[DATA_WIDTH * i +: DATA_WIDTH] = i_rx_xcoded[1 + DATA_WIDTH * i +: DATA_WIDTH];
                        end
                    end
                end
    
                // Assign the corresponding 64b sync headers
                next_rx_coded_0[1:0] = {i_rx_xcoded[1], ~i_rx_xcoded[1]};
                next_rx_coded_1[1:0] = {i_rx_xcoded[2], ~i_rx_xcoded[2]};
                next_rx_coded_2[1:0] = {i_rx_xcoded[3], ~i_rx_xcoded[3]};
                next_rx_coded_3[1:0] = {i_rx_xcoded[4], ~i_rx_xcoded[4]};
            end

            // If the 4 bits are '1111'
            else begin
                inv_block_flag = 1'b1;
                
                // Assign payload
                next_rx_payloads = {i_rx_xcoded[TC_WIDTH-1 : 9] , 
                                    4'h0                        ,
                                    i_rx_xcoded[8 : 5]          };

                // Assign invalid 64b sync headers
                next_rx_coded_0[1:0] = 2'b00;
                next_rx_coded_1[1:0] = 2'b11;
                next_rx_coded_2[1:0] = 2'b00;
                next_rx_coded_3[1:0] = 2'b11;
            end
            
            // Assign the next four 64b blocks
            next_rx_coded_0[65:2] = next_rx_payloads[0 +: DATA_WIDTH];
            next_rx_coded_1[65:2] = next_rx_payloads[64 +: DATA_WIDTH];
            next_rx_coded_2[65:2] = next_rx_payloads[64 * 2 +: DATA_WIDTH];
            next_rx_coded_3[65:2] = next_rx_payloads[64 * 3 +: DATA_WIDTH];
        end

        // Update counter
        next_inv_block_count = inv_block_count + inv_block_flag;
    end

    always @(posedge clk or posedge i_rst) begin
        if(i_rst) begin
            rx_coded_0 <= '0;
            rx_coded_1 <= '0;
            rx_coded_2 <= '0;
            rx_coded_3 <= '0;
            rx_payloads <= '0;
            block_count <= '0;
            data_count <= '0;
            ctrl_count <= '0;
            inv_block_count <= '0;
        end
        else begin
            rx_coded_0 <= next_rx_coded_0;
            rx_coded_1 <= next_rx_coded_1;
            rx_coded_2 <= next_rx_coded_2;
            rx_coded_3 <= next_rx_coded_3;
            rx_payloads <= next_rx_payloads;
            block_count <= next_block_count;
            data_count <= next_data_count;
            ctrl_count <= next_ctrl_count;
            inv_block_count <= next_inv_block_count;
        end
    end

    assign o_rx_coded_0         = rx_coded_0        ;
    assign o_rx_coded_1         = rx_coded_1        ;
    assign o_rx_coded_2         = rx_coded_2        ;
    assign o_rx_coded_3         = rx_coded_3        ;
    assign o_block_count        = block_count       ;
    assign o_ctrl_count         = ctrl_count        ;
    assign o_data_count         = data_count        ;
    assign o_inv_block_count    = inv_block_count   ;

endmodule
