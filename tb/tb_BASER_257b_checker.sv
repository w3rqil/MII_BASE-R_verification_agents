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
    parameter       CTRL_CHAR_PATTERN   = 7'h1E                     ;
    parameter       OSET_CHAR_PATTERN   = 4'hF                      ;

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

        // Bloque valido: D3 D2 D1 D0
        i_rx_coded  = {{TC_DATA_WIDTH / 8 {DATA_CHAR_PATTERN}}, 1'b1};

        #200;
        @(posedge clk);
        i_rst = 0;

        #200;
        @(posedge clk);
        // Bloque valido: D3 D2 D1 C0
        i_rx_coded[0]          = 1'b0;

        i_rx_coded[ 4  :    1] = 4'b1110;

        i_rx_coded[ 5 +:    4] = 4'h7;                      // Start block type (0x78)
        i_rx_coded[ 9 +:  7*8] = {  7{DATA_CHAR_PATTERN}};

        i_rx_coded[65 +: 3*64] = {3*8{DATA_CHAR_PATTERN}};

        #200;
        @(posedge clk);
        // Bloque valido: C3 D2 C1 D0
        i_rx_coded[  4  :   1] = 4'b0101;

        i_rx_coded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}};

        i_rx_coded[ 69 +:   4] = 4'hF;                      // "D0 D1 D2 D3 D4 D5 D6 T7" block type (0xFF)
        i_rx_coded[ 73 +: 7*8] = {7{DATA_CHAR_PATTERN}};

        i_rx_coded[129 +: 8*8] = {8{DATA_CHAR_PATTERN}};
        
        i_rx_coded[193 +:   8] = 8'h87;                     // "T0 C1 C2 C3 C4 C5 C6 C7" block type (0x87)
        i_rx_coded[201 +:   7] = 7'h0;
        i_rx_coded[208 +: 7*7] = {7{CTRL_CHAR_PATTERN}};
        
        #200;
        @(posedge clk);
        // Bloque invalido: D3 D2 D1 D0 pero con el header en 0 y los sig 4 bits en 1111
        i_rx_coded[  4  :    1] = 4'b1111;
        i_rx_coded[  5 +: 3*64] = {3*8{DATA_CHAR_PATTERN}};
        i_rx_coded[197 +:   60] = {  8{DATA_CHAR_PATTERN}};

        #200;
        @(posedge clk);
        // Bloque invalido: D3 D2 C1 D0 pero el C1 tiene 64 bits
        i_rx_coded[4 : 1] = 4'b1101;

        i_rx_coded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}};

        i_rx_coded[69  +:   8] = 8'h4B;                        // Ordered Set block type (0x4B)
        i_rx_coded[77  +: 3*8] = {3{DATA_CHAR_PATTERN}};
        i_rx_coded[101 +:   4] = OSET_CHAR_PATTERN;
        i_rx_coded[105 +:  28] = '0;

        i_rx_coded[133 +: 124] = {2*8{DATA_CHAR_PATTERN}};
        
        #200;
        @(posedge clk);

        // Bloque valido: El mismo bloque anterior corregido
        i_rx_coded[4 : 1] = 4'b1101;

        i_rx_coded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}};

        i_rx_coded[69  +:    4] = 4'h4;                         // Ordered Set block type (0x4B)
        i_rx_coded[73  +:  3*8] = {3{DATA_CHAR_PATTERN}};
        i_rx_coded[97  +:    4] = OSET_CHAR_PATTERN;
        i_rx_coded[101 +:   28] = '0;

        i_rx_coded[129 +: 2*64] = {2*8{DATA_CHAR_PATTERN}};
        
        #200;
        @(posedge clk);

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
        .CTRL_CHAR_PATTERN  (CTRL_CHAR_PATTERN) ,
        .OSET_CHAR_PATTERN  (OSET_CHAR_PATTERN)
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