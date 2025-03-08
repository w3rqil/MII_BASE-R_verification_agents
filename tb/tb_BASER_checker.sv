`timescale 1ns/100ps

module tb_BASER_checker;
    /*
    *---------WIDTH---------
    */
    parameter   DATA_WIDTH              = 64                            ;
    parameter   HDR_WIDTH               = 2                             ;
    parameter   FRAME_WIDTH             = DATA_WIDTH + HDR_WIDTH        ;
    parameter   CTRL_WIDTH              = DATA_WIDTH / 8                ;
    parameter   TC_DATA_WIDTH           = 4 * DATA_WIDTH                ;   // 256 bits transcoded blocks (without header)
    parameter   TC_HDR_WIDTH            = 1                             ;
    parameter   TC_WIDTH                = TC_DATA_WIDTH + TC_HDR_WIDTH  ;   // 257 bits transcoded blocks
    parameter   TC_BLOCKS               = 4                             ;   // Four 64b blocks in a 257b block
    parameter   TRANSCODER_HDR_WIDTH    = 4                             ;
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
    // 257b Checker
    logic [TC_WIDTH          - 1 : 0]   i_rx_xcoded                     ;   // Received data
    logic                               i_valid                         ;   // Enable check process. If 0, the outputs don't change.
    // 66b Checker
    logic [                    7 : 0]   i_pattern_mode                  ;
    
    /*
    *--------OUTPUTS---------
    */
    // 257b Checker
    logic [                   31 : 0]   o_257_block_count                           ;   // Total number of 257b blocks received
    logic [                   31 : 0]   o_257_data_count                            ;   // Total number of 257b blocks with all 64b data block received
    logic [                   31 : 0]   o_257_ctrl_count                            ;   // Total number of 257b blocks with at least one 64b control block received
    logic [                   31 : 0]   o_257_inv_block_count                       ;   // Total number of invalid blocks
    logic [                   31 : 0]   o_257_inv_sh_count                          ;   // Total number of 257b blocks with invalid sync header
    // 66b Checker
    logic [DATA_WIDTH        - 1 : 0]   o_txd                   [TC_BLOCKS - 1 : 0] ;   // Output MII Data
    logic [CTRL_WIDTH        - 1 : 0]   o_txc                   [TC_BLOCKS - 1 : 0] ;   // Output MII Control
    logic [                   31 : 0]   o_66_block_count        [TC_BLOCKS - 1 : 0] ;   // Total number of 66b blocks received
    logic [                   31 : 0]   o_66_data_count         [TC_BLOCKS - 1 : 0] ;   // Total number of 66b data blocks received
    logic [                   31 : 0]   o_66_ctrl_count         [TC_BLOCKS - 1 : 0] ;   // Total number of 66b control blocks received
    logic [                   31 : 0]   o_66_inv_block_count    [TC_BLOCKS - 1 : 0] ;   // Total number of invalid 66b blocks
    logic [                   31 : 0]   o_66_inv_pattern_count  [TC_BLOCKS - 1 : 0] ;   // Total number of invalid 66b blocks
    logic [                   31 : 0]   o_66_inv_format_count   [TC_BLOCKS - 1 : 0] ;   // Total number of invalid 66b blocks
    logic [                   31 : 0]   o_66_inv_sh_count       [TC_BLOCKS - 1 : 0] ;   // Total number of 66b blocks with invalid sync header

    /*
    *------CONNECTIONS-------
    */
    logic [FRAME_WIDTH        -1 : 0]   rx_coded                [TC_BLOCKS - 1 : 0] ;   // 64B blocks

    logic [7:0] temp;

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // Test sequence
    initial begin
        i_rst   = 1'b1;
        clk     = 1'b0;
        i_valid = 1'b0;
        i_pattern_mode = 8'd0;
        i_rx_xcoded = 'b0;

        #200                                                ;
        @(posedge clk)                                      ;
        i_rst = 0                                           ;
        // // Bloque valido: D3 D2 D1 D0
        // i_rx_xcoded = {{TC_DATA_WIDTH / 8 {DATA_CHAR_PATTERN}}, 1'b1};

        // #200                                                ;
        // @(posedge valid)                                      ;
        // // Bloque valido: D3 D2 D1 C0
        // i_rx_xcoded[0]          = 1'b0                      ;

        // i_rx_xcoded[4 : 1] = 4'b1110                        ;

        // i_rx_xcoded[ 5 +:    4] = 4'h8                      ;   // Start block type (0x78)
        // i_rx_xcoded[ 9 +:  7*8] = {  7{DATA_CHAR_PATTERN}}  ;

        // i_rx_xcoded[65 +: 3*64] = {3*8{DATA_CHAR_PATTERN}}  ;

        // #200                                                ;
        // @(posedge valid)                                      ;
        // // Bloque valido: C3 D2 C1 D0
        // i_rx_xcoded[  4  :   1] = 4'b0101                   ;

        // i_rx_xcoded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;

        // i_rx_xcoded[ 69 +:   4] = 4'hF                      ;   // "T7 D6 D5 D4 D3 D2 D1 D0" block type (0xFF)
        // i_rx_xcoded[ 73 +: 7*8] = {7{DATA_CHAR_PATTERN}}    ;

        // i_rx_xcoded[129 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;
        
        // i_rx_xcoded[193 +:   8] = 8'h87                     ;   // "C7 C6 C5 C4 C3 C2 C1 T0" block type (0x87)
        // i_rx_xcoded[201 +:   7] = 7'h0                      ;
        // i_rx_xcoded[208 +: 7*7] = {7{CTRL_CHAR_PATTERN}}    ;
        
        // #200                                                ;
        // @(posedge valid)                                      ;
        // // Bloque invalido: C3 D2 C1 D0 pero los dos C con block type incorrecto
        // i_rx_xcoded[  4  :   1] = 4'b0101                   ;

        // i_rx_xcoded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;

        // i_rx_xcoded[ 69 +:   4] = 4'hD                      ;   // "T7 D6 D5 D4 D3 D2 D1 D0" block type (0xFF)
        // i_rx_xcoded[ 73 +: 7*8] = {7{DATA_CHAR_PATTERN}}    ;

        // i_rx_xcoded[129 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;
        
        // i_rx_xcoded[193 +:   8] = 8'h86                     ;   // "C7 C6 C5 C4 C3 C2 C1 T0" block type (0x87)
        // i_rx_xcoded[201 +:   7] = 7'h0                      ;
        // i_rx_xcoded[208 +: 7*7] = {7{CTRL_CHAR_PATTERN}}    ;

        // #200                                                ;
        // @(posedge valid)                                      ;
        // // Bloque invalido: D3 D2 D1 D0 pero con el header en 0 y los sig 4 bits en 1111
        // i_rx_xcoded[  4  :    1] = 4'b1111                  ;
        // i_rx_xcoded[  5 +: 3*64] = {3*8{DATA_CHAR_PATTERN}} ;
        // i_rx_xcoded[197 +:   60] = {  8{DATA_CHAR_PATTERN}} ;

        // #200                                                ;
        // @(posedge valid)                                      ;
        // // Bloque invalido: D3 D2 C1 D0 pero el C1 tiene 64 bits
        // i_rx_xcoded[4 : 1] = 4'b1101                        ;

        // i_rx_xcoded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;

        // i_rx_xcoded[69  +:   8] = 8'h4B                     ;   // Ordered Set block type (0x4B) (2 nibbles)
        // i_rx_xcoded[77  +: 3*8] = {3{DATA_CHAR_PATTERN}}    ;
        // i_rx_xcoded[101 +:   4] = OSET_CHAR_PATTERN         ;
        // i_rx_xcoded[105 +:  28] = '0                        ;

        // i_rx_xcoded[133 +: 124] = {2*8{DATA_CHAR_PATTERN}}  ;
        
        // #200                                                ;
        // @(posedge valid)                                      ;
        // // Bloque valido: El mismo bloque anterior corregido
        // i_rx_xcoded[4 : 1] = 4'b1101                        ;

        // i_rx_xcoded[  5 +: 8*8] = {8{DATA_CHAR_PATTERN}}    ;

        // i_rx_xcoded[69  +:    4] = 4'hB                     ;   // Ordered Set block type (0x4B) (1 nibble)
        // i_rx_xcoded[73  +:  3*8] = {3{DATA_CHAR_PATTERN}}   ;
        // i_rx_xcoded[97  +:    4] = OSET_CHAR_PATTERN        ;
        // i_rx_xcoded[101 +:   28] = '0                       ;

        // i_rx_xcoded[129 +: 2*64] = {2*8{DATA_CHAR_PATTERN}} ;
        
        // #200                                                ;
        // @(posedge valid)                                      ;

        // PRBS
        i_pattern_mode = 8'd2;
        i_rx_xcoded[0] = 1'b1;
        i_rx_xcoded[1 +: 8] = 8'hFF;

        repeat(2) begin
            for(int i = 9; i < TC_WIDTH; i = i + 8) begin
                i_rx_xcoded[i +: 8] = prbs8_gen(i_rx_xcoded[i-8 +: 8]);
                temp = i_rx_xcoded[i +: 8];
                $display("i_rx_xcoded: %h", i_rx_xcoded[i +: 8]);
            end

            @(posedge clk);
            i_rx_xcoded[1 +: 8] = prbs8_gen(temp);
        end

        i_valid = 1'b1;
        
        repeat(5) begin
            for(int i = 9; i < TC_WIDTH; i = i + 8) begin
                i_rx_xcoded[i +: 8] = prbs8_gen(i_rx_xcoded[i-8 +: 8]);
                temp = i_rx_xcoded[i +: 8];
                $display("i_rx_xcoded: %h", i_rx_xcoded[i +: 8]);
            end

            @(posedge clk);
            i_rx_xcoded[1 +: 8] = prbs8_gen(temp);
        end

        // Display after all tests
        if((o_257_inv_block_count + o_66_inv_block_count[0] + o_66_inv_block_count[1] + o_66_inv_block_count[2] + o_66_inv_block_count[3]) == 0) begin
            // Invalid blocks Not found
            $display("Final Result: TEST PASSED\n");
        end
        else begin
            // Invalid blocks Found
            $display("Final Result: TEST FAILED\n");
        end

        // Display all counters
        $display("---256B/257B CHECKER---\n");
        $display("Total blocks received: %0d", o_257_block_count);
        $display("\tBlocks with all 66B Data Blocks received: %0d", o_257_data_count);
        $display("\tBlocks with at least one 66B Control Block received: %0d", o_257_ctrl_count);
        $display("Blocks with SH '0' and next 4 bits '1111' Received: %0d\n", o_257_inv_sh_count);

        for(int i = 0; i < TC_BLOCKS; i++) begin
            $display("---64B/66B CHECKER: LINE %0d---\n", i);
            $display("Total Blocks Received: %0d", o_66_block_count[i]);
            $display("\t-Data Blocks Received: %0d", o_66_data_count[i]);
            $display("\t-Control Blocks Received: %0d", o_66_ctrl_count[i]);
            $display("Invalid Blocks Received: %0d", o_66_inv_block_count[i]);
            $display("\t-Invalid Pattern: %0d", o_66_inv_pattern_count[i]);
            $display("\t-Invalid Format/Block Type: %0d", o_66_inv_format_count[i]);
            $display("\t-Invalid Sync Header ('00' or '11'): %0d\n", o_66_inv_sh_count[i]);
        end

        $finish;
    end

    // Instantiate 257b checker
    BASER_257b_checker#(
        .DATA_WIDTH             (DATA_WIDTH             ),
        .HDR_WIDTH              (HDR_WIDTH              ),
        .FRAME_WIDTH            (FRAME_WIDTH            ),
        .TC_DATA_WIDTH          (TC_DATA_WIDTH          ),
        .TC_HDR_WIDTH           (TC_HDR_WIDTH           ),
        .TC_WIDTH               (TC_WIDTH               ),
        .DATA_CHAR_PATTERN      (DATA_CHAR_PATTERN      ),
        .CTRL_CHAR_PATTERN      (CTRL_CHAR_PATTERN      ),
        .OSET_CHAR_PATTERN      (OSET_CHAR_PATTERN      )
    ) dut_257b_check (
        .clk                    (clk                    ),
        .i_rst                  (i_rst                  ),
        .i_valid                (i_valid                ),
        .i_rx_xcoded            (i_rx_xcoded            ),
        .o_rx_coded_0           (rx_coded[0]            ),
        .o_rx_coded_1           (rx_coded[1]            ),
        .o_rx_coded_2           (rx_coded[2]            ),
        .o_rx_coded_3           (rx_coded[3]            ),
        .o_block_count          (o_257_block_count      ),
        .o_data_count           (o_257_data_count       ),
        .o_ctrl_count           (o_257_ctrl_count       ),
        .o_inv_block_count      (o_257_inv_block_count  ),
        .o_inv_sh_count         (o_257_inv_sh_count     )
    );

    // Instantiate 66b checker
    genvar i;
    generate
        for(i = 0; i < TC_BLOCKS; i++) begin
            BASER_66b_checker#(
                .DATA_WIDTH         (DATA_WIDTH                 ),
                .HDR_WIDTH          (HDR_WIDTH                  ),
                .FRAME_WIDTH        (FRAME_WIDTH                ),
                .CTRL_WIDTH         (CTRL_WIDTH                 ),
                .DATA_CHAR_PATTERN  (DATA_CHAR_PATTERN          ),
                .CTRL_CHAR_PATTERN  (CTRL_CHAR_PATTERN          ),
                .OSET_CHAR_PATTERN  (OSET_CHAR_PATTERN          )
            ) dut_66b_check (
                .clk                    (clk                        ),
                .i_rst                  (i_rst                      ),
                .i_valid                (i_valid                    ),
                .i_rx_coded             (rx_coded             [i] ),
                .i_pattern_mode(i_pattern_mode),
                .o_txd                  (o_txd                  [i] ),
                .o_txc                  (o_txc                  [i] ),
                .o_block_count          (o_66_block_count       [i] ),
                .o_data_count           (o_66_data_count        [i] ),
                .o_ctrl_count           (o_66_ctrl_count        [i] ),
                .o_inv_block_count      (o_66_inv_block_count   [i] ),
                .o_inv_pattern_count    (o_66_inv_pattern_count [i] ),
                .o_inv_format_count     (o_66_inv_format_count  [i] ),
                .o_inv_sh_count         (o_66_inv_sh_count      [i] )
            );
        end
    endgenerate

    function automatic reg [7:0] prbs8_gen
    (
        input [7:0] i_seed
    );
        reg [7:0] val;
    
        val[0]   = i_seed[1] ^ i_seed[2] ^ i_seed[3] ^ i_seed[7];
        val[7:1] = i_seed[6:0];

        return val;
    endfunction

endmodule