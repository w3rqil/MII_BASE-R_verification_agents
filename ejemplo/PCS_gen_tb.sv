
module PCS_generator_tb;

  // Parameters
  localparam  DATA_WIDTH           = 64                                                                                                                                                                                                                                                     ;                          
  localparam  HDR_WIDTH            = 2                                                                                                                                                                                                                                                      ;                          
  localparam  FRAME_WIDTH          = DATA_WIDTH + HDR_WIDTH                                                                                                                                                                                                                                 ;                          
  localparam  CONTROL_WIDTH        = 8                                                                                                                                                                                                                                                      ;                          
  localparam  TRANSCODER_BLOCKS    = 4                                                                                                                                                                                                                                                      ;                                   
  localparam  TRANSCODER_WIDTH     = 257                                                                                                                                                                                                                                                    ;                              
  localparam  TRANSCODER_HDR_WIDTH = 4                                                                                                                                                                                                                                                      ;                          
  localparam  PROB                 = 30                                                                                                                                                                                                                                                     ;                          
              
  logic [TRANSCODER_WIDTH  - 1 : 0] o_tx_coded_f0       /* Output transcoder                      */                                                                                                                                                                                        ;
  logic [FRAME_WIDTH       - 1 : 0] o_frame_0           /* Output frame 0                         */                                                                                                                                                                                        ;
  logic [FRAME_WIDTH       - 1 : 0] o_frame_1           /* Output frame 1                         */                                                                                                                                                                                        ;
  logic [FRAME_WIDTH       - 1 : 0] o_frame_2           /* Output frame 2                         */                                                                                                                                                                                        ;
  logic [FRAME_WIDTH       - 1 : 0] o_frame_3           /* Output frame 3                         */                                                                                                                                                                                        ;
  logic [DATA_WIDTH        - 1 : 0] i_txd               /* Input data                             */                                                                                                                                                                                        ;
  logic [CONTROL_WIDTH     - 1 : 0] i_txc               /* Input control byte                     */                                                                                                                                                                                        ;
  logic [TRANSCODER_BLOCKS - 1 : 0] i_data_sel_0        /* Data selector                          */                                                                                                                                                                                        ;
  logic [1                     : 0] i_valid             /* Input to enable frame generation       */                                                                                                                                                                                        ;    
  logic                             i_enable            /* Flag to enable frame generation        */                                                                                                                                                                                        ;
  logic                             i_random_0          /* Flag to enable random frame generation */                                                                                                                                                                                        ;
  logic                             i_tx_test_mode      /* Flag to enable TX test mode            */                                                                                                                                                                                        ;
  logic                             i_rst_n             /* Reset                                  */                                                                                                                                                                                        ;    
  logic                             clk                 /* Clock                                  */                                                                                                                                                                                        ;      
              


  PCS_generator # (
    .DATA_WIDTH           (DATA_WIDTH           )                                                                                                                                                                                                                                           ,
    .HDR_WIDTH            (HDR_WIDTH            )                                                                                                                                                                                                                                           ,
    .FRAME_WIDTH          (FRAME_WIDTH          )                                                                                                                                                                                                                                           ,
    .CONTROL_WIDTH        (CONTROL_WIDTH        )                                                                                                                                                                                                                                           ,
    .TRANSCODER_BLOCKS    (TRANSCODER_BLOCKS    )                                                                                                                                                                                                                                           ,
    .TRANSCODER_WIDTH     (TRANSCODER_WIDTH     )                                                                                                                                                                                                                                           ,
    .TRANSCODER_HDR_WIDTH (TRANSCODER_HDR_WIDTH )                                                                                                                                                                                                                                           ,
    .PROB                 (PROB                 )
  )
  PCS_generator_inst (                                                                            
    .o_tx_coded_f0        (o_tx_coded_f0        )                                                                                                                                                                                                                                           ,                       
    .o_frame_0            (o_frame_0            )                                                                                                                                                                                                                                           ,          
    .o_frame_1            (o_frame_1            )                                                                                                                                                                                                                                           ,                       
    .o_frame_2            (o_frame_2            )                                                                                                                                                                                                                                           ,                        
    .o_frame_3            (o_frame_3            )                                                                                                                                                                                                                                           ,          
    .i_txd                (i_txd                )                                                                                                                                                                                                                                           ,                      
    .i_txc                (i_txc                )                                                                                                                                                                                                                                           ,
    .i_data_sel_0         (i_data_sel_0         )                                                                                                                                                                                                                                           ,                      
    .i_valid              (i_valid              )                                                                                                                                                                                                                                           ,                          
    .i_enable             (i_enable             )                                                                                                                                                                                                                                           ,
    .i_random_0           (i_random_0           )                                                                                                                                                                                                                                           ,                       
    .i_tx_test_mode       (i_tx_test_mode       )                                                                                                                                                                                                                                           ,                       
    .i_rst_n              (i_rst_n              )                                                                                                                                                                                                                                           ,                           
    .clk                  (clk                  )                                                                                                                                                                                                                                           
      
  );

