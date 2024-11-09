`timescale 1ns/100ps

module BASER_257b_scrambled_checker
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
    parameter       SYNC_HEADER         = 1'b1
)
(
    input  logic                    clk             ,   //! Clock input
    input  logic                    i_rst           ,   //! Asynchronous reset
    input  logic    [TC_WIDTH-1:0]  i_tx_scrambled  ,   //! Received data
    output logic    [31:0]          o_block_count   ,   //! Total number of 257b blocks received
    output logic    [31:0]          o_data_count    ,   //! Total number of 257b blocks with all 64b data block received
    output logic    [31:0]          o_ctrl_count        //! Total number of 257b blocks with at least one 64b control block received
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

    always_comb begin
        next_block_count = block_count + 1;
        
        // All data blocks
        if(i_tx_scrambled[0]) begin
            next_data_count = data_count + 'd1;
            next_ctrl_count = ctrl_count;
        end
        // At least one ctrl block
        else begin 
            next_data_count = data_count;
            next_ctrl_count = ctrl_count + 'd1;
        end

    end

    always_ff @(posedge clk or posedge i_rst) begin
        if(i_rst) begin
            block_count <= '0;
            data_count <= '0;
            ctrl_count <= '0;
        end
        else begin
            block_count <= block_count+1;
            data_count <= next_data_count;
            ctrl_count <= next_ctrl_count;
        end
    end

    assign o_block_count = block_count;
    assign o_data_count = data_count;
    assign o_ctrl_count = ctrl_count;

endmodule
