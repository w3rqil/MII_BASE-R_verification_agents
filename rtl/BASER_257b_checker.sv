`timescale 1ns/100ps

module BASER_257b_checker
#(
    /*
    *---------WIDTH---------
    */
    parameter int   DATA_WIDTH          = 64                        ,
    parameter int   TC_DATA_WIDTH       = 4 * DATA_WIDTH            ,   //! 256 bits transcoded blocks (without header)
    parameter int   SH_WIDTH            = 1                         ,
    parameter int   TC_WIDTH            = TC_DATA_WIDTH + SH_WIDTH      //! 257 bits transcoded blocks
    /*
    *------BLOCK TYPE-------
    */
    parameter       SYNC_HEADER         = 1'b1                      ,
    parameter       DATA_CHAR_PATTERN   = 8'hAA
)
(
    input  logic                    clk             ,   //! Clock input
    input  logic                    i_rst           ,   //! Asynchronous reset
    input  logic    [TC_WIDTH-1:0]  i_tx_coded      ,   //! Received data
    output int                      o_block_count   ,   //! Total number of 257b blocks received
    output int                      o_data_count    ,   //! Total number of 257b blocks with all 64b data block received
    output int                      o_ctrl_count    ,   //! Total number of 257b blocks with at least one 64b control block received
);

    // Total blocks counter
    int block_count;
    int next_block_count;
    // Data blocks counter
    int data_count;
    int next_data_count;
    // Ctrl blocks counter
    int ctrl_count;
    int next_ctrl_count;

    always_comb begin
        // All data blocks
        if(i_tx_coded[0]) begin
            next_block_count = block_count + 1;
            next_data_count = data_count + 1;
            next_ctrl_count = ctrl_count;
        end
        // At least one ctrl block
        else begin
            next_block_count = block_count + 1;
            next_data_count = data_count;
            next_ctrl_count = ctrl_count + 1;
        end
    end

    always_ff @(posedge clk or posedge i_rst) begin
        if(i_rst) begin
            block_count <= '0;
            data_count <= '0;
            ctrl_count <= '0;
        end
        else begin
            block_count <= next_block_count;
            data_count <= next_data_count;
            ctrl_count <= next_ctrl_count;
        end
    end

endmodule
