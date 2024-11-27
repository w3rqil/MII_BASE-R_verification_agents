module mac_frame_generator #(
    parameter PAYLOAD_MAX_SIZE = 1500                                                                                   , // Maximum payload size in bytes
    parameter [7:0] PAYLOAD_CHAR_PATTERN = 8'h55                                                                        ,
    parameter PAYLOAD_LENGTH = 8                    
)(                  
    input               logic   clk                                                                                     , // Clock signal
    input               logic   i_rst_n                                                                                 , // Active-low reset
    input               logic   i_start                                                                                 , // Start signal to begin frame generation
    input       [47:0]          i_dest_address                                                                          , // Destination MAC address
    input       [47:0]          i_src_address                                                                           , // Source MAC address
    input       [15:0]          i_eth_type                                                                              , // EtherType or Length field
    input       [15:0]          i_payload_length                                                                        , // Payload length in bytes
    input       [7:0]           i_payload[PAYLOAD_LENGTH-1:0]                                                           , // Payload data (preloaded)
    input       [7:0]           i_interrupt                                                                             , // Set of interruptions to acomplish different behavors
    output      logic           o_valid                                                                                 , // Output valid signal
    output      logic [63:0]    o_frame_out                                                                             , // 64-bit output data
    output      logic           o_done                                                                                    // Indicates frame generation is complete
);

    localparam [7:0]
                    FIXED_PAYLOAD = 8'd1;


    // State machine states
    localparam [2:0]
        IDLE            = 3'd0                                                                                          ,
        SEND_PREAMBLE   = 3'd1                                                                                          ,
        SEND_HEADER     = 3'd2                                                                                          ,
        SEND_PAYLOAD    = 3'd3                                                                                          ,
        SEND_PADDING    = 3'd4                                                                                          ,
        DONE            = 3'd5                                                                                          ;

    reg [2:0] state, next_state                                                                                         ;
    reg [(PAYLOAD_LENGTH)*8 - 1:0] payload_reg;
    // Internal registers                   
    reg [15:0] byte_counter                                                                                             ;   // Tracks bytes sent
    logic [111:0] header_shift_reg                                                                                      ;   // Shift register for sending preamble + header (192 bits)
    logic [63:0] payload_shift_reg                                                                                      ;   // Shift register for 64-bit payload output
    reg [15:0] payload_index                                                                                            ;   // Index for reading payload bytes
    reg [15:0] padding_counter                                                                                          ;   // Counter for adding padding if payload < 46 bytes
    logic [(PAYLOAD_LENGTH)*8 + 112-1:0] gen_shift_reg;                 
    // Constants for Ethernet frame                                                         
    localparam [63:0] PREAMBLE_SFD = 64'h55555555555555D5                                                               ; // Preamble (7 bytes) + SFD (1 byte)
    localparam MIN_PAYLOAD_SIZE = 46                                                                                    ; // Minimum Ethernet payload size
    localparam FRAME_SIZE = 64                                                                                          ; // Minimum Ethernet frame size (in bytes)

    // // Sequential logic: State transitions
    // always_ff @(posedge clk or negedge i_rst_n) begin
    //     if (!i_rst_n) begin
    //         state <= IDLE                                                                           ;
    //     end else begin
    //         state <= next_state                                                                     ;
    //     end
    // end


    reg valid, next_valid, next_done;
    reg [63:0] frame_out, next_frame_out;
    reg [15:0] next_payload_index, next_byte_counter, next_padding_counter;   
    
    always_comb begin

        next_state              = state                                                                                 ;
        next_valid              = 1'b0                                                                                  ;
        next_frame_out          = 64'b0                                                                                 ;
        next_done               = 1'b0                                                                                  ;
        next_byte_counter       = byte_counter                                                                          ;
        next_payload_index      = payload_index                                                                         ;    
        next_padding_counter    = padding_counter                                                                       ;
       

        case (state)                                                    
                IDLE: begin                
                                                     
                    next_valid          = 1'b0                                                                          ;
                    next_frame_out      = 64'b0                                                                         ;
                    next_done              = 1'b0                                                                       ; 
                    next_byte_counter        = 16'd0                                                                    ;
                    next_payload_index       = 16'd0                                                                    ;
                    next_padding_counter     = 16'd0                                                                    ;

                    // Prepare header: Destination + Source + EtherType 
                    header_shift_reg = {i_dest_address, i_src_address, i_eth_type}                                      ;
                    //genetal_shift_reg <= {header_shift_reg, }
                    for(i=0; i<PAYLOAD_LENGTH; i= i+1) begin
                        payload_reg[(i*8) +:8]  = i_payload[i];
                        if(i_interrupt == FIXED_PAYLOAD) begin //interrupt to indicate that the payload  should be PAYLOAD_CHAR_PETTERN
                            payload_reg[(i*8) +:8]  = PAYLOAD_CHAR_PATTERN;
                        end
                    end
                    gen_shift_reg = {header_shift_reg, payload_reg};

                    if (i_start) begin
                        next_state = SEND_PREAMBLE                                                                      ;
                    end else begin                                                          
                        next_state = IDLE                                                                               ;
                    end     
                end     
                SEND_PREAMBLE: begin        
                    next_valid     = 1'b1                                                                               ;
                    next_frame_out = PREAMBLE_SFD                                                                       ; // Send Preamble + SFD
                    next_state = SEND_HEADER                                                                            ;
                end     
                SEND_HEADER: begin      
                    next_valid = 1'b1                                                                                   ;
                    // if(next_byte_counter > 8 ) begin
                    //     next_frame_out <= gen_shift_reg[(PAYLOAD_LENGTH-1)*8 + 48]                     ;
                    //     next_byte_counter <= next_byte_counter + 8                                            ;
                    // end

                    //next_frame_out <= {header_shift_reg[111:48]}                                       ; // Send top 64 bits of the header
                    //header_shift_reg <= {header_shift_reg[47:0], 64'b0}                             ; // Shift left
                    next_frame_out     = gen_shift_reg [(PAYLOAD_LENGTH)*8 + 112 -1 : (PAYLOAD_LENGTH)*8 + 48]          ;
                    gen_shift_reg   = {gen_shift_reg [(PAYLOAD_LENGTH)*8 + 47:0], 64'b0}                              ;
                    next_byte_counter    = byte_counter + 8                                                             ;

                    if (byte_counter >= 14) begin   
                        next_state = SEND_PAYLOAD                                                                       ;
                    end else begin                                                      
                        next_state = SEND_HEADER                                                                        ;
                    end 

                end 
                SEND_PAYLOAD: begin 
                    next_valid <= 1'b1                                                                                  ;
                    //if(i_interrupt == FIXED_PAYLOAD) begin
                    //    if(i_payload_length < 46)   next_frame_out
                    //end

                    //next_frame_out <= payload_shift_reg                                                ;      // Output 64 bits
                    next_frame_out         = gen_shift_reg [(PAYLOAD_LENGTH)*8 + 112 - 1 : (PAYLOAD_LENGTH)*8 + 48]      ;
                    gen_shift_reg       = {gen_shift_reg [(PAYLOAD_LENGTH)*8 + 47:0], 64'b0}                          ;

                    //payload_shift_reg   = {payload_shift_reg[55:0], i_payload[payload_index]}                           ;
                    next_payload_index       = payload_index + 1                                                        ;
                    next_byte_counter        = byte_counter + 8                                                         ;

                    if (payload_index >= i_payload_length) begin
                        if (payload_index < MIN_PAYLOAD_SIZE) begin
                            next_state = SEND_PADDING; // Add padding if payload is too short
                        end else begin
                            next_state = DONE                                                                           ;
                        end                                                     
                    end else begin                                                      
                        next_state = SEND_PAYLOAD                                                                       ;
                    end

                end
                SEND_PADDING: begin
                    next_valid             = 1'b1                                                                       ;
                    next_frame_out         = 64'b0                                                                      ; // Send zero padding
                    next_padding_counter     = padding_counter + 8                                                      ;
                    if (padding_counter >= (MIN_PAYLOAD_SIZE - i_payload_length)) begin
                        next_state = DONE                                                                               ;
                    end else begin                                                      
                        next_state = SEND_PADDING                                                                       ;
                    end  
                end
                DONE: begin
                    next_valid = 1'b0                                                                                   ;
                    next_done  = 1'b1                                                                                   ;
                    next_state = IDLE                                                                                   ;
                end
                default: begin
                    next_state = IDLE;
                    next_valid              = 1'b0                                                                      ;
                    next_frame_out          = 64'b0                                                                     ;
                    next_done               = 1'b0                                                                      ; 
                    next_byte_counter       = 16'd0                                                                     ;
                    next_payload_index      = 16'd0                                                                     ;
                    next_padding_counter    = 16'd0                                                                     ;
                end
            endcase
        
    end

    integer i;
    
    // Sequential logic: Frame generation
    always_ff @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state               = IDLE                                                                                  ;
            o_valid             = 1'b0                                                                                  ;
            o_frame_out         = 64'b0                                                                                 ;
            o_done              = 1'b0                                                                                  ;
            byte_counter        = 16'd0                                                                                 ;
            payload_index       = 16'd0                                                                                 ;
            padding_counter     = 16'd0                                                                                 ;
            header_shift_reg    = 112'b0                                                                                ;
            payload_shift_reg   = 64'b0                                                                                 ;
        end else begin                                                  
            state           <= next_state                                                                               ;
            o_valid         <= next_valid                                                                               ;
            o_frame_out     <= next_frame_out                                                                           ;
            o_done          <= next_done                                                                                ; 
            byte_counter    <= next_byte_counter                                                                        ;
            payload_index   <= next_payload_index                                                                       ;
            padding_counter <= next_padding_counter                                                                     ;

            
        end
    end

endmodule