always #5  clk = ~clk                                                                                                                                                                                                                                                                       ; 

initial begin
    clk             = 'b0                                                                                                                                                                                                                                                                   ;
    i_rst_n         = 'b0                                                                                                                                                                                                                                                                   ;
    i_data_sel_0    = 'b0                                                                                                                                                                                                                                                                   ;
    i_enable        = 'b0                                                                                                                                                                                                                                                                   ;      
    i_valid         = 'b0                                                                                                                                                                                                                                                                   ;
    i_tx_test_mode  = 'b0                                                                                                                                                                                                                                                                   ;
    i_random_0      = 'b0                                                                                                                                                                                                                                                                   ;
    i_txd           = 'b0                                                                                                                                                                                                                                                                   ;
    i_txc           = 'b0                                                                                                                                                                                                                                                                   ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the enable and desactive the reset
    i_rst_n         = 1'b1                                                                                                                                                                                                                                                                  ;
    i_enable        = 1'b1                                                                                                                                                                                                                                                                  ;
    i_valid         = 2'b11                                                                                                                                                                                                                                                                 ;
    // Set the random generator
    i_random_0      = 1'b1                                                                                                                                                                                                                                                                  ;
    #1000                                                                                                                                                                                                                                                                                   ;  
    // Unset the random generator
    i_random_0      = 1'b0                                                                                                                                                                                                                                                                  ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the data sel 0 to data
    i_data_sel_0    = 4'b0001                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the data sel 1 to data
    i_data_sel_0    = 4'b0010                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 0 and 1 as data
    i_data_sel_0    = 4'b0011                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bit 2 as data
    i_data_sel_0    = 4'b0100                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 2 and 0 as data
    i_data_sel_0    = 4'b0101                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 2 and 1 as data
    i_data_sel_0    = 4'b0110                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 2, 1 and 0 as data
    i_data_sel_0    = 4'b0111                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bit 3 as data
    i_data_sel_0    = 4'b1000                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 3 and 0 as data
    i_data_sel_0    = 4'b1001                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 3 and 1 as data
    i_data_sel_0    = 4'b1010                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 3, 1 and 0 as data
    i_data_sel_0    = 4'b1011                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 3 and 2 as data
    i_data_sel_0    = 4'b1100                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 3, 2 and 0 as data
    i_data_sel_0    = 4'b1101                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the bits 3, 2 and 1 as data
    i_data_sel_0    = 4'b1110                                                                                                                                                                                                                                                               ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Set the random flag to 1 again
    i_random_0      = 1'b1                                                                                                                                                                                                                                                                  ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Desactivate scrambler, transcoder and PCS convertion
    i_valid         = 2'b00                                                                                                                                                                                                                                                                 ; 
    #100                                                                                                                                                                                                                                                                                    ;
    // Activate PCS convertion
    i_valid         = 2'b01                                                                                                                                                                                                                                                                 ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Activate the transcoder
    i_valid         = 2'b10                                                                                                                                                                                                                                                                 ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Activate the transcoder and PCS convertion
    i_valid         = 2'b11                                                                                                                                                                                                                                                                 ;
    #100                                                                                                                                                                                                                                                                                    ;                                                                                                                                                                                                                                                             ;
    // Activate the test mode
    i_tx_test_mode  = 1'b1                                                                                                                                                                                                                                                                  ;
    #100                                                                                                                                                                                                                                                                                    ;
    // Desactivate the test mode and change the inputs 
    i_tx_test_mode  = 1'b0                                                                                                                                                                                                                                                                  ;
    i_enable        = 1'b0                                                                                                                                                                                                                                                                  ;
    i_txc           = 8'h00;
    i_txd           = 64'hFFFFFFFFFFFFFFFF;
    #300;
    i_txd           = 64'hAAAAAAAAAAAAAAAA;
    #300;
    i_txd           = 64'h5555555555555555;
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

    $display("o_frame_0: %h", o_frame_0)                                                                                                                                                                                                                                                    ; 
    $display("o_frame_0: %b", o_frame_0)                                                                                                                                                                                                                                                    ;
    $display("o_frame_1: %h", o_frame_1)                                                                                                                                                                                                                                                    ; 
    $display("o_frame_1: %b", o_frame_1)                                                                                                                                                                                                                                                    ;
    $display("o_frame_2: %h", o_frame_2)                                                                                                                                                                                                                                                    ; 
    $display("o_frame_2: %b", o_frame_2)                                                                                                                                                                                                                                                    ;
    $display("o_frame_3: %h", o_frame_3)                                                                                                                                                                                                                                                    ; 
    $display("o_frame_3: %b", o_frame_3)                                                                                                                                                                                                                                                    ;
    $display("o_transcoder: %h", o_tx_coded_f0)                                                                                                                                                                                                                                             ;
    $display("o_transcoder: %b", o_tx_coded_f0)                                                                                                                                                                                                                                             ;
    #400                                                                                                                                                                                                                                                                                    ;
    $finish                                                                                                                                                                                                                                                                                 ;
end


endmodule