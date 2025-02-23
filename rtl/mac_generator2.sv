module mac_frame_generator #(
    /* Packet structure:
        - Preamble: 7 bytes
        - SFD: 1 byte
        - Destination adress: 6 bytes
        - Source adress: 6 bytes
        - Length/Type: 2 bytes
        - Client Data (Payload): 46-1500 bytes
        - Frame Check Sequence (CRC): 4 bytes 
    */
    parameter       PAYLOAD_MAX_SIZE     = 1500                                                                             , //! Maximum payload size in bytes (should be 1514)
    parameter [7:0] PAYLOAD_CHAR_PATTERN = 8'h55                                                                            , //! fixed char patter
    parameter       PAYLOAD_LENGTH       = 8                                                                                  //! len type - payload length in bytes    
)(                      
    input       logic                                               clk                                                     , //! Clock signal
    input       logic                                               i_rst_n                                                 , //! Active-low reset
    input       logic                                               i_start                                                 , //! Start signal to begin frame generation
    input       logic [47:0]                                        i_dest_address                                          , //! Destination MAC address
    input       logic [47:0]                                        i_src_address                                           , //! Source MAC address
    input       logic [15:0]                                        i_eth_type                                              , //! EtherType or Length field
    input       logic [15:0]                                        i_payload_length                                        , //! -----------------------------------------------------------------------
    input       logic [7:0]                                         i_payload        [PAYLOAD_LENGTH-1:0]                   , //! Payload data (preloaded)
    input       logic [7:0]                                         i_interrupt                                             , //! Set of interruptions to acomplish different behavors
    output      reg                                                 o_valid                                                 , //! Output valid signal
    output      reg   [63:0]                                        o_frame_out                                             , //! 64-bit output data
    output      wire  [(PAYLOAD_MAX_SIZE)*8 + 112+ 32 + 64 -1:0]    o_register                                              , //! register output with the full data
    output      logic                                               o_done                                                    //! Indicates frame generation is complete
);

    localparam [7:0]
                    FIXED_PAYLOAD   = 8'd1,
                    NO_PADDING      = 8'd2;

    //localparam PAYLOAD_SIZE = (PAYLOAD_LENGTH < 46)? 46 : PAYLOAD_LENGTH                                                    ;
    // State machine states
    localparam [2:0]
        IDLE            = 3'd0                                                                                              ,
        SEND_PREAMBLE   = 3'd1                                                                                              ,
        SEND_HEADER     = 3'd2                                                                                              ,
        SEND_PAYLOAD    = 3'd3                                                                                              ,
        SEND_PADDING    = 3'd4                                                                                              ,
        DONE            = 3'd5                                                                                              ;

    localparam [31:0] POLYNOMIAL = 32'h04C11DB7; //polynomial for CRC32 calc    

    reg [2:0]                             state, next_state                                                                 ;
    reg [PAYLOAD_MAX_SIZE*8 - 1:0]        payload_reg                                                                       ;

    // Internal registers                       
    reg   [15:0]                          byte_counter                                                                      ;   // Tracks bytes sent
    logic [111:0]                         header_shift_reg                                                                  ;   // Shift register for sending preamble + header (192 bits)
    reg   [15:0]                          payload_index                                                                     ;   // Index for reading payload bytes
    reg   [15:0]                          padding_counter                                                                   ;   // Counter for adding padding if payload < 46 bytes
    logic [PAYLOAD_MAX_SIZE*8 + 112 -1:0] gen_shift_reg;                 //! register for PAYLOAD + ADDRESS 

    // Constants for Ethernet frame
    localparam [63:0] PREAMBLE_SFD     = 64'hD555555555555555                                                               ; // Preamble (7 bytes) + SFD (1 byte)
    localparam        MIN_PAYLOAD_SIZE = 46                                                                                 ; // Minimum Ethernet payload size
    localparam        FRAME_SIZE       = 64                                                                                 ; // Minimum Ethernet frame size (in bytes)


    integer min_size_flag;
    integer size;
    integer i,j;

    //min_size_flag = (i_eth_type < 46) ? 1 : 0;

    reg        valid, next_valid, next_done                                                                                 ;
    reg [31:0] frame_out, next_frame_out                                                                                    ;
    reg [15:0] next_payload_index, next_byte_counter, next_padding_counter                                                  ;   

    reg [31:0] crc, next_crc                                                                                                ;
    reg [31:0] data_xor                                                                                                     ;

    logic [15:0] payload_size;
    assign payload_size = (i_payload_length < MIN_PAYLOAD_SIZE) ? MIN_PAYLOAD_SIZE : i_payload_length;


    always_comb begin: size_block   

        if(i_eth_type < 46) size = 46                                                                                       ;
        else                size = i_eth_type                                                                               ;
    end
    // integer i4test =0;
    // always_comb begin
    //     i4test = (i4test == 10) ? 0: i4test + 1;
    // end
    always_comb begin
        if(i_start) begin
            next_done = 1'b0                                                                                                ; //lower done flag
            // Prepare header: Destination + Source + EtherType
            header_shift_reg = {i_payload_length, i_src_address, i_dest_address}                                                  ;
    
            //prepare payload
            if(!(i_interrupt == NO_PADDING)) begin
                for(i=0; i<PAYLOAD_MAX_SIZE; i= i+1) begin
                        $display("PADDING");
                        
                        payload_reg[(i*8) +:8]  = (i<i_payload_length) ? i_payload[i] : 8'h00                                        ;
                        $display("BYTE %h; I VALUE: %d", (i<i_payload_length) ? i_payload[i] : 8'h00, i);
                        if(i_interrupt == FIXED_PAYLOAD) begin //interrupt to indicate that the payload  should be PAYLOAD_CHAR_PETTERN
                            payload_reg[(i*8) +:8]  = PAYLOAD_CHAR_PATTERN                                                      ;
                        end
                end
            end else begin // no padding interruption
                $display("NO_PADDING");
                for (i=0; i<i_payload_length; i=i+1) begin
                    payload_reg[(i*8) +:8]  = i_payload[i]                                                                     ;
    
                        if(i_interrupt == FIXED_PAYLOAD) begin //interrupt to indicate that the payload  should be PAYLOAD_CHAR_PETTERN
                            payload_reg[(i*8) +:8]  = PAYLOAD_CHAR_PATTERN                                                      ;
                        end
                end
            end

            
            gen_shift_reg = {payload_reg, header_shift_reg}                                                                 ; 
            
            //! CRC32 calculation
            for(i=0; i<(i_payload_length*8 + 112 ); i= i+32) begin
                    
                    next_frame_out = gen_shift_reg [(i) + 31 -: 32]                                                         ;
                
                    // crc calc 
                    if(i==0)begin   
                        data_xor = 32'hFFFFFFFF ^ next_frame_out                                                   ; //initial xor // {crc,    32'b0} {32'b0, crc}

                    end else begin                                                  
                        data_xor = next_crc ^ next_frame_out                                                    ; //initial xor // {crc,    32'b0} {32'b0, crc}
                    end 

                    for (j = 0; j < 32; j = j + 1) begin    
                        if (data_xor[31]) begin 
                            data_xor = (data_xor << 1) ^ POLYNOMIAL                                                         ;
                        end else begin                                                      
                            data_xor = (data_xor << 1)                                                                      ;
                        end
                    end
                    
                    next_crc = ~data_xor[31:0]                                                                              ;
    
            end

        end else begin
            next_done = 1'b1;
        end
        

        for (i=0; i<= PAYLOAD_MAX_SIZE; i++) begin
            if(i <= (i_payload_length + 112/8)) begin
            gen_shift_reg[i*8 +:8] = gen_shift_reg[i*8 +:8];
            end else begin
                gen_shift_reg[i*8 +:32] = next_crc;
                break;
            end
        end
    end

    
 
    //! Sequential logic: Frame generation
    always_ff @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_valid             <= 1'b0                                                                                     ;
            crc                 <= 32'hFFFF                                                                                 ;
            o_frame_out         <= 64'b0                                                                                    ;
            o_done              <= 1'b0                                                                                     ;
            byte_counter        <= 16'd0                                                                                    ;
            payload_index       <= 16'd0                                                                                    ;
            padding_counter     <= 16'd0                                                                                    ;
            header_shift_reg    <= 112'b0                                                                                   ;

        end else begin
            o_frame_out     <= 64'hFFFFFFFFFFFFFFFF                                                                         ;
            o_done          <= next_done                                                                                    ; 

            crc             <= next_crc                                                                                     ;
            payload_index   <= next_payload_index                                                                           ;
            padding_counter <= next_padding_counter                                                                         ;

        end
    end

    assign o_register = {gen_shift_reg, PREAMBLE_SFD};

endmodule
