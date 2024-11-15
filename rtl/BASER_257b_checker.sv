`timescale 1ns/100ps

module BASER_257b_checker
#(
    /*
    *---------WIDTH---------
    */
    parameter int   DATA_WIDTH          = 64                        ,   //! 64 bits blocks
    parameter int   TC_DATA_WIDTH       = 4 * DATA_WIDTH            ,   //! 256 bits transcoded blocks (without header)
    parameter int   SH_WIDTH            = 1                         ,   //! 1 bit sync header
    parameter int   TC_WIDTH            = TC_DATA_WIDTH + SH_WIDTH  ,   //! 257 bits transcoded blocks
    /*
    *------BLOCK TYPE-------
    */
    parameter       DATA_CHAR_PATTERN   = 8'hAA                     ,   //! Data character
    // For control characters, the standard specifies:
    // Idle:    0x00
    // Error:   0x1E
    parameter       CTRL_CHAR_PATTERN   = 7'h1E                     ,   //! 7 BITS Control character
    parameter       OSET_CHAR_PATTERN   = 4'hF                          //! 4 BITS Ordered Set character
)
(
    /*
    *--------INPUTS---------
    */
    input  logic                    clk                 ,   //! Clock input
    input  logic                    i_rst               ,   //! Asynchronous reset
    input  logic    [TC_WIDTH-1:0]  i_rx_coded          ,   //! Received data
    /*
    *--------OUTPUTS--------
    */
    output logic    [31:0]          o_block_count       ,   //! Total number of 257b blocks received
    output logic    [31:0]          o_data_count        ,   //! Total number of 257b blocks with all 64b data block received
    output logic    [31:0]          o_ctrl_count        ,   //! Total number of 257b blocks with at least one 64b control block received
    output logic    [31:0]          o_inv_block_count       //! Total number of invalid blocks
);

    // Total blocks counter
    logic [31:0] block_count;
    logic [31:0] next_block_count;
    // Data blocks counter
    logic [31:0] data_count;
    logic [31:0] next_data_count;
    // Ctrl blocks counter
    logic [31:0] ctrl_count;
    logic [31:0] next_ctrl_count;
    // Invalid blocks counter
    logic [31:0] inv_block_count;
    logic [31:0] next_inv_block_count;

    // Flag of first 64b ctrl block received in the 257b block
    logic        first_ctrl_block_flag;

    always @(*) begin
        // Increase total block counter every clock positive edge
        next_block_count = block_count + 'd1;

        // Detected all data blocks
        if(i_rx_coded[0]) begin
            // Increase data block counter
            next_data_count = data_count + 'd1;
            next_ctrl_count = ctrl_count;

            // Valid block verification logic (INCOMPLETE)
            next_inv_block_count = inv_block_count;
        end

        // Detected at least one ctrl block
        else begin
            // Increase control block counter
            next_data_count = data_count;
            next_ctrl_count = ctrl_count + 'd1;
            first_ctrl_block_flag = 1'b0;
            
            // Analize the four 64b frames
            for(int i = 0; i < 4; i++) begin

                // Data frame
                if(i_rx_coded[i+1]) begin

                    // There is no ctrl frame found yet
                    if(first_ctrl_block_flag == 1'b0) begin

                        // The frame has to be all Data characters
                        if(i_rx_coded[5 + DATA_WIDTH * i +: DATA_WIDTH] == {8{DATA_CHAR_PATTERN}}) begin
                            next_inv_block_count = inv_block_count;
                        end
                        else begin
                            next_inv_block_count = inv_block_count + 'd1;
                        end
                    end

                    // There is a ctrl frame found before
                    else begin

                        // The frame has to be all Data characters
                        if(i_rx_coded[1 + DATA_WIDTH * i +: DATA_WIDTH] == {8{DATA_CHAR_PATTERN}}) begin
                            next_inv_block_count = inv_block_count;
                        end
                        else begin
                            next_inv_block_count = inv_block_count + 'd1;
                        end
                    end
                end

                // Ctrl frame
                else begin

                    // It is the first ctrl frame found
                    if(first_ctrl_block_flag == 1'b0) begin
                        first_ctrl_block_flag = 1'b1;

                        // Ctrl frame formats
                        case (i_rx_coded[5 + DATA_WIDTH * i])

                            // C7 C6 C5 C4 C3 C2 C1 C0
                            4'h1: begin
                                if(i_rx_coded[9 + DATA_WIDTH * i +: 56] == {8{CTRL_CHAR_PATTERN}}) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // D7 D6 D5 D4 D3 D2 D1 S0
                            4'h7: begin
                                if(i_rx_coded[9 + DATA_WIDTH * i +: 56] == {7{DATA_CHAR_PATTERN}}) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // Z7 Z6 Z5 Z4 D3 D2 D1 O0
                            4'h4: begin
                                if(i_rx_coded[9  + DATA_WIDTH * i +: 24] == {3{DATA_CHAR_PATTERN}}
                                && i_rx_coded[33 + DATA_WIDTH * i +:  4] == OSET_CHAR_PATTERN
                                && i_rx_coded[37 + DATA_WIDTH * i +: 28] == '0                      ) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // C7 C6 C5 C4 C3 C2 C1 T0
                            4'h8: begin
                                if(i_rx_coded[ 9 + DATA_WIDTH * i  +:  7] == '0
                                && i_rx_coded[16 + DATA_WIDTH * i  +: 49] == {7{CTRL_CHAR_PATTERN}}) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // C7 C6 C5 C4 C3 C2 T1 D0
                            4'h9: begin
                                if(i_rx_coded[ 9 + DATA_WIDTH * i  +:  8] == DATA_CHAR_PATTERN
                                && i_rx_coded[17 + DATA_WIDTH * i  +:  6] == '0
                                && i_rx_coded[23 + DATA_WIDTH * i  +: 42] == {6{CTRL_CHAR_PATTERN}}) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // C7 C6 C5 C4 C3 T2 D1 D0
                            4'hA: begin
                                if(i_rx_coded[ 9 + DATA_WIDTH * i  +: 16] == {2{DATA_CHAR_PATTERN}}
                                && i_rx_coded[25 + DATA_WIDTH * i  +:  5] == '0
                                && i_rx_coded[30 + DATA_WIDTH * i  +: 35] == {5{CTRL_CHAR_PATTERN}}) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // C7 C6 C5 C4 T3 D2 D1 D0
                            4'hB: begin
                                if(i_rx_coded[ 9 + DATA_WIDTH * i  +: 24] == {3{DATA_CHAR_PATTERN}}
                                && i_rx_coded[33 + DATA_WIDTH * i  +:  4] == '0
                                && i_rx_coded[37 + DATA_WIDTH * i  +: 28] == {4{CTRL_CHAR_PATTERN}}) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // C7 C6 C5 T4 D3 D2 D1 D0
                            4'hC: begin
                                if(i_rx_coded[ 9 + DATA_WIDTH * i  +: 32] == {4{DATA_CHAR_PATTERN}}
                                && i_rx_coded[41 + DATA_WIDTH * i  +:  3] == '0
                                && i_rx_coded[46 + DATA_WIDTH * i  +: 21] == {3{CTRL_CHAR_PATTERN}}) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // C7 C6 T5 D4 D3 D2 D1 D0
                            4'hD: begin
                                if(i_rx_coded[ 9 + DATA_WIDTH * i  +: 40] == {5{DATA_CHAR_PATTERN}}
                                && i_rx_coded[49 + DATA_WIDTH * i  +:  2] == '0
                                && i_rx_coded[51 + DATA_WIDTH * i  +: 14] == {2{CTRL_CHAR_PATTERN}}) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // C7 T6 D5 D4 D3 D2 D1 D0
                            4'hE: begin
                                if(i_rx_coded[ 9 + DATA_WIDTH * i  +: 48] == {6{DATA_CHAR_PATTERN}}
                                && i_rx_coded[57 + DATA_WIDTH * i  +:  1] == '0
                                && i_rx_coded[58 + DATA_WIDTH * i  +:  7] == CTRL_CHAR_PATTERN      ) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end

                            // T7 D6 D5 D4 D3 D2 D1 D0
                            4'hF: begin
                                if(i_rx_coded[9 + DATA_WIDTH * i +: 56] == {7{DATA_CHAR_PATTERN}}) begin
                                    next_inv_block_count = inv_block_count;
                                end
                                else begin
                                    next_inv_block_count = inv_block_count + 'd1;
                                end
                            end 

                            // Invalid format
                            default: begin
                                next_inv_block_count = inv_block_count + 'd1;
                            end
                        endcase
                    end

                    // It is not the first ctrl frame found
                    else begin
                        
                        // The frame has to be all Ctrl characters
                        if(i_rx_coded[1 + DATA_WIDTH * i +: DATA_WIDTH] == {8{CTRL_CHAR_PATTERN}}) begin
                            next_inv_block_count = inv_block_count;
                        end
                        else begin
                            next_inv_block_count = inv_block_count + 'd1;
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk or posedge i_rst) begin
        if(i_rst) begin
            block_count <= '0;
            data_count <= '0;
            ctrl_count <= '0;
            inv_block_count <= '0;
        end
        else begin
            block_count <= next_block_count;
            data_count <= next_data_count;
            ctrl_count <= next_ctrl_count;
            inv_block_count <= next_inv_block_count;
        end
    end

    assign o_block_count = block_count;
    assign o_ctrl_count = ctrl_count;
    assign o_data_count = data_count;
    assign o_inv_block_count = inv_block_count;

endmodule
