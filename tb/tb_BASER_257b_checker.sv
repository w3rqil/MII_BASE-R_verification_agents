`timescale 1ns/100ps

module tb_BASER_257b_checker;
    /*
    *---------WIDTH---------
    */
    parameter int   DATA_WIDTH          = 64                        ;
    parameter int   TC_DATA_WIDTH       = 4 * DATA_WIDTH            ;   //! 256 bits transcoded blocks (without header)
    parameter int   SH_WIDTH            = 1                         ;
    parameter int   TC_WIDTH            = TC_DATA_WIDTH + SH_WIDTH  ;   //! 257 bits transcoded blocks
    /*
    *------BLOCK TYPE-------
    */
    parameter       DATA_CHAR_PATTERN   = 8'hAA                     ;
    parameter       CTRL_CHAR_PATTERN   = 8'h55                     ;

    /*
    *---------INPUTS----------
    */
    logic                    clk             ;   //! Clock input
    logic                    i_rst           ;   //! Asynchronous reset
    logic    [TC_WIDTH-1:0]  i_rx_coded      ;   //! Received data
    
    /*
    *--------OUTPUTS---------
    */
    logic    [31:0]          o_block_count      ;   //! Total number of 257b blocks received
    logic    [31:0]          o_data_count       ;   //! Total number of 257b blocks with all 64b data block received
    logic    [31:0]          o_ctrl_count       ;   //! Total number of 257b blocks with at least one 64b control block received
    logic    [31:0]          o_inv_block_count  ;   //! Total number of invalid blocks

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // Test sequence
    initial begin
        // Generate .vcd
        $dumpfile("dump.vcd");
        $dumpvars;
                 
        i_rst       = 1;
        clk         = 0;
        i_rx_coded  = {{TC_DATA_WIDTH / 8{DATA_CHAR_PATTERN}}, 1'b1};

        #200;
        @(posedge clk);
        i_rst = 0;

        #200;
        @(posedge clk);
        i_rx_coded[0] = 1'b0;
        i_rx_coded[4 : 1] = 4'b1110;
        i_rx_coded[5 +: 60] = {8{CTRL_CHAR_PATTERN}};
        i_rx_coded[TC_WIDTH - 1: 65] = {24{DATA_CHAR_PATTERN}};

        #100;
        @(posedge clk);
        // i_tx_coded[0] = 0;

        // @(posedge clk);
        // i_tx_coded[0] = 1;
        
        // @(posedge clk);
        // i_tx_coded[0] = 0;
        
        // @(posedge clk);
        // i_tx_coded[0] = 1;

        // Display outputs
        $display("Simulation finished after %0t ps.", $time);
        $display("Final Results:");
        $display("Total Blocks Received: %0d", o_block_count);
        $display("Data Blocks Received: %0d", o_data_count);
        $display("Control Blocks Received: %0d", o_ctrl_count);
        $display("Invalid Blocks Received: %0d", o_inv_block_count);

        $finish;
    end

    // Instantiate DUT
    BASER_257b_checker#(
        .DATA_WIDTH         (DATA_WIDTH)        ,
        .TC_DATA_WIDTH      (TC_DATA_WIDTH)     ,
        .SH_WIDTH           (SH_WIDTH)          ,
        .TC_WIDTH           (TC_WIDTH)          ,
        .DATA_CHAR_PATTERN  (DATA_CHAR_PATTERN) ,
        .CTRL_CHAR_PATTERN  (CTRL_CHAR_PATTERN)
    ) dut (
        .clk                (clk)               ,
        .i_rst              (i_rst)             ,
        .i_rx_coded         (i_rx_coded)        ,
        .o_block_count      (o_block_count)     ,
        .o_data_count       (o_data_count)      ,
        .o_ctrl_count       (o_ctrl_count)      ,
        .o_inv_block_count  (o_inv_block_count)
    );

endmodule