`timescale 1ns/100ps

module tb_BASER_checker;
    /*
    *---------WIDTH---------
    */
    parameter int   DATA_WIDTH          = 64                            ;
    parameter int   HDR_WIDTH           = 2                             ;
    parameter int   FRAME_WIDTH         = DATA_WIDTH + HDR_WIDTH        ;
    parameter int   CTRL_WIDTH          = DATA_WIDTH / 8                ;
    parameter int   TC_DATA_WIDTH       = 4 * DATA_WIDTH                ;   // 256 bits transcoded blocks (without header)
    parameter int   TC_HDR_WIDTH        = 1                             ;
    parameter int   TC_WIDTH            = TC_DATA_WIDTH + TC_HDR_WIDTH  ;   // 257 bits transcoded blocks
    /*
    *------BLOCK TYPE-------
    */
    parameter       DATA_CHAR_PATTERN   = 8'hAA                     ;
    parameter       CTRL_CHAR_PATTERN   = 7'h1E                     ;
    parameter       OSET_CHAR_PATTERN   = 4'hB                      ;

    /*
    *---------INPUTS----------
    */
    logic                    clk            ;   // Clock input
    logic                    i_rst          ;   // Asynchronous reset
    logic    [TC_WIDTH-1:0]  i_rx_xcoded    ;   // Received data
    
    /*
    *--------OUTPUTS---------
    */
    logic    [DATA_WIDTH-1:0]   o_txd               ;   // Output MII Data
    logic    [CTRL_WIDTH-1:0]   o_txc               ;   // Output MII Control
    // 66b checker counters
    logic    [31:0]             o_66_block_count       ;   // Total number of 66b blocks received
    logic    [31:0]             o_66_data_count        ;   // Total number of 66b data blocks received
    logic    [31:0]             o_66_ctrl_count        ;   // Total number of 66b control blocks received
    logic    [31:0]             o_66_inv_block_count   ;   // Total number of invalid 66b blocks
    logic    [31:0]             o_66_inv_pattern_count ;   // Total number of 66b blocks with invalid char pattern
    logic    [31:0]             o_66_inv_format_count  ;   // Total number of 66b blocks with invalid format
    logic    [31:0]             o_66_inv_sh_count      ;   // Total number of 66b blocks with invalid sync header
    // 257b checker counters
    logic    [31:0]             o_257_block_count       ;   // Total number of 257b blocks received
    logic    [31:0]             o_257_data_count        ;   // Total number of 257b blocks with all 64b data block received
    logic    [31:0]             o_257_ctrl_count        ;   // Total number of 257b blocks with at least one 64b control block received
    logic    [31:0]             o_257_inv_block_count   ;   // Total number of invalid blocks
    logic    [31:0]             o_257_inv_pattern_count ;   // Total number of 257b blocks with invalid char pattern
    logic    [31:0]             o_257_inv_format_count  ;   // Total number of 257b blocks with with invalid 64b format
    logic    [31:0]             o_257_inv_sh_count      ;   // Total number of 257b blocks with invalid sync header

    /*
    *------CONNECTIONS-------
    */
    logic    [FRAME_WIDTH-1:0]  rx_coded_0          ;   // 1st 64b block
    logic    [FRAME_WIDTH-1:0]  rx_coded_1          ;   // 2nd 64b block
    logic    [FRAME_WIDTH-1:0]  rx_coded_2          ;   // 3rd 64b block
    logic    [FRAME_WIDTH-1:0]  rx_coded_3          ;   // 4th 64b block
    logic                       valid               ;   // Valid signal for 257b checker

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // Test sequence
    initial begin
        i_rst   = 1'b1;
        clk     = 1'b0;

        // Bloque valido: D3 D2 D1 D0
        i_rx_xcoded = {{TC_DATA_WIDTH / 8 {DATA_CHAR_PATTERN}}, 1'b1};

        #200                                                ;
        @(posedge clk)                                      ;
        i_rst = 0                                           ;

        #200                                                ;
        @(posedge valid)                                      ;
        // Bloque valido: D3 D2 D1 C0
        i_rx_xcoded[0]          = 1'b0                      ;

        i_rx_xcoded[4 : 1] = 4'b1110                        ;

        i_rx_xcoded[ 5 +:    4] = 4'h8                      ;   // Start block type (0x78)
        i_rx_xcoded[ 9 +:  7*8] = {  7{DATA_CHAR_PATTERN}}  ;

        i_rx_xcoded[65 +: 3*64] = {3*8{DATA_CHAR_PATTERN}}  ;

        #200                                                ;
        @(posedge valid)                                      ;
        // Bloque valido: C3 D2 C1 D0
        i_rx_xcoded[  4  :   1] = 4'b0101                   ;

        i_rx_xcoded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;

        i_rx_xcoded[ 69 +:   4] = 4'hF                      ;   // "T7 D6 D5 D4 D3 D2 D1 D0" block type (0xFF)
        i_rx_xcoded[ 73 +: 7*8] = {7{DATA_CHAR_PATTERN}}    ;

        i_rx_xcoded[129 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;
        
        i_rx_xcoded[193 +:   8] = 8'h87                     ;   // "C7 C6 C5 C4 C3 C2 C1 T0" block type (0x87)
        i_rx_xcoded[201 +:   7] = 7'h0                      ;
        i_rx_xcoded[208 +: 7*7] = {7{CTRL_CHAR_PATTERN}}    ;
        
        #200                                                ;
        @(posedge valid)                                      ;
        // Bloque invalido: C3 D2 C1 D0 pero los dos C con block type incorrecto
        i_rx_xcoded[  4  :   1] = 4'b0101                   ;

        i_rx_xcoded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;

        i_rx_xcoded[ 69 +:   4] = 4'hD                      ;   // "T7 D6 D5 D4 D3 D2 D1 D0" block type (0xFF)
        i_rx_xcoded[ 73 +: 7*8] = {7{DATA_CHAR_PATTERN}}    ;

        i_rx_xcoded[129 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;
        
        i_rx_xcoded[193 +:   8] = 8'h86                     ;   // "C7 C6 C5 C4 C3 C2 C1 T0" block type (0x87)
        i_rx_xcoded[201 +:   7] = 7'h0                      ;
        i_rx_xcoded[208 +: 7*7] = {7{CTRL_CHAR_PATTERN}}    ;

        #200                                                ;
        @(posedge valid)                                      ;
        // Bloque invalido: D3 D2 D1 D0 pero con el header en 0 y los sig 4 bits en 1111
        i_rx_xcoded[  4  :    1] = 4'b1111                  ;
        i_rx_xcoded[  5 +: 3*64] = {3*8{DATA_CHAR_PATTERN}} ;
        i_rx_xcoded[197 +:   60] = {  8{DATA_CHAR_PATTERN}} ;

        #200                                                ;
        @(posedge valid)                                      ;
        // Bloque invalido: D3 D2 C1 D0 pero el C1 tiene 64 bits
        i_rx_xcoded[4 : 1] = 4'b1101                        ;

        i_rx_xcoded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;

        i_rx_xcoded[69  +:   8] = 8'h4B                     ;   // Ordered Set block type (0x4B) (2 nibbles)
        i_rx_xcoded[77  +: 3*8] = {3{DATA_CHAR_PATTERN}}    ;
        i_rx_xcoded[101 +:   4] = OSET_CHAR_PATTERN         ;
        i_rx_xcoded[105 +:  28] = '0                        ;

        i_rx_xcoded[133 +: 124] = {2*8{DATA_CHAR_PATTERN}}  ;
        
        #200                                                ;
        @(posedge valid)                                      ;
        // Bloque valido: El mismo bloque anterior corregido
        i_rx_xcoded[4 : 1] = 4'b1101                        ;

        i_rx_xcoded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;

        i_rx_xcoded[69  +:    4] = 4'hB                     ;   // Ordered Set block type (0x4B) (1 nibble)
        i_rx_xcoded[73  +:  3*8] = {3{DATA_CHAR_PATTERN}}   ;
        i_rx_xcoded[97  +:    4] = OSET_CHAR_PATTERN        ;
        i_rx_xcoded[101 +:   28] = '0                       ;

        i_rx_xcoded[129 +: 2*64] = {2*8{DATA_CHAR_PATTERN}} ;
        
        #200                                                ;
        @(posedge valid)                                      ;

        // Display after all tests
        if(o_66_inv_block_count == 0) begin
            // Invalid blocks Not found
            $display("Final Result: TEST PASSED");
        end
        else begin
            // Invalid blocks Found
            $display("Final Result: TEST FAILED");
        end
        // Display all counters
        $display("Total Blocks Received: %0d"       ,   o_66_block_count                                                   );
        $display("Data Blocks Received: %0d"        ,   o_66_data_count                                                    );
        $display("Control Blocks Received: %0d"     ,   o_66_ctrl_count                                                    );
        $display("Invalid Blocks Received: %0d"     ,   o_66_inv_block_count                                               );
        $display("Valid blocks percentage: %0f%%"   ,   (1 - real'(o_66_inv_block_count) / real'(o_66_block_count)) * 100     );

        $finish;
    end

    // Instantiate 257b to 66b checker
    BASER_257b_checker#(
        .DATA_WIDTH             (DATA_WIDTH                 ),
        .HDR_WIDTH              (HDR_WIDTH                  ),
        .FRAME_WIDTH            (FRAME_WIDTH                ),
        .TC_DATA_WIDTH          (TC_DATA_WIDTH              ),
        .TC_HDR_WIDTH           (TC_HDR_WIDTH               ),
        .TC_WIDTH               (TC_WIDTH                   ),
        .DATA_CHAR_PATTERN      (DATA_CHAR_PATTERN          ),
        .CTRL_CHAR_PATTERN      (CTRL_CHAR_PATTERN          ),
        .OSET_CHAR_PATTERN      (OSET_CHAR_PATTERN          )
    ) dut_257b (
        .clk                    (valid                      ),
        .i_rst                  (i_rst                      ),
        .i_rx_xcoded            (i_rx_xcoded                ),
        .o_rx_coded_0           (rx_coded_0                 ),
        .o_rx_coded_1           (rx_coded_1                 ),
        .o_rx_coded_2           (rx_coded_2                 ),
        .o_rx_coded_3           (rx_coded_3                 ),
        .o_block_count          (o_257_block_count          ),
        .o_data_count           (o_257_data_count           ),
        .o_ctrl_count           (o_257_ctrl_count           ),
        .o_inv_block_count      (o_257_inv_block_count      ),
        .o_inv_pattern_count    (o_257_inv_pattern_count    ),
        .o_inv_format_count     (o_257_inv_format_count     ),
        .o_inv_sh_count         (o_257_inv_sh_count         )
    );

    // Instantiate 66b to MII checker
    BASER_66b_checker#(
        .DATA_WIDTH             (DATA_WIDTH                 ),
        .HDR_WIDTH              (HDR_WIDTH                  ),
        .FRAME_WIDTH            (FRAME_WIDTH                ),
        .CTRL_WIDTH             (CTRL_WIDTH                 ),
        .DATA_CHAR_PATTERN      (DATA_CHAR_PATTERN          ),
        .CTRL_CHAR_PATTERN      (CTRL_CHAR_PATTERN          ),
        .OSET_CHAR_PATTERN      (OSET_CHAR_PATTERN          )
    ) dut_66b (
        .clk                    (clk                        ),
        .i_rst                  (i_rst                      ),
        .i_rx_coded_0           (rx_coded_0                 ),
        .i_rx_coded_1           (rx_coded_1                 ),
        .i_rx_coded_2           (rx_coded_2                 ),
        .i_rx_coded_3           (rx_coded_3                 ),
        .o_txd                  (o_txd                      ),
        .o_txc                  (o_txc                      ),
        .o_block_count          (o_66_block_count           ),
        .o_data_count           (o_66_data_count            ),
        .o_ctrl_count           (o_66_ctrl_count            ),
        .o_inv_block_count      (o_66_inv_block_count       ),
        .o_inv_pattern_count    (o_66_inv_pattern_count     ),
        .o_inv_format_count     (o_66_inv_format_count      ),
        .o_inv_sh_count         (o_66_inv_sh_count          ),
        .o_valid                (valid                      )
    );

endmodule