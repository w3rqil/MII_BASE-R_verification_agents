/*
    Conexion entre el generador y el checker de señal 1.6TBASE-R
*/

`timescale 1ns/100ps
// `include "Modulos/signalGenerator/ejemplo/PCS_gen.sv"
// `include "Modulos/signalGenerator/rtl/BASER_257b_checker.sv"

/*
    TEST_1: test general
    TEST_2: todo datos (caso 1 y 2 en la presentacion, cambiar los parametros en el generador)
    TEST_3: todo control
    TEST_4: todo Error e Idle
    TEST_5: varios patrones en i_txd, algunos erroneos (caso 3 en la presentacion)
    TEST_6: varios patrones en i_txd, todos validos
    TEST_7: patrones aleatorios
    TEST_8: ejemplo de Idles constantes, del anexo 175A IEEE802.3 (descrambleado)
    TEST_9: sync header corrupto con los patrones de TEST_8
*/
`define TEST_5

/*
    INTERRUPT: muchos bloques invalidos interrumpen la simulacion y fallan el test
*/
// `define INTERRUPT

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
    parameter   TC_BLOCKS               = 4                             ;   // Four 64b blocks in a 257b block
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
    logic [TC_BLOCKS         - 1 : 0]   i_data_sel                      ;   /* Data selector                          */
    logic [                    1 : 0]   i_valid_gen                     ;   /* Input to enable frame generation       */    
    logic                               i_enable                        ;   /* Flag to enable frame generation        */
    logic                               i_random                        ;   /* Flag to enable random frame generation */
    logic                               i_tx_test_mode                  ;   /* Flag to enable TX test mode            */
    logic                               i_corrupt_header                ;   /* First bit is 0 and next 4 bits are '1111' */
    // 257b Checker
    logic [TC_WIDTH          - 1 : 0]   i_rx_xcoded                     ;   // Received data
    logic                               i_valid                         ;   // Enable check process. If 0, the outputs don't change.
    // 66b Checker
    logic [FRAME_WIDTH       - 1 : 0]   i_rx_coded  [TC_BLOCKS - 1 : 0] ;   //64b blocks
    logic [                    7 : 0]   i_pattern_mode                  ;

    /*
    *---------------------OUTPUTS------------------------
    */
    // Generator
    logic [TC_WIDTH          - 1 : 0]   o_tx_coded                                  ;   /* Output transcoder                      */
    logic [FRAME_WIDTH       - 1 : 0]   o_frame                 [TC_BLOCKS - 1 : 0] ;   /* Output frames                          */
    logic                               o_valid_gen                                 ;   // Output frames from generator are valid
    // 257b Checker
    logic [FRAME_WIDTH       - 1 : 0]   o_rx_coded_0                                ;   // 1st 64b block
    logic [FRAME_WIDTH       - 1 : 0]   o_rx_coded_1                                ;   // 2nd 64b block
    logic [FRAME_WIDTH       - 1 : 0]   o_rx_coded_2                                ;   // 3rd 64b block
    logic [FRAME_WIDTH       - 1 : 0]   o_rx_coded_3                                ;   // 4th 64b block
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
    *---------------------INTERRUPT------------------------
    */
    // Counter register
    logic [31:0] prev_257_inv_block_count;
    // State counter 
    integer state_count;

    // Pattern check modes
    localparam NONE  = 8'd0;
    localparam FIXED = 8'd1;
    localparam PRBS8 = 8'd2;

    // invalid blocks counter but it doesn't count invalid pattern
    logic [31:0] inv_block_no_pattern_count;

    // Invalid blocks percentage
    real inv_percent;

    // Generator's valid signal enables check process for 257b checker
    logic valid;

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // Loopback Generator-Checker
    assign i_rx_xcoded = o_tx_coded;
    assign i_rx_coded [0] = o_rx_coded_0;
    assign i_rx_coded [1] = o_rx_coded_1;
    assign i_rx_coded [2] = o_rx_coded_2;
    assign i_rx_coded [3] = o_rx_coded_3;

    always @(posedge clk) begin

        // // MII log
        // $display("%0t\t\t%16h\t\t%16h\t\t%16h\t\t%16h\t\t%16h", 
        //         $time, i_txd, o_txd[0], o_txd[1], o_txd[2], o_txd[3]);

        `ifdef INTERRUPT

        // Simulation interrupt
        if(o_257_inv_block_count == prev_257_inv_block_count) begin
            state_count <= 'd0;
        end
        else if(state_count < 100) begin
            state_count <= state_count + 'd1;
        end
        else begin
            $display("Error: TEST FAILED. Too many consecutive invalid blocks.");
            // Display all counters
            $display("Total Blocks Received: %0d"       ,   o_257_block_count       );
            $display("Data Blocks Received: %0d"        ,   o_257_data_count        );
            $display("Control Blocks Received: %0d"     ,   o_257_ctrl_count        );
            $display("Invalid Blocks Received: %0d"     ,   o_257_inv_block_count   );

            $finish;
        end
        prev_257_inv_block_count <= o_257_inv_block_count;
        
        `endif

    end

    initial begin
        // $dumpfile("Modulos/signalGenerator/tb/tb_BASER_gen_check.vcd");
        // $dumpvars();

        // // MII log
        // $display("Time\t\tTXD input\t\t\t\tTXD output (0)\t\t\tTXD output (1)\t\t\tTXD output (2)\t\t\tTXD output (3)");

        clk                 = 'b0       ;
        i_rst               = 'b1       ;
        i_data_sel          = 'b0000    ;
        i_enable            = 'b0       ;
        i_valid_gen         = 'b000     ;
        i_valid             = 'b0       ;
        i_tx_test_mode      = 'b0       ;
        i_corrupt_header    = 'b0       ;
        i_random            = 'b0       ;
        i_txd               = 'b0       ;
        i_txc               = 'b0       ;
        i_pattern_mode      = NONE      ;

        state_count         = '0        ;

        // Set the enable and desactive the reset
        #100                        ;
        @(posedge clk)              ;
        i_rst           = 1'b0      ;
        i_enable        = 1'b1      ;
        i_valid_gen     = 2'b11     ;

        `ifdef TEST_1
        `include "tests/TEST_1.sv"

        `elsif TEST_2
        `include "tests/TEST_2.sv"

        `elsif TEST_3
        `include "tests/TEST_3.sv"

        `elsif TEST_4
        `include "tests/TEST_4.sv"

        `elsif TEST_5
        `include "tests/TEST_5.sv"
        
        `elsif TEST_6
        `include "tests/TEST_6.sv"

        `elsif TEST_7
        `include "tests/TEST_7.sv"

        `elsif TEST_8
        `include "tests/TEST_8.sv"

        `elsif TEST_9
        `include "tests/TEST_9.sv"
        
        `elsif TEST_10
        `include "tests/TEST_10.sv"

        `endif

        inv_block_no_pattern_count =  o_257_inv_block_count 
                                    + o_66_inv_block_count[0]    + o_66_inv_block_count[1]   + o_66_inv_block_count[2]   + o_66_inv_block_count[3]
                                    - (o_66_inv_pattern_count[0] + o_66_inv_pattern_count[1] + o_66_inv_pattern_count[2] + o_66_inv_pattern_count[3]);
        
        inv_percent  = real'(inv_block_no_pattern_count) / real'(o_257_block_count) * 100;
        // inv_percent  = real'(o_257_inv_block_count)      / real'(o_257_block_count) * 100;

        // Display after all tests
        // if(inv_block_no_pattern_count == 0) begin
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
            // $display("Invalid Blocks Received: %0d", o_66_inv_format_count[i] + o_66_inv_sh_count[i]);
            $display("Invalid Blocks Received: %0d", o_66_inv_block_count[i]);
            // $display("\t-Invalid Pattern: %0d", 0);
            $display("\t-Invalid Pattern: %0d", o_66_inv_pattern_count[i]);
            $display("\t-Invalid Format/Block Type: %0d", o_66_inv_format_count[i]);
            $display("\t-Invalid Sync Header ('00' or '11'): %0d\n", o_66_inv_sh_count[i]);
        end

        $finish;
    end

    // Instantiate generator
    PCS_generator # (
        .NB_PAYLOAD_OUT         (DATA_WIDTH             ),
        .NB_HEADER_OUT          (HDR_WIDTH              ),
        // .FRAME_WIDTH            (FRAME_WIDTH            ),
        .NB_CONTROL_CHAR        (CTRL_WIDTH             ),
        .N_PCS_WORDS_OUT        (TC_BLOCKS              ),
        .NB_FRAME_IN            (TC_WIDTH               ),
        .NB_TRANSCODER_HDR_OUT  (TRANSCODER_HDR_WIDTH   ),
        .PROB                   (PROB                   )
    ) dut_gen (
        .o_tx_coded             (o_tx_coded             ),
        .o_frame                (o_frame                ),
        .o_valid                (valid                  ),
        .i_txd                  (i_txd                  ),
        .i_txc                  (i_txc                  ),
        .i_data_sel             (i_data_sel             ),
        .i_valid                (i_valid_gen            ),
        .i_enable               (i_enable               ),
        .i_random               (i_random               ),
        .i_tx_test_mode         (i_tx_test_mode         ),
        .i_corrupt_header       (i_corrupt_header       ),
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
        .clk                    (clk                    ),
        .i_rst                  (i_rst                  ),
        .i_valid                (valid                  ),
        // .i_valid                (i_valid                ),
        .i_rx_xcoded            (i_rx_xcoded            ),
        .o_rx_coded_0           (o_rx_coded_0           ),
        .o_rx_coded_1           (o_rx_coded_1           ),
        .o_rx_coded_2           (o_rx_coded_2           ),
        .o_rx_coded_3           (o_rx_coded_3           ),
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
                .i_valid                (valid                      ),
                // .i_valid                (i_valid                    ),
                .i_rx_coded             (i_rx_coded             [i] ),
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

endmodule