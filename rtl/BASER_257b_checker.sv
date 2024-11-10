`timescale 1ns/100ps

module BASER_257b_checker
#(
    /*
    *---------WIDTH---------
    */
    parameter int   DATA_WIDTH          = 64                        ,
    parameter int   TC_DATA_WIDTH       = 4 * DATA_WIDTH            ,   //! 256 bits transcoded blocks (without header)
    parameter int   SH_WIDTH            = 1                         ,
    parameter int   TC_WIDTH            = TC_DATA_WIDTH + SH_WIDTH  ,   //! 257 bits transcoded blocks
    /*
    *------BLOCK TYPE-------
    */
    parameter       DATA_CHAR_PATTERN   = 8'hAA                     ,
    parameter       CTRL_CHAR_PATTERN   = 8'h55
)
(
    input  logic                    clk                 ,   //! Clock input
    input  logic                    i_rst               ,   //! Asynchronous reset
    input  logic    [TC_WIDTH-1:0]  i_rx_coded          ,   //! Received data
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

    always_comb begin
        next_block_count = block_count + 'd1;

        // All data blocks
        if(i_rx_coded[0]) begin
            next_data_count = data_count + 'd1;
            next_ctrl_count = ctrl_count;
            next_inv_block_count = inv_block_count;
        end
        // At least one ctrl block
        else begin
            next_data_count = data_count;
            next_ctrl_count = ctrl_count + 'd1;
            first_ctrl_block_flag = 1'b0;
            
            for(int i = 0; i < 4; i++) begin
                // Data frame
                if(i_rx_coded[i+1]) begin
                    // There is no ctrl frame found yet
                    if(first_ctrl_block_flag == 1'b0) begin
                        if(i_rx_coded[5 + DATA_WIDTH * i +: DATA_WIDTH] != {8{DATA_CHAR_PATTERN}}) begin
                            next_inv_block_count = inv_block_count + 'd1;
                        end
                        else
                            next_inv_block_count = inv_block_count;
                    end
                    // There is a ctrl frame found before
                    else begin
                        if(i_rx_coded[1 + DATA_WIDTH * i +: DATA_WIDTH] != {8{DATA_CHAR_PATTERN}}) begin
                            next_inv_block_count = inv_block_count + 'd1;
                        end
                        else
                            next_inv_block_count = inv_block_count;
                    end
                end
                // Ctrl frame
                else begin
                    // It is the first ctrl frame found
                    if(first_ctrl_block_flag == 1'b0) begin
                        first_ctrl_block_flag = 1'b1;
                        if(i_rx_coded[5 + DATA_WIDTH * i +: 60] != {8{CTRL_CHAR_PATTERN}}) begin
                            next_inv_block_count = inv_block_count + 'd1;
                        end
                        else
                            next_inv_block_count = inv_block_count;
                    end
                    // It is not the first ctrl frame found
                    else begin
                        if(i_rx_coded[1 + DATA_WIDTH * i +: DATA_WIDTH] != {8{CTRL_CHAR_PATTERN}}) begin
                            next_inv_block_count = inv_block_count + 'd1;
                        end
                        else
                            next_inv_block_count = inv_block_count;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk or posedge i_rst) begin
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
