module PCS_generator                
#(              

    parameter DATA_WIDTH           = 64                                                                                                                                                                                                                                                             , 
    parameter HDR_WIDTH            = 2                                                                                                                                                                                                                                                              , 
    parameter FRAME_WIDTH          = DATA_WIDTH + HDR_WIDTH  /* Frame width                           */                                                                                                                                                                                            ,                                                                                                                                                                                             
    parameter CONTROL_WIDTH        = 8                       /* Control width of 8 bits               */                                                                                                                                                                                            ,
    parameter TRANSCODER_BLOCKS    = 4                       /* Number of transcoder blocks           */                                                                                                                                                                                            ,
    parameter TRANSCODER_WIDTH     = 257                     /* Transcoder width                      */                                                                                                                                                                                            ,
    parameter TRANSCODER_HDR_WIDTH = 4                       /* Transcoder header width               */                                                                                                                                                                                            ,
    parameter PROB                 = 5                       /* Probability of inserting control byte */                                                                                                                                                                                            
)               
(               
    output logic [TRANSCODER_WIDTH  - 1 : 0] o_tx_coded_f0       /* Output transcoder                      */                                                                                                                                                                                       ,
    output logic [FRAME_WIDTH       - 1 : 0] o_frame_0           /* Output frame 0                         */                                                                                                                                                                                       ,
    output logic [FRAME_WIDTH       - 1 : 0] o_frame_1           /* Output frame 1                         */                                                                                                                                                                                       ,
    output logic [FRAME_WIDTH       - 1 : 0] o_frame_2           /* Output frame 2                         */                                                                                                                                                                                       ,
    output logic [FRAME_WIDTH       - 1 : 0] o_frame_3           /* Output frame 3                         */                                                                                                                                                                                       ,
    input  logic [DATA_WIDTH        - 1 : 0] i_txd               /* Input data                             */                                                                                                                                                                                       ,
    input  logic [CONTROL_WIDTH     - 1 : 0] i_txc               /* Input control byte                     */                                                                                                                                                                                       ,
    input  logic [TRANSCODER_BLOCKS - 1 : 0] i_data_sel_0        /* Data selector                          */                                                                                                                                                                                       ,
    input  logic [1                     : 0] i_valid             /* Input to enable frame generation       */                                                                                                                                                                                       ,    
    input  logic                             i_enable            /* Flag to enable frame generation        */                                                                                                                                                                                       ,
    input  logic                             i_random_0          /* Flag to enable random frame generation */                                                                                                                                                                                       ,
    input  logic                             i_tx_test_mode      /* Flag to enable TX test mode            */                                                                                                                                                                                       ,
    input  logic                             i_rst_n             /* Reset                                  */                                                                                                                                                                                       ,    
    input  logic                             clk                 /* Clock                                  */                                                                                                                                                                                             

);              

localparam [HDR_WIDTH - 1 : 0]              
    DATA_SYNC = 2'b10 /* Data sync    */                                                                                                                                                                                                                                                            ,
    CTRL_SYNC = 2'b01 /* Control sync */                                                                                                                                                                                                                                                            ;

localparam [CONTROL_WIDTH - 1 : 0]              
    CTRL_IDLE  = 8'h00   /* Control idle     */                                                                                                                                                                                                                                                     ,
    CTRL_LPI   = 8'h01   /* Control LPI      */                                                                                                                                                                                                                                                     ,
    CTRL_START = 8'h00   /* Control start    */                                                                                                                                                                                                                                                     ,
    CTRL_TERM  = 8'h00   /* Control terminate*/                                                                                                                                                                                                                                                     ,
    CTRL_ERROR = 8'h1E   /* Control error    */                                                                                                                                                                                                                                                     ,
    CTRL_SEQ   = 8'h4B   /* Control sequence */                                                                                                                                                                                                                                                     ;

localparam [CONTROL_WIDTH - 1 : 0]              
    MII_IDLE  = 8'h07   /* MII idle     */                                                                                                                                                                                                                                                          ,
    MII_LPI   = 8'h06   /* MII LPI      */                                                                                                                                                                                                                                                          ,
    MII_START = 8'hFB   /* MII start    */                                                                                                                                                                                                                                                          ,
    MII_TERM  = 8'hFD   /* MII terminate*/                                                                                                                                                                                                                                                          ,
    MII_ERROR = 8'hFE   /* MII error    */                                                                                                                                                                                                                                                          ,
    MII_SEQ   = 8'h9C   /* MII sequence ordered set */                                                                                                                                                                                                                                              ;

