/*
    Conexion entre el generador y el checker de señal 1.6TBASE-R
*/

`timescale 1ns/100ps
// `include "Modulos/signalGenerator/ejemplo/PCS_gen.sv"
// `include "Modulos/signalGenerator/rtl/BASER_257b_checker.sv"

module tb_BASER_gen_check;

    /*
    *-------------------------WIDTH PARAMETERS---------------------------
    */
    parameter   DATA_WIDTH              = 64                            ;   // 64 bits PCS blocks (without header)
    parameter   CTRL_WIDTH              = DATA_WIDTH / 8                ;
    parameter   HDR_WIDTH               = 2                             ;   // 2 bits sync header
    parameter   FRAME_WIDTH             = DATA_WIDTH + HDR_WIDTH        ;   // 66 bits PCS blocks
    parameter   TC_DATA_WIDTH           = 4 * DATA_WIDTH                ;   // 256 bits transcoded blocks (without header)
    parameter   TC_HDR_WIDTH            = 1                             ;   // 1 bit sync header
    parameter   TC_WIDTH                = TC_DATA_WIDTH + TC_HDR_WIDTH  ;   // 257 bits transcoded blocks
    parameter   TRANSCODER_BLOCKS       = 4                             ;   // Four 64b blocks in a 257b block
    parameter   TRANSCODER_HDR_WIDTH    = 4                             ;
    parameter   PROB                    = 30                            ;

    /*
    *-----------------------BLOCK TYPE PARAMETERS------------------------
    */
    parameter   DATA_CHAR_PATTERN       = 8'hAA                         ;   // Data character
    // For Control characters, the standard specifies:
    // Idle:    0x00
    // Error:   0x1E
    parameter   CTRL_CHAR_PATTERN       = 7'h00                         ;   // 7 BITS Control character
    parameter   OSET_CHAR_PATTERN       = 4'hB                          ;   // 4 BITS Ordered Set character

    /*
    *---------------------INPUTS-------------------------
    */
    logic                               clk                             ;   // Clock input
    logic                               i_rst                           ;   // Asynchronous reset

    // Generator
    logic [DATA_WIDTH        - 1 : 0]   i_txd                           ;   /* Input data                             */
    logic [CTRL_WIDTH        - 1 : 0]   i_txc                           ;   /* Input control byte                     */
    logic [TRANSCODER_BLOCKS - 1 : 0]   i_data_sel_0                    ;   /* Data selector                          */
    logic [                    1 : 0]   i_valid                         ;   /* Input to enable frame generation       */    
    logic                               i_enable                        ;   /* Flag to enable frame generation        */
    logic                               i_random_0                      ;   /* Flag to enable random frame generation */
    logic                               i_tx_test_mode                  ;   /* Flag to enable TX test mode            */
    // 257b Checker
    logic [TC_WIDTH          - 1 : 0]   i_rx_xcoded                     ;   // Received data
    // 66b Checker
    logic [FRAME_WIDTH       - 1 : 0]   i_rx_coded_0                    ;   // 1st 64b block
    logic [FRAME_WIDTH       - 1 : 0]   i_rx_coded_1                    ;   // 2nd 64b block
    logic [FRAME_WIDTH       - 1 : 0]   i_rx_coded_2                    ;   // 3rd 64b block
    logic [FRAME_WIDTH       - 1 : 0]   i_rx_coded_3                    ;   // 4th 64b block

    /*
    *---------------------OUTPUTS------------------------
    */
    // Generator
    logic [TC_WIDTH          - 1 : 0]   o_tx_coded_f0                   ;   /* Output transcoder                      */
    logic [FRAME_WIDTH       - 1 : 0]   o_frame_0                       ;   /* Output frame 0                         */
    logic [FRAME_WIDTH       - 1 : 0]   o_frame_1                       ;   /* Output frame 1                         */
    logic [FRAME_WIDTH       - 1 : 0]   o_frame_2                       ;   /* Output frame 2                         */
    logic [FRAME_WIDTH       - 1 : 0]   o_frame_3                       ;   /* Output frame 3                         */
    // 257b Checker
    logic [FRAME_WIDTH       - 1 : 0]   o_rx_coded_0                    ;   // 1st 64b block
    logic [FRAME_WIDTH       - 1 : 0]   o_rx_coded_1                    ;   // 2nd 64b block
    logic [FRAME_WIDTH       - 1 : 0]   o_rx_coded_2                    ;   // 3rd 64b block
    logic [FRAME_WIDTH       - 1 : 0]   o_rx_coded_3                    ;   // 4th 64b block
    logic [                   31 : 0]   o_257_block_count               ;   // Total number of 257b blocks received
    logic [                   31 : 0]   o_257_data_count                ;   // Total number of 257b blocks with all 64b data block received
    logic [                   31 : 0]   o_257_ctrl_count                ;   // Total number of 257b blocks with at least one 64b control block received
    logic [                   31 : 0]   o_257_inv_block_count           ;   // Total number of invalid blocks
    logic [                   31 : 0]   o_257_inv_pattern_count         ;   // Total number of 257b blocks with invalid char pattern
    logic [                   31 : 0]   o_257_inv_format_count          ;   // Total number of 257b blocks with with invalid 64b format
    logic [                   31 : 0]   o_257_inv_sh_count              ;   // Total number of 257b blocks with invalid sync header
    // 66b Checker
    logic [DATA_WIDTH        - 1 : 0]   o_txd                           ;   // Output MII Data
    logic [CTRL_WIDTH        - 1 : 0]   o_txc                           ;   // Output MII Control
    logic [                   31 : 0]   o_66_block_count                ;   // Total number of 66b blocks received
    logic [                   31 : 0]   o_66_data_count                 ;   // Total number of 66b data blocks received
    logic [                   31 : 0]   o_66_ctrl_count                 ;   // Total number of 66b control blocks received
    logic [                   31 : 0]   o_66_inv_block_count            ;   // Total number of invalid 66b blocks
    logic [                   31 : 0]   o_66_inv_sh_count               ;   // Total number of 66b blocks with invalid sync header
    logic                               o_valid                         ;   // Valid signal for 257b checker

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // Loopback Generator-Checker
    assign i_rx_xcoded = o_tx_coded_f0;
    assign i_rx_coded_0 = o_rx_coded_0;
    assign i_rx_coded_1 = o_rx_coded_1;
    assign i_rx_coded_2 = o_rx_coded_2;
    assign i_rx_coded_3 = o_rx_coded_3;

    initial begin
        // $dumpfile("Modulos/signalGenerator/tb/tb_BASER_gen_check.vcd");
        // $dumpvars();
        clk             = 'b0       ;
        i_rst           = 'b1       ;
        i_data_sel_0    = 'b0000    ;
        i_enable        = 'b0       ;      
        i_valid         = 'b000     ;
        i_tx_test_mode  = 'b0       ;
        i_random_0      = 'b0       ;
        i_txd           = 'b0       ;
        i_txc           = 'b0       ;

        // Set the enable and desactive the reset
        #100                        ;
        @(posedge clk)              ;
        i_rst           = 1'b0      ;
        i_enable        = 1'b1      ;
        i_valid         = 2'b11     ;

        // Set the data sel 0
        #600                        ;
        @(posedge clk)              ;
        i_data_sel_0    = 4'b0001   ;
        #600                        ;
        @(posedge clk)              ;
        i_data_sel_0    = 4'b0010   ;
        #600                        ;
        @(posedge clk)              ;
        i_data_sel_0    = 4'b0011   ;
        #600                        ;
        @(posedge clk)              ;
        i_data_sel_0    = 4'b0100   ;
        #600                        ;
        @(posedge clk)              ;
        i_data_sel_0    = 4'b1000   ;
        #600                        ;
        @(posedge clk)              ;
        i_data_sel_0    = 4'b1111   ;
        #600                        ;
        @(posedge clk)              ;

        // Change the MII input
        i_enable        = 1'b0                  ;
        i_txc           = 8'h00                 ;
        i_txd           = 64'hFFFFFFFFFFFFFFFF  ;
        #600                                    ;
        @(posedge clk)                          ;
        i_txd           = 64'hAAAAAAAAAAAAAAAA  ;
        #600                                    ;
        @(posedge clk)                          ;
        i_txc           = 8'hFF                 ;
        i_txd           = 64'h07070707070707FD  ;
        #600                                    ;
        @(posedge clk)                          ;
        i_txc           = 8'h01                 ;
        i_txd           = 64'hAAAAAAAAAAAAAAFB  ;
        #600                                    ;
        @(posedge clk)                          ;
        i_txc           = 8'h00                 ;
        i_txd           = 64'hAAAAAAAAAAAAAAAA  ;
        #600                                    ;
        @(posedge clk)                          ;
        i_txc           = 8'hFC                 ;
        i_txd           = 64'h0707070707FDAAAA  ;
        #600                                    ;
        @(posedge clk)                          ;
        i_txc           = 8'hFF                 ;
        i_txd           = 64'h0707070707070707  ;
        #600                                    ;
        @(posedge clk)                          ;
        i_txc           = 8'hFF                 ;
        i_txd           = 64'hFEFEFEFEFEFEFEFE  ;
        #600                                    ;
        @(posedge clk)                          ;
        
        // Display after all tests
        if(o_257_inv_block_count == 0) begin
            // Invalid blocks Not found
            $display("Final Result: TEST PASSED");
        end
        else begin
            // Invalid blocks Found
            $display("Final Result: TEST FAILED");
        end
        // Display all counters
        $display("Total Blocks Received: %0d"       ,   o_257_block_count                                                   );
        $display("Data Blocks Received: %0d"        ,   o_257_data_count                                                    );
        $display("Control Blocks Received: %0d"     ,   o_257_ctrl_count                                                    );
        $display("Invalid Blocks Received: %0d"     ,   o_257_inv_block_count                                               );
        $display("Valid blocks percentage: %0f%%"   ,   (1 - real'(o_257_inv_block_count) / real'(o_257_block_count)) * 100     );

        $finish;
    end

    // Instantiate generator
    PCS_generator # (
        .DATA_WIDTH             (DATA_WIDTH             ),
        .HDR_WIDTH              (HDR_WIDTH              ),
        .FRAME_WIDTH            (FRAME_WIDTH            ),
        .CONTROL_WIDTH          (CTRL_WIDTH             ),
        .TRANSCODER_BLOCKS      (TRANSCODER_BLOCKS      ),
        .TRANSCODER_WIDTH       (TC_WIDTH               ),
        .TRANSCODER_HDR_WIDTH   (TRANSCODER_HDR_WIDTH   ),
        .PROB                   (PROB                   )
    ) dut_gen (
        .o_tx_coded_f0          (o_tx_coded_f0          ),
        .o_frame_0              (o_frame_0              ),
        .o_frame_1              (o_frame_1              ),
        .o_frame_2              (o_frame_2              ),
        .o_frame_3              (o_frame_3              ),
        .i_txd                  (i_txd                  ),
        .i_txc                  (i_txc                  ),
        .i_data_sel_0           (i_data_sel_0           ),
        .i_valid                (i_valid                ),
        .i_enable               (i_enable               ),
        .i_random_0             (i_random_0             ),
        .i_tx_test_mode         (i_tx_test_mode         ),
        .i_rst_n                (!i_rst                 ),    // Reset negado
        .clk                    (clk                    )
    );

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
        .clk                    (o_valid                ),
        .i_rst                  (i_rst                  ),
        .i_rx_xcoded            (i_rx_xcoded            ),
        .o_rx_coded_0           (o_rx_coded_0           ),
        .o_rx_coded_1           (o_rx_coded_1           ),
        .o_rx_coded_2           (o_rx_coded_2           ),
        .o_rx_coded_3           (o_rx_coded_3           ),
        .o_block_count          (o_257_block_count      ),
        .o_data_count           (o_257_data_count       ),
        .o_ctrl_count           (o_257_ctrl_count       ),
        .o_inv_block_count      (o_257_inv_block_count  ),
        .o_inv_pattern_count    (o_257_inv_pattern_count),
        .o_inv_format_count     (o_257_inv_format_count ),
        .o_inv_sh_count         (o_257_inv_sh_count     )
    );

    // Instantiate 66b checker
    BASER_66b_checker#(
        .DATA_WIDTH             (DATA_WIDTH             ),
        .HDR_WIDTH              (HDR_WIDTH              ),
        .FRAME_WIDTH            (FRAME_WIDTH            ),
        .CTRL_WIDTH             (CTRL_WIDTH             ),
        .DATA_CHAR_PATTERN      (DATA_CHAR_PATTERN      ),
        .CTRL_CHAR_PATTERN      (CTRL_CHAR_PATTERN      ),
        .OSET_CHAR_PATTERN      (OSET_CHAR_PATTERN      )
    ) dut_66b_check (
        .clk                    (clk                    ),
        .i_rst                  (i_rst                  ),
        .i_rx_coded_0           (i_rx_coded_0           ),
        .i_rx_coded_1           (i_rx_coded_1           ),
        .i_rx_coded_2           (i_rx_coded_2           ),
        .i_rx_coded_3           (i_rx_coded_3           ),
        .o_txd                  (o_txd                  ),
        .o_txc                  (o_txc                  ),
        .o_block_count          (o_66_block_count       ),
        .o_data_count           (o_66_data_count        ),
        .o_ctrl_count           (o_66_ctrl_count        ),
        .o_inv_block_count      (o_66_inv_block_count   ),
        .o_inv_sh_count         (o_66_inv_sh_count      ),
        .o_valid                (o_valid                )
    );

endmodule