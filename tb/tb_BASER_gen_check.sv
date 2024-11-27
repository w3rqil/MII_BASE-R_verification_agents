/*
    Conexion entre el generador y el checker de BASE-R. Por ahora al checker entra solo
    una de las salidas del generador, que es uno de los canales donde sale el bloque de 257b
    antes de entrar al scrambler.
*/

`timescale 1ns/100ps
`include "Modulos/signalGenerator/ejemplo/PCS_gen.sv"
`include "Modulos/signalGenerator/rtl/BASER_257b_checker.sv"

module BASER_gen_check;

    // Parameters
    parameter int   DATA_WIDTH          = 64                        ;
    parameter  HDR_WIDTH            = 2                             ;
    parameter  FRAME_WIDTH          = DATA_WIDTH + HDR_WIDTH        ;
    parameter  CONTROL_WIDTH        = 8                             ;
    parameter  TRANSCODER_BLOCKS    = 4                             ;
    parameter  TRANSCODER_WIDTH     = 257                           ;
    parameter  TRANSCODER_HDR_WIDTH = 4                             ;
    parameter  PROB                 = 30                            ;

    parameter int   TC_DATA_WIDTH       = 4 * DATA_WIDTH            ;   //! 256 bits transcoded blocks (without header)
    parameter int   SH_WIDTH            = 1                         ;
    parameter int   TC_WIDTH            = TC_DATA_WIDTH + SH_WIDTH  ;   //! 257 bits transcoded blocks

    parameter       DATA_CHAR_PATTERN   = 8'hAA                     ;
    parameter       CTRL_CHAR_PATTERN   = 7'h00                     ;
    parameter       OSET_CHAR_PATTERN   = 4'hF                      ;

    logic [TRANSCODER_WIDTH  - 1 : 0] o_tx_scrambled_f0 ;   /* Output scrambler                       */
    logic [TRANSCODER_WIDTH  - 1 : 0] o_tx_scrambled_f1 ;   /* Output scrambler                       */
    logic [TRANSCODER_WIDTH  - 1 : 0] o_tx_coded_f0     ;   /* Output transcoder                      */
    logic [TRANSCODER_WIDTH  - 1 : 0] o_tx_coded_f1     ;   /* Output transcoder                      */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_0         ;   /* Output frame 0                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_1         ;   /* Output frame 1                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_2         ;   /* Output frame 2                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_3         ;   /* Output frame 3                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_4         ;   /* Output frame 4                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_5         ;   /* Output frame 5                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_6         ;   /* Output frame 6                         */
    logic [FRAME_WIDTH       - 1 : 0] o_frame_7         ;   /* Output frame 7                         */
    logic [DATA_WIDTH        - 1 : 0] i_txd             ;   /* Input data                             */
    logic [CONTROL_WIDTH     - 1 : 0] i_txc             ;   /* Input control byte                     */
    logic [TRANSCODER_BLOCKS - 1 : 0] i_data_sel_0      ;   /* Data selector                          */
    logic [TRANSCODER_BLOCKS - 1 : 0] i_data_sel_1      ;   /* Data selector                          */
    logic [2                     : 0] i_valid           ;   /* Input to enable frame generation       */    
    logic                             i_enable          ;   /* Flag to enable frame generation        */
    logic                             i_random_0        ;   /* Flag to enable random frame generation */
    logic                             i_random_1        ;   /* Flag to enable random frame generation */
    logic                             i_tx_test_mode    ;   /* Flag to enable TX test mode            */

    logic                    clk                ;   //! Clock input
    logic                    i_rst              ;   //! Asynchronous reset
    logic    [TC_WIDTH-1:0]  i_rx_coded         ;   //! Received data

    logic    [31:0]          o_block_count      ;   //! Total number of 257b blocks received
    logic    [31:0]          o_data_count       ;   //! Total number of 257b blocks with all 64b data block received
    logic    [31:0]          o_ctrl_count       ;   //! Total number of 257b blocks with at least one 64b control block received
    logic    [31:0]          o_inv_block_count  ;   //! Total number of invalid blocks

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // Pre-scrambler 257b block output from generator is the input of the checker.
    always @(*) begin
        i_rx_coded[0] = o_tx_coded_f0[256];
        for (int i = 0; i < 32; i++) begin
            i_rx_coded[(i * 8) + 1 +: 8] = o_tx_coded_f0[((32 - i) * 8) - 1 -: 8];
        end 
    end

    initial begin
        $dumpfile("Modulos/signalGenerator/tb/tb_BASER_gen_check.vcd");
        $dumpvars();
        clk             = 'b0       ;
        i_rst           = 'b1       ;
        i_data_sel_0    = 'b0000    ;
        i_data_sel_1    = 'b0000    ;
        i_enable        = 'b0       ;      
        i_valid         = 'b000     ;
        i_tx_test_mode  = 'b0       ;
        i_random_0      = 'b0       ;
        i_random_1      = 'b0       ;
        i_txd           = 'b0       ;
        i_txc           = 'b0       ;
        #100                        ;

        // Set the enable and desactive the reset
        i_rst         = 1'b0      ;
        i_enable        = 1'b1      ;
        i_valid         = 3'b111    ;

        // Set the data sel 0 to data
        i_data_sel_0    = 4'b0001   ;
        #100                        ;
        i_data_sel_0 = 4'b0010;
        #100;
        // Set the data sel 0 to ctrl
        i_data_sel_0    = 4'b0000   ;
        #100                        ;

        // Change the inputs

        i_enable        = 1'b0                  ;
        i_txc           = 8'h00                 ;
        i_txd           = 64'hAAAAAAAAAAAAAAAA  ;
        #500                                    ;
        $finish                                 ;
    end

    // Instantiate generator
    PCS_generator # (
        .DATA_WIDTH           (DATA_WIDTH           )   ,
        .HDR_WIDTH            (HDR_WIDTH            )   ,
        .FRAME_WIDTH          (FRAME_WIDTH          )   ,
        .CONTROL_WIDTH        (CONTROL_WIDTH        )   ,
        .TRANSCODER_BLOCKS    (TRANSCODER_BLOCKS    )   ,
        .TRANSCODER_WIDTH     (TRANSCODER_WIDTH     )   ,
        .TRANSCODER_HDR_WIDTH (TRANSCODER_HDR_WIDTH )   ,
        .PROB                 (PROB                 )
    )
    PCS_generator_inst (                                                                            
        .o_tx_scrambled_f0    (o_tx_scrambled_f0    )   ,                        
        .o_tx_scrambled_f1    (o_tx_scrambled_f1    )   ,                        
        .o_tx_coded_f0        (o_tx_coded_f0        )   ,                       
        .o_tx_coded_f1        (o_tx_coded_f1        )   ,               
        .o_frame_0            (o_frame_0            )   ,          
        .o_frame_1            (o_frame_1            )   ,                       
        .o_frame_2            (o_frame_2            )   ,                        
        .o_frame_3            (o_frame_3            )   ,          
        .o_frame_4            (o_frame_4            )   ,                       
        .o_frame_5            (o_frame_5            )   ,                        
        .o_frame_6            (o_frame_6            )   ,                                                                                                                                                                                                                                                                                  
        .o_frame_7            (o_frame_7            )   ,                                                                                                                                                                                                                                                                                  
        .i_txd                (i_txd                )   ,                      
        .i_txc                (i_txc                )   ,
        .i_data_sel_0         (i_data_sel_0         )   ,                      
        .i_data_sel_1         (i_data_sel_1         )   ,                      
        .i_valid              (i_valid              )   ,                          
        .i_enable             (i_enable             )   ,
        .i_random_0           (i_random_0           )   ,                       
        .i_random_1           (i_random_1           )   ,                       
        .i_tx_test_mode       (i_tx_test_mode       )   ,                       
        .i_rst_n              (!i_rst               )   ,    // Reset negado
        .clk                  (clk                  )
    );

    // Instantiate checker
    BASER_257b_checker#(
        .DATA_WIDTH         (DATA_WIDTH         )   ,
        .TC_DATA_WIDTH      (TC_DATA_WIDTH      )   ,
        .SH_WIDTH           (SH_WIDTH           )   ,
        .TC_WIDTH           (TC_WIDTH           )   ,
        .DATA_CHAR_PATTERN  (DATA_CHAR_PATTERN  )   ,
        .CTRL_CHAR_PATTERN  (CTRL_CHAR_PATTERN  )   ,
        .OSET_CHAR_PATTERN  (OSET_CHAR_PATTERN  )
    ) dut (
        .clk                (clk                )   ,
        .i_rst              (i_rst              )   ,
        .i_rx_coded         (i_rx_coded         )   ,
        .o_block_count      (o_block_count      )   ,
        .o_data_count       (o_data_count       )   ,
        .o_ctrl_count       (o_ctrl_count       )   ,
        .o_inv_block_count  (o_inv_block_count  )
    );


endmodule