localparam [DATA_WIDTH - 1 : 0]             
    FIXED_PATTERN_0_DATA = 64'hAAAAAAAAAAAAAAAA                                                                                                                                                                                                                                                     ,
    FIXED_PATTERN_1_DATA = 64'h3333333333333333                                                                                                                                                                                                                                                     ,
    FIXED_PATTERN_2_DATA = 64'hFFFFFFFFFFFFFFFF                                                                                                                                                                                                                                                     ,
    FIXED_PATTERN_3_DATA = 64'h0000000000000000                                                                                                                                                                                                                                                     ,
    FIXED_PATTERN_0_CTRL = {8{MII_IDLE}}                                                                                                                                                                                                                                                            , 
    FIXED_PATTERN_1_CTRL = {MII_START, {7{8'hAA}}}                                                                                                                                                                                                                                                  , 
    FIXED_PATTERN_2_CTRL = {MII_SEQ  , {7{8'h33}}}                                                                                                                                                                                                                                                  ,
    FIXED_PATTERN_3_CTRL = {MII_TERM , {7{8'h00}}}                                                                                                                                                                                                                                                  ;                                                      

localparam [CONTROL_WIDTH - 1 : 0]              
    BLOCK_TYPE_FIELD_0  = 8'h1E   /* Block type field 0 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_1  = 8'h78   /* Block type field 1 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_2  = 8'h4B   /* Block type field 2 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_3  = 8'h87   /* Block type field 3 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_4  = 8'h99   /* Block type field 4 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_5  = 8'hAA   /* Block type field 5 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_6  = 8'hB4   /* Block type field 6 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_7  = 8'hCC   /* Block type field 7 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_8  = 8'hD2   /* Block type field 8 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_9  = 8'hE1   /* Block type field 9 */                                                                                                                                                                                                                                          ,
    BLOCK_TYPE_FIELD_10 = 8'hFF   /* Block type field 10 */                                                                                                                                                                                                                                         ;

localparam [CONTROL_WIDTH - 1 : 0]
    TXC_TYPE_FIELD_0  = 8'hFF   /* All control      */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_1  = 8'h01   /* All data         */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_2  = 8'hF1   /* Ordered set      */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_3  = 8'hFF   /* End in lane 0    */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_4  = 8'hFE   /* End in lane 1    */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_5  = 8'hFC   /* End in lane 2    */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_6  = 8'hF8   /* End in lane 3    */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_7  = 8'hF0   /* End in lane 4    */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_8  = 8'hE0   /* End in lane 5    */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_9  = 8'hC0   /* End in lane 6    */                                                                                                                                                                                                                                               ,
    TXC_TYPE_FIELD_10 = 8'h80   /* End in lane 7    */                                                                                                                                                                                                                                               ,
    TXC_TYPE_DATA     = 8'h00                                                                                                                                                                                                                                                                        ;                                        

// Local variables              
logic [CONTROL_WIDTH     - 1 : 0] mii_txc_0     /* Output frame */                                                                                                                                                                                                                                   ;
logic [CONTROL_WIDTH     - 1 : 0] mii_txc_1     /* Output frame */                                                                                                                                                                                                                                   ;
logic [CONTROL_WIDTH     - 1 : 0] mii_txc_2     /* Output frame */                                                                                                                                                                                                                                   ;
logic [CONTROL_WIDTH     - 1 : 0] mii_txc_3     /* Output frame */                                                                                                                                                                                                                                   ;
logic [DATA_WIDTH        - 1 : 0] mii_txd_0     /* Output frame */                                                                                                                                                                                                                                   ;
logic [DATA_WIDTH        - 1 : 0] mii_txd_1     /* Output frame */                                                                                                                                                                                                                                   ;
logic [DATA_WIDTH        - 1 : 0] mii_txd_2     /* Output frame */                                                                                                                                                                                                                                   ;
logic [DATA_WIDTH        - 1 : 0] mii_txd_3     /* Output frame */                                                                                                                                                                                                                                   ;
logic [FRAME_WIDTH       - 1 : 0] frame_reg_0    /* Frame register */                                                                                                                                                                                                                                ;
logic [FRAME_WIDTH       - 1 : 0] frame_reg_1    /* Frame register */                                                                                                                                                                                                                                ;
logic [FRAME_WIDTH       - 1 : 0] frame_reg_2    /* Frame register */                                                                                                                                                                                                                                ;
logic [FRAME_WIDTH       - 1 : 0] frame_reg_3    /* Frame register */                                                                                                                                                                                                                                ;                                                       
logic [FRAME_WIDTH       - 1 : 0] frame_invert_reg_0 /* Frame register */                                                                                                                                                                                                                            ;
logic [FRAME_WIDTH       - 1 : 0] frame_invert_reg_1 /* Frame register */                                                                                                                                                                                                                            ;
logic [FRAME_WIDTH       - 1 : 0] frame_invert_reg_2 /* Frame register */                                                                                                                                                                                                                            ;
logic [FRAME_WIDTH       - 1 : 0] frame_invert_reg_3 /* Frame register */                                                                                                                                                                                                                            ;
logic [TRANSCODER_WIDTH  - 1 : 0] transcoder_reg_0 /* Transcoder register */                                                                                                                                                                                                                         ;
logic [TRANSCODER_WIDTH  - 1 : 0] transcoder_invert_reg_0 /* Transcoder register */                                                                                                                                                                                                                  ;
logic [                    1 : 0] counter                                                                                                                                                                                                                                                            ;

// Task to generate a PCS frame             
task automatic generate_frame(              
    output logic [DATA_WIDTH    - 1 : 0] o_txd      /* Output frame data*/                                                                                                                                                                                                                          ,
    output logic [CONTROL_WIDTH - 1 : 0] o_txc      /* Output ontrol byte */                                                                                                                                                                                                                        ,
    input  int                           i_number       /* Random number */                                                                                                                                                                                                                             
)                                                                                                                                                                                                                                                                                                   ;
    logic         [DATA_WIDTH    - 1 : 0] data_block       /* Block of data */                                                                                                                                                                                                                      ;
    logic         [CONTROL_WIDTH - 1 : 0] txc              /* Control byte */                                                                                                                                                                                                                       ;
    logic         [DATA_WIDTH    - 1 : 0] txd              /* Data byte */                                                                                                                                                                                                                          ;
    automatic int                         insert_control   /* Flag to insert control byte */                                                                                                                                                                                                        ;             

    // Generate a random data block             
    data_block = $urandom($time + i_number) % 64'hFFFFFFFFFFFFFFFF                                                                                                                                                                                                                                  ;                                            

    // Decide wheter insert control byte or not             
    insert_control = $urandom($time + i_number) % 100                                                                                                                                                                                                                                               ;

    // Create the frame             
    if (insert_control < PROB) begin                
        // Choose a random control byte between 0 to 2              
        // Choose a byte position to insert control byte                
        case ($urandom($time + i_number) % 11)              
            0: begin
                // [ FF ] [ CTRL CTRL CTRL CTRL CTRL CTRL CTRL  CTRL ]                
                txd =  {MII_IDLE[CONTROL_WIDTH - 2 : 0]                                                                                                                                                                                                                                             , 
                        MII_IDLE[CONTROL_WIDTH - 2 : 0]                                                                                                                                                                                                                                             , 
                        MII_IDLE[CONTROL_WIDTH - 2 : 0]                                                                                                                                                                                                                                             , 
                        MII_IDLE[CONTROL_WIDTH - 2 : 0]                                                                                                                                                                                                                                             , 
                        MII_IDLE[CONTROL_WIDTH - 2 : 0]                                                                                                                                                                                                                                             , 
                        MII_IDLE[CONTROL_WIDTH - 2 : 0]                                                                                                                                                                                                                                             , 
                        MII_IDLE[CONTROL_WIDTH - 2 : 0]                                                                                                                                                                                                                                             , 
                        MII_IDLE[CONTROL_WIDTH - 2 : 0]}                                                                                                                                                                                                                                            ;
                txc = TXC_TYPE_FIELD_0                                                                                                                                                                                                                                                              ;    
            end             
            1: begin
                // [ B0 ] [ FB DATA DATA DATA DATA DATA DATA DATA ]                
                txd = {MII_START, data_block[DATA_WIDTH - 9 : 0]}                                                                                                                                                                                                                                   ;                                       
                txc = TXC_TYPE_FIELD_1                                                                                                                                                                                                                                                              ; 
            end             
            2: begin 
                // [ F1 ] [ 9C DATA DATA DATA 00 00 00 00 ]               
                txd = {MII_SEQ, data_block[DATA_WIDTH - 9 -: 24], 32'b0}                                                                                                                                                                                                                            ;                                       
                txc = TXC_TYPE_FIELD_2                                                                                                                                                                                                                                                              ; 
            end             
            3: begin       
                // [ FF ] [ FD IDLE IDLE IDLE IDLE IDLE IDLE IDLE ]         
                txd = {MII_TERM, {7{MII_IDLE}}}                                                                                                                                                                                                                                                     ;
                txc = TXC_TYPE_FIELD_3                                                                                                                                                                                                                                                              ;
            end             
            4: begin       
                // [ FE ] [ DATA FD IDLE IDLE IDLE IDLE IDLE IDLE ]         
                txd = {data_block[DATA_WIDTH - 1 -: 8], MII_TERM, {6{MII_IDLE}}}                                                                                                                                                                                                                    ;                                               
                txc = TXC_TYPE_FIELD_4                                                                                                                                                                                                                                                              ;            
            end             
            5: begin  
                // [ FD ] [ DATA DATA FD IDLE IDLE IDLE IDLE IDLE ]              
                txd = {data_block[DATA_WIDTH - 1 -: 16], MII_TERM, {5{MII_IDLE}}}                                                                                                                                                                                                                   ;                                               
                txc = TXC_TYPE_FIELD_5                                                                                                                                                                                                                                                              ;                                                                                                                                                                                                                                                                          
            end             
            6: begin    
                // [ FC ] [ DATA DATA DATA FD IDLE IDLE IDLE IDLE ]            
                txd = {data_block[DATA_WIDTH - 1 -: 24], MII_TERM, {4{MII_IDLE}}}                                                                                                                                                                                                                   ;                                               
                txc = TXC_TYPE_FIELD_6                                                                                                                                                                                                                                                              ;            
            end             
            7: begin     
                // [ FB ] [ DATA DATA DATA DATA FD IDLE IDLE IDLE ]           
                txd = {data_block[DATA_WIDTH - 1 -: 32], MII_TERM, {3{MII_IDLE}}}                                                                                                                                                                                                                   ;                                               
                txc = TXC_TYPE_FIELD_7                                                                                                                                                                                                                                                              ;            
            end             
            8: begin     
                // [ FA ] [ DATA DATA DATA DATA DATA FD IDLE IDLE ]           
                txd = {data_block[DATA_WIDTH - 1 -: 40], MII_TERM, {2{MII_IDLE}}}                                                                                                                                                                                                                   ;                                               
                txc = TXC_TYPE_FIELD_8                                                                                                                                                                                                                                                              ; 
            end             
            9: begin  
                // [ F9 ] [ DATA DATA DATA DATA DATA DATA FD IDLE ]              
                txd = {data_block[DATA_WIDTH - 1 -: 48], MII_TERM, {MII_IDLE}}                                                                                                                                                                                                                      ;                                               
                txc = TXC_TYPE_FIELD_9                                                                                                                                                                                                                                                              ; 
            end             
            10: begin   
                // [ F8 ] [ DATA DATA DATA DATA DATA DATA DATA FD ]            
                txd = {data_block[DATA_WIDTH - 1 -: 56], MII_TERM}                                                                                                                                                                                                                                  ;                                               
                txc = TXC_TYPE_FIELD_10                                                                                                                                                                                                                                                             ; 
            end             
        endcase                                                                                                                                                                                                                                                         
    end else begin              
         // Use data sync if no control byte                
       txd = data_block                                                                                                                                                                                                                                                                             ;
       txc = TXC_TYPE_DATA                                                                                                                                                                                                                                                                          ;        
    end             
    o_txd = txd                                                                                                                                                                                                                                                                                     ;
    o_txc = txc                                                                                                                                                                                                                                                                                     ;
endtask       

task automatic convert_mii(
    input  logic [CONTROL_WIDTH - 1 : 0] i_txc /* Input control byte*/                                                                                                                                                                                                                              ,
    input  logic [DATA_WIDTH    - 1 : 0] i_txd /* Input data byte   */                                                                                                                                                                                                                              ,                 
    output logic [DATA_WIDTH    - 1 : 0] o_pcs_txd /* Output data byte*/                                                                                                                                                                                                                                                                          
);
    logic [DATA_WIDTH - 1 : 0] pcs_txd /* Output data byte*/                                                                                                                                                                                                                                        ;
    int i;
    for(i = 0; i < DATA_WIDTH / 8; i = i + 1) begin
        if(i_txc[i]) begin
            case(i_txd[8* (i + 1) -1 -: 8])
                // Replace MII control bytes with PCS control bytes
                MII_IDLE  : pcs_txd[8*(i+1) - 1 -: 8] = CTRL_IDLE                                                                                                                                                                                                                                       ;
                MII_LPI   : pcs_txd[8*(i+1) - 1 -: 8] = CTRL_LPI                                                                                                                                                                                                                                        ;
                MII_START : pcs_txd[8*(i+1) - 1 -: 8] = CTRL_START                                                                                                                                                                                                                                      ;
                MII_TERM  : pcs_txd[8*(i+1) - 1 -: 8] = CTRL_TERM                                                                                                                                                                                                                                       ;
                MII_ERROR : pcs_txd[8*(i+1) - 1 -: 8] = CTRL_ERROR                                                                                                                                                                                                                                      ;
                MII_SEQ   : pcs_txd[8*(i+1) - 1 -: 8] = CTRL_SEQ                                                                                                                                                                                                                                        ;
                default   : pcs_txd[8*(i+1) - 1 -: 8] = CTRL_ERROR                                                                                                                                                                                                                                      ;
            endcase 
        end
    end

    o_pcs_txd = pcs_txd /* Output data byte*/                                                                                                                                                                                                                                                       ;                

endtask

task automatic invert_64_frame(
    output logic [FRAME_WIDTH - 1 : 0] o_frame, /* Output frame 0  */
    input  logic [FRAME_WIDTH - 1 : 0] i_frame /* Input frame 0   */
);

    logic [FRAME_WIDTH - 1 : 0] frame                                                                                                                                                                                                                                                               ;

    frame [HDR_WIDTH - 1: 0] = i_frame [FRAME_WIDTH - 1 -: HDR_WIDTH]                                                                                                                                                                                                                                 ;
    for(int i = 0; i < DATA_WIDTH / 8; i = i + 1) begin
        frame[CONTROL_WIDTH * (i+1) + HDR_WIDTH - 1 -: CONTROL_WIDTH] = i_frame[DATA_WIDTH - 1 - CONTROL_WIDTH*i -: CONTROL_WIDTH]                                                                                                                                                                              ;  
    end

    o_frame = frame                                                                                                                                                                                                                                                                                 ;
    
endtask

task automatic revert_64_frame(
    output logic [FRAME_WIDTH - 1 : 0] o_frame, /* Output frame 0  */
    input  logic [FRAME_WIDTH - 1 : 0] i_frame /* Input frame 0   */
);

    logic [FRAME_WIDTH - 1 : 0] frame                                                                                                                                                                                                                                                               ;

    frame[FRAME_WIDTH - 1 -: HDR_WIDTH] = i_frame[HDR_WIDTH -: 0]                                                                                                                                                                                                                                   ;
    for(int i = 0; i < DATA_WIDTH / 8; i = i + 1) begin
        frame[DATA_WIDTH - 1 - CONTROL_WIDTH*i -: CONTROL_WIDTH] = i_frame[CONTROL_WIDTH * (i+1) + HDR_WIDTH - 1 -: CONTROL_WIDTH]                                                                                                                                                                  ;
    end

    o_frame = frame                                                                                                                                                                                                                                                                                 ;
endtask

task automatic invert_257_frame(
    output logic [TRANSCODER_WIDTH - 1 : 0] o_frame, /* Output frame 0  */
    input  logic [TRANSCODER_WIDTH - 1 : 0] i_frame /* Input frame 0   */
);
    logic [TRANSCODER_WIDTH - 1 : 0] frame                                                                                                                                                                                                                                                          ;

    frame[0] = i_frame[TRANSCODER_WIDTH - 1]                                                                                                                                                                                                                                                        ;
    for(int i = 0; i < 32; i = i + 1'b1) begin
        frame[CONTROL_WIDTH * (i+1) -: CONTROL_WIDTH] = i_frame[TRANSCODER_WIDTH - 2 - CONTROL_WIDTH*i -: CONTROL_WIDTH]                                                                                                                                                                            ;
    end

    o_frame = frame                                                                                                                                                                                                                                                                                 ;
endtask

task automatic revert_257_frame(
    output logic [TRANSCODER_WIDTH - 1 : 0] o_frame, /* Output frame 0  */
    input  logic [TRANSCODER_WIDTH - 1 : 0] i_frame /* Input frame 0   */
);

    logic [TRANSCODER_WIDTH - 1 : 0] frame                                                                                                                                                                                                                                                          ;

    frame[TRANSCODER_WIDTH - 1] = i_frame[0]                                                                                                                                                                                                                                                        ;
    for(int i = 0; i < 32; i = i + 1'b1) begin
        frame[TRANSCODER_WIDTH - 2 - CONTROL_WIDTH*i -: CONTROL_WIDTH] = i_frame[CONTROL_WIDTH * (i+1) -: CONTROL_WIDTH]                                                                                                                                                                            ;
    end

    o_frame = frame                                                                                                                                                                                                                                                                                 ;
endtask

task automatic mii_to_pcs(
    input  logic [DATA_WIDTH    - 1 : 0] i_txd /* Input control byte*/                                                                                                                                                                                                                              ,
    input  logic [CONTROL_WIDTH - 1 : 0] i_txc /* Input data byte   */                                                                                                                                                                                                                              ,
    output logic [FRAME_WIDTH   - 1 : 0] o_frame /* Output frame 0  */                                                                                                                                                                                                                              
);

    logic [DATA_WIDTH  - 1 : 0] pcs_data /* Output data byte*/                                                                                                                                                                                                                                      ;
    logic [FRAME_WIDTH - 1 : 0] frame /* Frame 0 */                                                                                                                                                                                                                                                 ;
    logic [FRAME_WIDTH - 1 : 0] invert_frame /* Frame 0 */                                                                                                                                                                                                                                          ;

    convert_mii(i_txc, i_txd, pcs_data)                                                                                                                                                                                                                                                             ;
    
    if(i_txc[0]) begin
        // Compare control byte with PCS control bytes and generate frame
        frame =     (i_txc == TXC_TYPE_FIELD_0)                                         ? {CTRL_SYNC, BLOCK_TYPE_FIELD_0, 
                        pcs_data[DATA_WIDTH - 0*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1], 
                        pcs_data[DATA_WIDTH - 1*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1], 
                        pcs_data[DATA_WIDTH - 2*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 3*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 4*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 5*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 6*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],        
                        pcs_data[DATA_WIDTH - 7*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1]}                                                                                                                                                                                                            :
                    (i_txc == TXC_TYPE_FIELD_1 && 
                    i_txd[DATA_WIDTH - 1 -: CONTROL_WIDTH] == MII_START)                 ? {CTRL_SYNC, BLOCK_TYPE_FIELD_1,
                        i_txd  [DATA_WIDTH - 1*CONTROL_WIDTH - 1   : 0                ]}                                                                                                                                                                                                            :
                    (i_txc == TXC_TYPE_FIELD_2 
                    && i_txd[DATA_WIDTH - 1 -: CONTROL_WIDTH] == MII_SEQ)                ? {CTRL_SYNC, BLOCK_TYPE_FIELD_2,
                        i_txd  [DATA_WIDTH - 1*CONTROL_WIDTH - 1  -: 3*CONTROL_WIDTH  ],
                        CTRL_SEQ[CONTROL_WIDTH - 5 : 0                                ],
                        28'b0}                                                                                                                                                                                                                                                                      :
                    (i_txc == TXC_TYPE_FIELD_3 && 
                    i_txd[DATA_WIDTH - 0*CONTROL_WIDTH -1 -: CONTROL_WIDTH] == MII_TERM)  ? {CTRL_SYNC, BLOCK_TYPE_FIELD_3,
                        {7{1'b0}},
                        pcs_data[DATA_WIDTH - 1*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1], 
                        pcs_data[DATA_WIDTH - 2*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 3*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 4*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 5*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 6*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],        
                        pcs_data[DATA_WIDTH - 7*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1]}                                                                                                                                                                                                            :
                    (i_txc == TXC_TYPE_FIELD_4 && 
                    i_txd[DATA_WIDTH - 1*CONTROL_WIDTH - 1 -: CONTROL_WIDTH] == MII_TERM) ? {CTRL_SYNC, BLOCK_TYPE_FIELD_4,
                        i_txd   [DATA_WIDTH - 1                   -: CONTROL_WIDTH    ],
                        {6{1'b0}},
                        pcs_data[DATA_WIDTH - 2*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 3*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 4*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 5*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 6*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],        
                        pcs_data[DATA_WIDTH - 7*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1]}                                                                                                                                                                                                            :
                    (i_txc == TXC_TYPE_FIELD_5 &&
                    i_txd[DATA_WIDTH - 2*CONTROL_WIDTH - 1 -: CONTROL_WIDTH] == MII_TERM) ? {CTRL_SYNC, BLOCK_TYPE_FIELD_5,
                        i_txd   [DATA_WIDTH - 1                   -: 2*CONTROL_WIDTH  ],
                        {5{1'b0}},
                        pcs_data[DATA_WIDTH - 3*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 4*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 5*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 6*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],        
                        pcs_data[DATA_WIDTH - 7*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1]}                                                                                                                                                                                                            :
                    (i_txc == TXC_TYPE_FIELD_6 &&
                    i_txd[DATA_WIDTH - 3*CONTROL_WIDTH - 1 -: CONTROL_WIDTH] == MII_TERM) ? {CTRL_SYNC, BLOCK_TYPE_FIELD_6,
                        i_txd   [DATA_WIDTH - 1                   -: 3*CONTROL_WIDTH  ],
                        {4{1'b0}},
                        pcs_data[DATA_WIDTH - 4*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 5*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 6*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],        
                        pcs_data[DATA_WIDTH - 7*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1]}                                                                                                                                                                                                            :
                    (i_txc == TXC_TYPE_FIELD_7 &&
                    i_txd[DATA_WIDTH - 4*CONTROL_WIDTH - 1 -: CONTROL_WIDTH] == MII_TERM) ? {CTRL_SYNC, BLOCK_TYPE_FIELD_7,
                        i_txd   [DATA_WIDTH - 1                   -: 4*CONTROL_WIDTH  ],
                        {3{1'b0}},
                        pcs_data[DATA_WIDTH - 5*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],
                        pcs_data[DATA_WIDTH - 6*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],        
                        pcs_data[DATA_WIDTH - 7*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1]}                                                                                                                                                                                                            :
                    (i_txc == TXC_TYPE_FIELD_8 &&
                    i_txd[DATA_WIDTH - 5*CONTROL_WIDTH - 1 -: CONTROL_WIDTH] == MII_TERM) ? {CTRL_SYNC, BLOCK_TYPE_FIELD_8,
                        i_txd   [DATA_WIDTH - 1                   -: 5*CONTROL_WIDTH  ],
                        {2{1'b0}},
                        pcs_data[DATA_WIDTH - 6*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1],        
                        pcs_data[DATA_WIDTH - 7*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1]}                                                                                                                                                                                                            :
                    (i_txc == TXC_TYPE_FIELD_9 &&
                    i_txd[DATA_WIDTH - 6*CONTROL_WIDTH - 1 -: CONTROL_WIDTH] == MII_TERM) ? {CTRL_SYNC, BLOCK_TYPE_FIELD_9,
                        i_txd   [DATA_WIDTH - 1                   -: 6*CONTROL_WIDTH  ],
                        {1{1'b0}},
                        pcs_data[DATA_WIDTH - 7*CONTROL_WIDTH - 2 -: CONTROL_WIDTH - 1]}                                                                                                                                                                                                            :
                    (i_txc == TXC_TYPE_FIELD_10 &&
                    i_txd[DATA_WIDTH - 7*CONTROL_WIDTH - 1 -: CONTROL_WIDTH] == MII_TERM) ? {CTRL_SYNC, BLOCK_TYPE_FIELD_10,
                        i_txd   [DATA_WIDTH - 1                   -: 7*CONTROL_WIDTH  ]}                                                                                                                                                                                                            :
                    {8{CTRL_ERROR}}                                                                                                                                                                                                                                                                 ;                                                
    end
    else begin
        frame = {DATA_SYNC, i_txd}     /* Data frame */                                                                                                                                                                                                                                             ;              
    end

    o_frame = frame                                                                                                                                                                                                                                                                                 ;
endtask

task automatic encode_frame(                
    output logic [TRANSCODER_WIDTH - 1 : 0] o_transcoder /* Output transcoder */                                                                                                                                                                                                                    ,  
    input  logic [FRAME_WIDTH      - 1 : 0] i_frame_reg_0 /* Frame register 0 */                                                                                                                                                                                                                    ,
    input  logic [FRAME_WIDTH      - 1 : 0] i_frame_reg_1 /* Frame register 1 */                                                                                                                                                                                                                    ,
    input  logic [FRAME_WIDTH      - 1 : 0] i_frame_reg_2 /* Frame register 2 */                                                                                                                                                                                                                    ,
    input  logic [FRAME_WIDTH      - 1 : 0] i_frame_reg_3 /* Frame register 3 */                                                                                                                                                                                                                    
);                                                                                                                                                                                                                                                                                                                                        
    // transcoder output                 
    logic [TRANSCODER_WIDTH     - 1 : 0] transcoder                                                                                                                                                                                                                                                 ; 
    // transcoder control heade                 
    logic [TRANSCODER_HDR_WIDTH - 1 : 0] transcoder_control_hdr                                                                                                                                                                                                                                     ;
    // transcoder heade                 
    logic                                transcoder_hdr                                                                                                                                                                                                                                             ;                                    
    // Check if the frame is a control frame 
    if((i_frame_reg_0[FRAME_WIDTH - 1 -: 2] == DATA_SYNC) && (i_frame_reg_1[FRAME_WIDTH - 1 -: 2] == DATA_SYNC) && (i_frame_reg_2[FRAME_WIDTH - 1 -: 2] == DATA_SYNC) && (i_frame_reg_3[FRAME_WIDTH - 1 -: 2] == DATA_SYNC)) begin
        // Data frame with header as 1
        transcoder = {1'b1, i_frame_reg_0[DATA_WIDTH - 1 : 0], i_frame_reg_1[DATA_WIDTH - 1 : 0], i_frame_reg_2[DATA_WIDTH - 1 : 0], i_frame_reg_3[DATA_WIDTH - 1 : 0]}                                                                                                                             ;                                                                                                                                                                                                                   ;
    end
    else begin
        // Control frame with header as 0
        transcoder_hdr = 1'b0                                                                                                                                                                                                                                                                       ;
        transcoder_control_hdr = {(i_frame_reg_0[FRAME_WIDTH - 1 -: 2] == DATA_SYNC), (i_frame_reg_1[FRAME_WIDTH - 1 -: 2] == DATA_SYNC), (i_frame_reg_2[FRAME_WIDTH - 1 -: 2] == DATA_SYNC), (i_frame_reg_3[FRAME_WIDTH - 1 -: 2] == DATA_SYNC)}                                                   ;
        transcoder = (i_frame_reg_0[FRAME_WIDTH-1 -: 2] == CTRL_SYNC) ? {transcoder_hdr, transcoder_control_hdr, i_frame_reg_0[DATA_WIDTH - 1 -: 4], i_frame_reg_0[DATA_WIDTH - 9 : 0 ], i_frame_reg_1[DATA_WIDTH - 1 : 0 ], i_frame_reg_2[DATA_WIDTH - 1 : 0 ], i_frame_reg_3[DATA_WIDTH - 1 : 0]} :
                     (i_frame_reg_1[FRAME_WIDTH-1 -: 2] == CTRL_SYNC) ? {transcoder_hdr, transcoder_control_hdr, i_frame_reg_0[DATA_WIDTH - 1  : 0], i_frame_reg_1[DATA_WIDTH - 1 -: 4], i_frame_reg_1[DATA_WIDTH - 9 : 0 ], i_frame_reg_2[DATA_WIDTH - 1 : 0 ], i_frame_reg_3[DATA_WIDTH - 1 : 0]} :
                     (i_frame_reg_2[FRAME_WIDTH-1 -: 2] == CTRL_SYNC) ? {transcoder_hdr, transcoder_control_hdr, i_frame_reg_0[DATA_WIDTH - 1  : 0], i_frame_reg_1[DATA_WIDTH - 1 : 0 ], i_frame_reg_2[DATA_WIDTH - 1 -: 4], i_frame_reg_2[DATA_WIDTH - 9 : 0 ], i_frame_reg_3[DATA_WIDTH - 1 : 0]} :
                                                                        {transcoder_hdr, transcoder_control_hdr, i_frame_reg_0[DATA_WIDTH - 1  : 0], i_frame_reg_1[DATA_WIDTH - 1 : 0 ], i_frame_reg_2[DATA_WIDTH - 1 : 0 ], i_frame_reg_3[DATA_WIDTH - 1 -: 4], i_frame_reg_3[DATA_WIDTH - 9 : 0]} ;
    end  
    o_transcoder = transcoder                                                                                                                                                                                                                                                                       ;                                                                                                                                                                                                                   ;
endtask


task automatic scrambler(                       
    output logic [TRANSCODER_WIDTH - 1 : 0] o_scrambled_data /* Output data scrambled */                                                                                                                                                                                                            ,
    output logic [TRANSCODER_WIDTH - 1 : 0] o_lfsr_value     /* Output LFSR value */                                                                                                                                                                                                                ,
    input  logic [TRANSCODER_WIDTH - 1 : 0] i_transcoder_reg /* Input data */                                                                                                                                                                                                                       ,
    input  logic [TRANSCODER_WIDTH - 1 : 0] i_lfsr_value     /* Input LFSR value */                                                                                                                                                                                                                 
)                                                                                                                                                                                                                                                                                                   ;
    logic [TRANSCODER_WIDTH - 1 : 0] data_scrambled /* Data scrambled */                                                                                                                                                                                                                            ;
    logic [TRANSCODER_WIDTH - 1 : 0] lfsr /* LFSR value */                                                                                                                                                                                                                                          ;

    begin               
        // Scrambler LFSR               
        for (int i = 0; i < TRANSCODER_WIDTH ; i++) begin                
            data_scrambled[i] = i_transcoder_reg[i] ^ i_lfsr_value[TRANSCODER_WIDTH - 1] /* XOR data with LFSR output */                                                                                                                                                                            ;         
            lfsr              = {i_lfsr_value[TRANSCODER_WIDTH - 2 : 0], i_lfsr_value[TRANSCODER_WIDTH - 1] ^ i_lfsr_value[217] ^ i_lfsr_value[198]} /* Use polynomial 1 + x^39 + x^56 */                                                                                                           ;         
        end             
        // Last bit of LFSR             
        data_scrambled[TRANSCODER_WIDTH - 1] = lfsr[TRANSCODER_WIDTH - 1]                                                                                                                                                                                                                           ;
        // Output scrambled data                
        o_scrambled_data = data_scrambled                                                                                                                                                                                                                                                           ;
        o_lfsr_value     = lfsr                                                                                                                                                                                                                                                                     ;            
    end             

endtask             


// Frame generation process             
always_ff @(posedge clk or negedge i_rst_n)              
    if (!i_rst_n)  begin            
        // Reset all frame registers                
        mii_txd_0                   <= 'b0                                                                                                                                                                                                                                                          ;
        mii_txd_1                   <= 'b0                                                                                                                                                                                                                                                          ;
        mii_txd_2                   <= 'b0                                                                                                                                                                                                                                                          ;
        mii_txd_3                   <= 'b0                                                                                                                                                                                                                                                          ;
        mii_txc_0                   <= 'b0                                                                                                                                                                                                                                                          ;
        mii_txc_1                   <= 'b0                                                                                                                                                                                                                                                          ;
        mii_txc_2                   <= 'b0                                                                                                                                                                                                                                                          ;
        mii_txc_3                   <= 'b0                                                                                                                                                                                                                                                          ;
        frame_reg_0                 <= 'b0                                                                                                                                                                                                                                                          ;                                                                                             
        frame_reg_1                 <= 'b0                                                                                                                                                                                                                                                          ;                                                                                             
        frame_reg_2                 <= 'b0                                                                                                                                                                                                                                                          ;                                                                                             
        frame_reg_3                 <= 'b0                                                                                                                                                                                                                                                          ;
        frame_invert_reg_0          <= 'b0                                                                                                                                                                                                                                                          ;
        frame_invert_reg_1          <= 'b0                                                                                                                                                                                                                                                          ;
        frame_invert_reg_2          <= 'b0                                                                                                                                                                                                                                                          ;
        frame_invert_reg_3          <= 'b0                                                                                                                                                                                                                                                          ;
        transcoder_reg_0            <= 'b0                                                                                                                                                                                                                                                          ;                                                                                             
        transcoder_invert_reg_0     <= 'b0                                                                                                                                                                                                                                                          ;
        counter                     <= 'b0                                                                                                                                                                                                                                                          ;                                                       
    end               
    else begin
        if(!i_tx_test_mode) begin 
            if(i_enable) begin            
                if(i_random_0) begin                
                    // Generate frames for each output              
                    generate_frame(mii_txd_0, mii_txc_0, 043)                                                                                                                                                                                                                                       ;
                    generate_frame(mii_txd_1, mii_txc_1, 086)                                                                                                                                                                                                                                       ;
                    generate_frame(mii_txd_2, mii_txc_2, 127)                                                                                                                                                                                                                                       ;
                    generate_frame(mii_txd_3, mii_txc_3, 065)                                                                                                                                                                                                                                       ;
                end              
                else begin    
                    // Select data or control byte for each output           
                    mii_txd_0 <= (i_data_sel_0[0] == 1) ? FIXED_PATTERN_0_DATA : FIXED_PATTERN_0_CTRL                                                                                                                                                                                               ;                             
                    mii_txc_0 <= (i_data_sel_0[0] == 1) ? TXC_TYPE_DATA        : TXC_TYPE_FIELD_0                                                                                                                                                                                                   ;                            
                    mii_txd_1 <= (i_data_sel_0[1] == 1) ? FIXED_PATTERN_1_DATA : FIXED_PATTERN_1_CTRL                                                                                                                                                                                               ;
                    mii_txc_1 <= (i_data_sel_0[1] == 1) ? TXC_TYPE_DATA        : TXC_TYPE_FIELD_1                                                                                                                                                                                                   ;                             
                    mii_txd_2 <= (i_data_sel_0[2] == 1) ? FIXED_PATTERN_2_DATA : FIXED_PATTERN_2_CTRL                                                                                                                                                                                               ;
                    mii_txc_2 <= (i_data_sel_0[2] == 1) ? TXC_TYPE_DATA        : TXC_TYPE_FIELD_2                                                                                                                                                                                                   ;                             
                    mii_txd_3 <= (i_data_sel_0[3] == 1) ? FIXED_PATTERN_3_DATA : FIXED_PATTERN_3_CTRL                                                                                                                                                                                               ;
                    mii_txc_3 <= (i_data_sel_0[3] == 1) ? TXC_TYPE_DATA        : TXC_TYPE_FIELD_3                                                                                                                                                                                                   ; 
                end             
                counter <= 2'b00                                                                                                                                                                                                                                                                    ;                                                    
            end
            else begin
                case(counter)
                2'b00: begin
                    // Set the input as data
                    mii_txd_0 <= i_txd                                                                                                                                                                                                                                                              ;
                    mii_txc_0 <= i_txc                                                                                                                                                                                                                                                              ;
                end                                                                                                                                                                                                                                                                 
                2'b01: begin                                                                                                                                                                                                                                                                   
                    mii_txd_1 <= i_txd                                                                                                                                                                                                                                                              ;
                    mii_txc_1 <= i_txc                                                                                                                                                                                                                                                              ;
                end                                                                                                                                                                                                                                                                 
                2'b10: begin                                                                                                                                                                                                                                                                   
                    mii_txd_2 <= i_txd                                                                                                                                                                                                                                                              ;
                    mii_txc_2 <= i_txc                                                                                                                                                                                                                                                              ;
                end                                                                                                                                                                                                                                                                 
                2'b11: begin                                                                                                                                                                                                                                                                   
                    mii_txd_3 <= i_txd                                                                                                                                                                                                                                                              ;
                    mii_txc_3 <= i_txc                                                                                                                                                                                                                                                              ;
                end                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                
                endcase
                counter <= counter + 1'b1                                                                                                                                                                                                                                                           ;
            end
            if(i_valid[0]) begin
                if(counter == 0) begin
                    // Convert MII to PCS
                    mii_to_pcs(mii_txd_0, mii_txc_0, frame_reg_0)                                                                                                                                                                                                                                   ;
                    mii_to_pcs(mii_txd_1, mii_txc_1, frame_reg_1)                                                                                                                                                                                                                                   ;
                    mii_to_pcs(mii_txd_2, mii_txc_2, frame_reg_2)                                                                                                                                                                                                                                   ;
                    mii_to_pcs(mii_txd_3, mii_txc_3, frame_reg_3)                                                                                                                                                                                                                                   ;
                    invert_64_frame(frame_invert_reg_0, frame_reg_0)                                                                                                                                                                                                                                ;
                    invert_64_frame(frame_invert_reg_1, frame_reg_1)                                                                                                                                                                                                                                ;
                    invert_64_frame(frame_invert_reg_2, frame_reg_2)                                                                                                                                                                                                                                ;
                    invert_64_frame(frame_invert_reg_3, frame_reg_3)                                                                                                                                                                                                                                ;
                end
                else begin
                    // Keep the frame registers
                    frame_reg_0 <= frame_reg_0                                                                                                                                                                                                                                                      ;
                    frame_reg_1 <= frame_reg_1                                                                                                                                                                                                                                                      ;
                    frame_reg_2 <= frame_reg_2                                                                                                                                                                                                                                                      ;
                    frame_reg_3 <= frame_reg_3                                                                                                                                                                                                                                                      ;
                end
            end
            else begin
                // Keep the frame registers
                frame_reg_0 <= frame_reg_0                                                                                                                                                                                                                                                          ;
                frame_reg_1 <= frame_reg_1                                                                                                                                                                                                                                                          ;
                frame_reg_2 <= frame_reg_2                                                                                                                                                                                                                                                          ;
                frame_reg_3 <= frame_reg_3                                                                                                                                                                                                                                                          ;
            end
            if(i_valid[1]) begin
                if(counter == 0) begin
                    // Encode the frame
                    encode_frame(transcoder_reg_0, frame_reg_0, frame_reg_1, frame_reg_2, frame_reg_3)                                                                                                                                                                                              ;
                    invert_257_frame(transcoder_invert_reg_0, transcoder_reg_0)                                                                                                                                                                                                                     ;
                end
                else begin
                    // Keep the transcoder registers
                    transcoder_reg_0 <= transcoder_reg_0                                                                                                                                                                                                                                            ;
                end
            end
            else begin
                // Keep the transcoder registers
                transcoder_reg_0 <= transcoder_reg_0                                                                                                                                                                                                                                                ;
            end
        end
        else begin
            // Test mode
            mii_txd_0        <= {DATA_WIDTH / CONTROL_WIDTH{CTRL_IDLE}}                                                                                                                                                                                                                             ;
            mii_txd_1        <= {DATA_WIDTH / CONTROL_WIDTH{CTRL_IDLE}}                                                                                                                                                                                                                             ;
            mii_txd_2        <= {DATA_WIDTH / CONTROL_WIDTH{CTRL_IDLE}}                                                                                                                                                                                                                             ;
            mii_txd_3        <= {DATA_WIDTH / CONTROL_WIDTH{CTRL_IDLE}}                                                                                                                                                                                                                             ;
            mii_txc_0        <= TXC_TYPE_FIELD_0                                                                                                                                                                                                                                                    ;
            mii_txc_1        <= TXC_TYPE_FIELD_0                                                                                                                                                                                                                                                    ;
            mii_txc_2        <= TXC_TYPE_FIELD_0                                                                                                                                                                                                                                                    ;
            mii_txc_3        <= TXC_TYPE_FIELD_0                                                                                                                                                                                                                                                    ;
            frame_reg_0      <= {FRAME_WIDTH / CONTROL_WIDTH{CTRL_IDLE}}                                                                                                                                                                                                                            ;
            frame_reg_1      <= {FRAME_WIDTH / CONTROL_WIDTH{CTRL_IDLE}}                                                                                                                                                                                                                            ;
            frame_reg_2      <= {FRAME_WIDTH / CONTROL_WIDTH{CTRL_IDLE}}                                                                                                                                                                                                                            ;
            frame_reg_3      <= {FRAME_WIDTH / CONTROL_WIDTH{CTRL_IDLE}}                                                                                                                                                                                                                            ;
            transcoder_reg_0 <= {TRANSCODER_WIDTH / CONTROL_WIDTH{CTRL_IDLE}}                                                                                                                                                                                                                       ;
        end             
    end 
           

// Output signals
assign o_frame_0          = frame_invert_reg_0                                                                                                                                                                                                                                                      ;   
assign o_frame_1          = frame_invert_reg_1                                                                                                                                                                                                                                                      ;   
assign o_frame_2          = frame_invert_reg_2                                                                                                                                                                                                                                                      ;   
assign o_frame_3          = frame_invert_reg_3                                                                                                                                                                                                                                                      ;   
assign o_tx_coded_f0      = transcoder_invert_reg_0                                                                                                                                                                                                                                                 ;

endmodule