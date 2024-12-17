module mac_frame_generator #(
    parameter PAYLOAD_MAX_SIZE = 1500                                                                                   , // Maximum payload size in bytes
    parameter [7:0] PAYLOAD_CHAR_PATTERN = 8'h55                                                                         ,
    parameter PAYLOAD_LENGTH = 8                    //len type - payload length in bytes
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
    output      reg           o_valid                                                                                 , // Output valid signal
    output      reg [63:0]    o_frame_out                                                                             , // 64-bit output data
    output      wire [(PAYLOAD_MAX_SIZE)*8 + 112+ 32 + 64 -1:0]  o_register,
    output      logic           o_done                                                                                    // Indicates frame generation is complete
);

    localparam [7:0]
                    FIXED_PAYLOAD = 8'd1;

    localparam PAYLOAD_SIZE = (PAYLOAD_LENGTH < 46)? 46 : PAYLOAD_LENGTH;
    // State machine states
    localparam [2:0]
        IDLE            = 3'd0                                                                                          ,
        SEND_PREAMBLE   = 3'd1                                                                                          ,
        SEND_HEADER     = 3'd2                                                                                          ,
        SEND_PAYLOAD    = 3'd3                                                                                          ,
        SEND_PADDING    = 3'd4                                                                                          ,
        DONE            = 3'd5                                                                                          ;

    localparam [31:0] POLYNOMIAL = 32'h04C11DB7; //polynomial for CRC32 calc

    reg [2:0] state, next_state                                                                                         ;
    reg [PAYLOAD_SIZE*8 - 1:0] payload_reg;
    // Internal registers                   
    reg [15:0] byte_counter                                                                                             ;   // Tracks bytes sent
    logic [111:0] header_shift_reg                                                                                      ;   // Shift register for sending preamble + header (192 bits)
    logic [63:0] payload_shift_reg                                                                                      ;   // Shift register for 64-bit payload output
    reg [15:0] payload_index                                                                                            ;   // Index for reading payload bytes
    reg [15:0] padding_counter                                                                                          ;   // Counter for adding padding if payload < 46 bytes
    logic [(PAYLOAD_LENGTH)*8 + 112 -1:0] gen_shift_reg;                 //! register for PAYLOAD + ADDRESS
    // Constants for Ethernet frame                                                         
    // localparam [63:0] PREAMBLE_SFD = 64'h55555555555555D5                                                               ; // Preamble (7 bytes) + SFD (1 byte)
    localparam [63:0] PREAMBLE_SFD = 64'hD555555555555555                                                               ; // Preamble (7 bytes) + SFD (1 byte)
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
    integer min_size_flag;
    integer size;
    integer i,j;

    //min_size_flag = (i_eth_type < 46) ? 1 : 0;

    reg valid, next_valid, next_done;
    reg [63:0] frame_out, next_frame_out;
    reg [15:0] next_payload_index, next_byte_counter, next_padding_counter;   

    reg [31:0] crc, next_crc;
    reg [63:0] data_xor;

    always_comb begin: size_block

        if(i_eth_type < 46) size = 46;
        else                size = i_eth_type;
    end

    always_comb begin
        if(i_start) begin
            next_done = 1'b0; //lower done flag
            // Prepare header: Destination + Source + EtherType 
            // header_shift_reg = {i_dest_address, i_src_address, i_eth_type}                                      ;
            header_shift_reg = {i_eth_type, i_src_address, i_dest_address}                                      ;
            //general_shift_reg <= {header_shift_reg, }
    
            //prepare payload
            for(i=0; i<PAYLOAD_LENGTH*8; i= i+1) begin
                    payload_reg[(i*8) +:8]  = (i<=i_eth_type) ? i_payload[i] : 8'h00;
                    if(i_interrupt == FIXED_PAYLOAD) begin //interrupt to indicate that the payload  should be PAYLOAD_CHAR_PETTERN
                        payload_reg[(i*8) +:8]  = PAYLOAD_CHAR_PATTERN;
                    end
            end
            // if(i_eth_type < 46 ) begin // padding if needed
            //     for(i= i_eth_type; i <46; i= i+1) begin
            //         payload_reg[(i*8) +:8]  = 8'h00;
            //         if(i_interrupt == FIXED_PAYLOAD) begin //interrupt to indicate that the payload  should be PAYLOAD_CHAR_PETTERN
            //             payload_reg[(i*8) +:8]  = PAYLOAD_CHAR_PATTERN;
            //         end
            //     end
            // end
    
    
    
            gen_shift_reg = {payload_reg, header_shift_reg}; 
            
            //next_crc = 32'hFFFFFFFF;
            //! CRC calculation
            for(i=0; i<(PAYLOAD_LENGTH*8 + 112 ); i= i+64) begin
                //if((i<= i_eth_type*8)) begin 
                    
                    next_frame_out = gen_shift_reg [(i) + 63 -: 64];
        
                        // crc calc
                    if(i==0)begin
                        data_xor = {32'hFFFFFFFF ,32'b0} ^ next_frame_out; //initial xor // {crc,    32'b0} {32'b0, crc}
                        
                    end else begin 
                        data_xor = {{ next_crc} ,32'b0} ^ next_frame_out; //initial xor // {crc,    32'b0} {32'b0, crc}
                    end
                    for (j = 0; j < 64; j = j + 1) begin
                        if (data_xor[63]) begin
                            data_xor = (data_xor << 1) ^ POLYNOMIAL;
                        end else begin
                            data_xor = (data_xor << 1);
                        end
                    end
                    $display("DATA XOR: %h", data_xor);
                    $display("NEXT_FRAME_OUT: %h", next_frame_out);
                    next_crc = ~data_xor[31:0];
                    $display("CRC RT: %h", next_crc);

                //end
    
            end

        end else begin
            next_done = 1'b1;
        end
        

        
    end

    assign o_register = {next_crc, gen_shift_reg, PREAMBLE_SFD};
 
    // Sequential logic: Frame generation
    always_ff @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            //state               <= IDLE                                                                                  ;
            o_valid             <= 1'b0                                                                                  ;
            crc                 <= 32'hFFFF                                                                          ;
            o_frame_out         <= 64'b0                                                                                 ;
            o_done              <= 1'b0                                                                                  ;
            byte_counter        <= 16'd0                                                                                 ;
            payload_index       <= 16'd0                                                                                 ;
            padding_counter     <= 16'd0                                                                                 ;
            header_shift_reg    <= 112'b0                                                                                ;
            payload_shift_reg   <= 64'b0                                                                                 ;
            //o_register <= 0;
        end else begin                                                  

            //state           <= next_state                                                                               ;
            //o_valid         <= next_valid                                                                               ;
            o_frame_out     <= 64'hFFFFFFFFFFFFFFFF                                                                           ;
            o_done          <= next_done                                                                                ; 
            //byte_counter    <= next_byte_counter                                                                        ;

            crc             <= next_crc                                                                                 ;
            payload_index   <= next_payload_index                                                                       ;
            padding_counter <= next_padding_counter  ;    
            
            //o_register <= {next_crc, gen_shift_reg, PREAMBLE_SFD};


            

            
        end
    end

endmodule
