/*
    Conexion entre el generador y el checker de BASE-R. Por ahora al checker entra solo
    una de las salidas del generador, que es uno de los canales donde sale el bloque de 257b
    antes de entrar al scrambler.
*/

`timescale 1ns/100ps
`include "Modulos/signalGenerator/ejemplo/PCS_gen.sv"
`include "Modulos/signalGenerator/rtl/BASER_257b_checker.sv"

module tb_BASER_gen_check;

    /*
    *-------------------------WIDTH PARAMETERS---------------------------
    */
    parameter   DATA_WIDTH              = 64                            ;
    parameter   HDR_WIDTH               = 2                             ;
    parameter   FRAME_WIDTH             = DATA_WIDTH + HDR_WIDTH        ;
    parameter   TC_DATA_WIDTH           = 4 * DATA_WIDTH                ;   // 256 bits transcoded blocks (without header)
    parameter   TC_HDR_WIDTH            = 1                             ;   // 1 bit sync header
    parameter   TC_WIDTH                = TC_DATA_WIDTH + TC_HDR_WIDTH  ;   // 257 bits transcoded blocks
    parameter   CONTROL_WIDTH           = 8                             ;
    parameter   TRANSCODER_BLOCKS       = 4                             ;
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
    parameter   OSET_CHAR_PATTERN       = 4'hF                          ;   // 4 BITS Ordered Set character

    /*
    *---------------------INPUTS-------------------------
    */
    logic                             clk               ;   // Clock input
    logic                             i_rst             ;   // Asynchronous reset

    // Generator
    logic [DATA_WIDTH        - 1 : 0] i_txd             ;   /* Input data                             */
    logic [CONTROL_WIDTH     - 1 : 0] i_txc             ;   /* Input control byte                     */
    logic [TRANSCODER_BLOCKS - 1 : 0] i_data_sel_0      ;   /* Data selector                          */
    logic [                    1 : 0] i_valid           ;   /* Input to enable frame generation       */    
    logic                             i_enable          ;   /* Flag to enable frame generation        */
    logic                             i_random_0        ;   /* Flag to enable random frame generation */
    logic                             i_tx_test_mode    ;   /* Flag to enable TX test mode            */
    // Checker
    logic [TC_WIDTH          - 1 : 0] i_rx_xcoded       ;   // Received data

    /*
    *---------------------OUTPUTS------------------------
    */
    // Generator
    logic [TC_WIDTH          - 1 : 0] o_tx_coded_f0     ;   /* Output transcoder                      */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_0         ;   /* Output frame 0                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_1         ;   /* Output frame 1                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_2         ;   /* Output frame 2                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_3         ;   /* Output frame 3                         */
    // Checker
    logic [FRAME_WIDTH       - 1 : 0] o_rx_coded_0              ;   // 1st 64b block
    logic [FRAME_WIDTH       - 1 : 0] o_rx_coded_1              ;   // 2nd 64b block
    logic [FRAME_WIDTH       - 1 : 0] o_rx_coded_2              ;   // 3rd 64b block
    logic [FRAME_WIDTH       - 1 : 0] o_rx_coded_3              ;   // 4th 64b block
    logic [                   31 : 0] o_block_count             ;   // Total number of 257b blocks received
    logic [                   31 : 0] o_data_count              ;   // Total number of 257b blocks with all 64b data block received
    logic [                   31 : 0] o_ctrl_count              ;   // Total number of 257b blocks with at least one 64b control block received
    logic [                   31 : 0] o_inv_block_count         ;   // Total number of invalid blocks
    logic [                   31 : 0] o_inv_ctrl_block_count    ;   // Total number of 257b blocks with invalid 64b ctrl blocks
    logic [                   31 : 0] o_inv_data_block_count    ;   // Total number of 257b blocks with invalid 64b data blocks
    logic [                   31 : 0] o_inv_sequence_count      ;   // Total number of 257b blocks with with invalid 64b format
    logic [                   31 : 0] o_inv_sh_count            ;   // Total number of 257b blocks with invalid sync header

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    assign i_rx_xcoded = o_tx_coded_f0;

    initial begin
        $dumpfile("Modulos/signalGenerator/tb/tb_BASER_gen_check.vcd");
        $dumpvars();
        clk             = 'b0       ;
        i_rst           = 'b1       ;
        i_data_sel_0    = 'b0000    ;
        i_enable        = 'b0       ;      
        i_valid         = 'b000     ;
        i_tx_test_mode  = 'b0       ;
        i_random_0      = 'b0       ;
        i_txd           = 'b0       ;
        i_txc           = 'b0       ;
        #100                        ;

        // Set the enable and desactive the reset
        i_rst           = 1'b0      ;
        i_enable        = 1'b1      ;
        i_valid         = 2'b11     ;

        // Set the data sel 0
        #300;
        i_data_sel_0    = 4'b0001   ;
        #300                        ;
        i_data_sel_0    = 4'b0010   ;
        #300;
        i_data_sel_0    = 4'b0011   ;
        #300                        ;
        i_data_sel_0    = 4'b0100   ;
        #300                        ;
        i_data_sel_0    = 4'b1000   ;
        #300                        ;
        i_data_sel_0    = 4'b1111   ;
        #300                        ;

        // Change the inputs
        i_enable        = 1'b0;
        i_txc           = 8'h00;
        i_txd           = 64'hFFFFFFFFFFFFFFFF;
        #300;
        i_txd           = 64'hAAAAAAAAAAAAAAAA;
        #300;
        i_txc           = 8'hFF;
        i_txd           = 64'h07070707070707FD;
        #300;
        i_txc           = 8'h01;
        i_txd           = 64'hAAAAAAAAAAAAAAFB;
        #300;
        i_txc           = 8'h00;
        i_txd           = 64'hAAAAAAAAAAAAAAAA;
        #300;
        i_txc           = 8'hFC;
        i_txd           = 64'h0707070707FDAAAA;
        #300;
        i_txc           = 8'hFF;
        i_txd           = 64'h0707070707070707;
        #300;
        
        // Display after all tests
        if(o_inv_block_count == 0) begin
            // Invalid blocks Not found
            $display("Final Result: TEST PASSED")                            ;
        end
        else begin
            // Invalid blocks Found
            $display("Final Result: TEST FAILED")                            ;
        end
        // Display all counters
        $display("Total Blocks Received: %0d"       ,   o_block_count                                                   );
        $display("Data Blocks Received: %0d"        ,   o_data_count                                                    );
        $display("Control Blocks Received: %0d"     ,   o_ctrl_count                                                    );
        $display("Invalid Blocks Received: %0d"     ,   o_inv_block_count                                               );
        $display("Valid blocks percentage: %0f%%"   ,   (1 - real'(o_inv_block_count) / real'(o_block_count)) * 100     );

        $finish;
    end

    // Instantiate generator
    PCS_generator # (
        .DATA_WIDTH           (DATA_WIDTH           )   ,
        .HDR_WIDTH            (HDR_WIDTH            )   ,
        .FRAME_WIDTH          (FRAME_WIDTH          )   ,
        .CONTROL_WIDTH        (CONTROL_WIDTH        )   ,
        .TRANSCODER_BLOCKS    (TRANSCODER_BLOCKS    )   ,
        .TRANSCODER_WIDTH     (TC_WIDTH             )   ,
        .TRANSCODER_HDR_WIDTH (TRANSCODER_HDR_WIDTH )   ,
        .PROB                 (PROB                 )
    )
    PCS_generator_inst (
        .o_tx_coded_f0        (o_tx_coded_f0        )   ,
        .o_frame_0            (o_frame_0            )   ,
        .o_frame_1            (o_frame_1            )   ,
        .o_frame_2            (o_frame_2            )   ,
        .o_frame_3            (o_frame_3            )   ,
        .i_txd                (i_txd                )   ,
        .i_txc                (i_txc                )   ,
        .i_data_sel_0         (i_data_sel_0         )   ,
        .i_valid              (i_valid              )   ,
        .i_enable             (i_enable             )   ,
        .i_random_0           (i_random_0           )   ,
        .i_tx_test_mode       (i_tx_test_mode       )   ,
        .i_rst_n              (!i_rst               )   ,    // Reset negado
        .clk                  (clk                  )
    );

    // Instantiate checker
    BASER_257b_checker#(
        .DATA_WIDTH         (DATA_WIDTH         )   ,
        .HDR_WIDTH          (HDR_WIDTH          )   ,
        .FRAME_WIDTH        (FRAME_WIDTH        )   ,
        .TC_DATA_WIDTH      (TC_DATA_WIDTH      )   ,
        .TC_HDR_WIDTH       (TC_HDR_WIDTH       )   ,
        .TC_WIDTH           (TC_WIDTH           )   ,
        .DATA_CHAR_PATTERN  (DATA_CHAR_PATTERN  )   ,
        .CTRL_CHAR_PATTERN  (CTRL_CHAR_PATTERN  )   ,
        .OSET_CHAR_PATTERN  (OSET_CHAR_PATTERN  )
    ) dut (
        .clk                (clk                )   ,
        .i_rst              (i_rst              )   ,
        .i_rx_xcoded        (i_rx_xcoded        )   ,
        .o_rx_coded_0       (o_rx_coded_0       )   ,
        .o_rx_coded_1       (o_rx_coded_1       )   ,
        .o_rx_coded_2       (o_rx_coded_2       )   ,
        .o_rx_coded_3       (o_rx_coded_3       )   ,
        .o_block_count      (o_block_count      )   ,
        .o_data_count       (o_data_count       )   ,
        .o_ctrl_count       (o_ctrl_count       )   ,
        .o_inv_block_count  (o_inv_block_count  )
    );


endmodule