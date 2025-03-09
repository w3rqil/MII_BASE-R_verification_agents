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
    parameter [7:0] PAYLOAD_CHAR_PATTERN = 8'h55                                                                              //! fixed char patter
)(                      
    input       logic                                               clk                                                     , //! Clock signal
    input       logic                                               i_rst_n                                                 , //! Active-low reset
    input       logic                                               i_prbs_rst_n,
    input       logic                                               i_start                                                 , //! Start signal to begin frame generation
    input       logic [47:0]                                        i_dest_address                                          , //! Destination MAC address
    input       logic [47:0]                                        i_src_address                                           , //! Source MAC address
    input       logic [15:0]                                        i_payload_length                                        , //! -----------------------------------------------------------------------
    input       logic [7:0]                                         i_payload        [PAYLOAD_MAX_SIZE-1:0]                 , //! Payload data (preloaded)
    input       logic [7:0]                                         i_prbs_seed,
    input       logic [7:0]                                         i_mode                                             , //! Set of modes to acomplish different behavors
    output      wire  [(PAYLOAD_MAX_SIZE)*8 + 112+ 32 + 64 -1:0]    o_register                                              , //! register output with the full data
    output      logic                                               o_done                                                    //! Indicates frame generation is complete
);

    localparam [7:0]
        FIXED_PAYLOAD   = 8'd1,
        NO_PADDING      = 8'd2,
        PRBS8           = 8'd3;

    localparam [31:0] POLYNOMIAL = 32'h04C11DB7; //polynomial for CRC32 calc    

    reg [PAYLOAD_MAX_SIZE*8 - 1:0]        payload_reg                                                                       ;

    // Internal registers
    logic [111:0]                         header_reg                                                                  ;   // Shift register for sending preamble + header (192 bits)
    logic [(PAYLOAD_MAX_SIZE + 18)*8 -1:0] frame_reg;                 //! register for PAYLOAD + ADDRESS 

    // Constants for Ethernet frame
    localparam [63:0] PREAMBLE_SFD     = 64'hD555555555555555                                                               ; // Preamble (7 bytes) + SFD (1 byte)
    localparam        MIN_PAYLOAD_SIZE = 46                                                                                 ; // Minimum Ethernet payload size
    localparam        FRAME_SIZE       = 64                                                                                 ; // Minimum Ethernet frame size (in bytes)

    integer i,j;

    reg        next_done                                                                                 ;
    reg [31:0] temp_data                                                                                    ;

    reg [7:0] prbs_char;
    reg [7:0] next_prbs_char;

    reg [31:0] crc                                                                                                ;
    reg [31:0] data_xor                                                                                                     ;

    logic [15:0] payload_size;
    assign payload_size = (i_payload_length < MIN_PAYLOAD_SIZE && i_mode != NO_PADDING) ? MIN_PAYLOAD_SIZE : i_payload_length;

    always_comb begin
        next_prbs_char = prbs_char;

        if(i_start) begin
            next_done = 1'b0                                                                                                ; //lower done flag
            // Prepare header: Destination + Source + EtherType
            header_reg = {i_payload_length, i_src_address, i_dest_address}                                                  ;
    
            //prepare payload
            if(!(i_mode == NO_PADDING)) begin
                for(i=0; i<PAYLOAD_MAX_SIZE; i= i+1) begin
                        // $display("PADDING");
                        
                        payload_reg[(i*8) +:8]  = (i<i_payload_length) ? i_payload[i] : 8'h00                                        ;
                        // $display("I_PAYLOAD: %h; BYTE %h; I VALUE: %d", i_payload[i], payload_reg[(i*8) +:8], i);
                        if(i_mode == FIXED_PAYLOAD) begin //Mode to indicate that the payload  should be PAYLOAD_CHAR_PETTERN
                            payload_reg[(i*8) +:8]  = (i<i_payload_length) ? PAYLOAD_CHAR_PATTERN : 8'h00                                        ;
                        end
                        else if(i_mode == PRBS8) begin
                            if(i < i_payload_length) begin
                                // $display("pos: %d prbs char: %h", i, next_prbs_char);
                                next_prbs_char = prbs8_gen(next_prbs_char);

                                if(next_prbs_char == 8'hFD) begin
                                    next_prbs_char = prbs8_gen(next_prbs_char);
                                end

                                payload_reg[(i*8) +:8]  = next_prbs_char;
                                // $display("payload: %h", payload_reg[(i*8) +:8]);
                            end
                            else begin
                                payload_reg[(i*8) +:8]  = 8'h00;
                            end
                        end
                end
            end else begin // no padding mode
                for (i=0; i<i_payload_length; i=i+1) begin
                    // $display("NO_PADDING");

                    payload_reg[(i*8) +:8]  = i_payload[i]                                                                     ;
    
                        if(i_mode == FIXED_PAYLOAD) begin //Mode to indicate that the payload  should be PAYLOAD_CHAR_PETTERN
                            payload_reg[(i*8) +:8]  = PAYLOAD_CHAR_PATTERN                                                      ;
                        end
                end
            end

            
            frame_reg = {payload_reg, header_reg}                                                                 ; 
            // $display("header_reg: %h", header_reg);
            // $display("PAYLOAD_REG: %h", payload_reg);
            // $display("frame_reg SIN CRC: %h", frame_reg);
            
            //! CRC32 calculation
            for(i=0; i < ((payload_size + 14) * 8); i= i+8) begin
                    
                    temp_data = frame_reg [i +: 8]                                                         ;
                
                    // crc calc 
                    if(i==0)begin   
                        data_xor = 32'hFFFFFFFF ^ {temp_data, 24'b0}                                                   ; //initial xor // {crc,    32'b0} {32'b0, crc}

                    end else begin                                                  
                        data_xor = crc ^ {temp_data, 24'b0}                                                    ; //initial xor // {crc,    32'b0} {32'b0, crc}
                    end 

                    for (j = 0; j < 32; j = j + 1) begin    
                        if (data_xor[31]) begin 
                            data_xor = (data_xor << 1) ^ POLYNOMIAL                                                         ;
                        end else begin                                                      
                            data_xor = (data_xor << 1)                                                                      ;
                        end
                    end
                    
                    crc = ~data_xor[31:0]                                                                              ;
                    // $display("bit %d/%d: FRAME GEN: %h   CRC GEN: %h", i, (payload_size*8 + 112) - 8, temp_data, crc);
    
            end

            frame_reg[(payload_size + 14)*8 +: 4*8] = crc;
            // $display("frame_reg CON CRC: %h", frame_reg);

        end else begin
            next_done = 1'b1;
        end
    end

    
 
    //! Sequential logic: Frame generation
    always_ff @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_done              <= 1'b0                                                                                     ;
            header_reg    <= 112'b0                                                                                   ;

        end else begin
            o_done          <= next_done                                                                                    ;


            $display("MAC REGISTER GENERATOR: %h", o_register);
            // $display("CRC: %h", crc);
        end

        if(!i_prbs_rst_n) begin
            prbs_char <= i_prbs_seed;
        end
        else begin
            prbs_char <= next_prbs_char;
        end
    end

    assign o_register = {frame_reg, PREAMBLE_SFD};

    function automatic reg [7:0] prbs8_gen
    (
        input [7:0] i_seed
    );
        reg [7:0] val                                               ;
        reg feedback;

        feedback = i_seed[7] ^ (i_seed[6:0]==7'b0000000);
    
        // val[0]   = i_seed[1] ^ i_seed[2] ^ i_seed[3] ^ i_seed[7]    ;
        // val[7:1] = i_seed[6:0]                                      ;
        val[0] = feedback;
        val[1] = i_seed[0];
        val[2] = i_seed[1] ^ feedback;
        val[3] = i_seed[2] ^ feedback;
        val[4] = i_seed[3] ^ feedback;
        val[5] = i_seed[4];
        val[6] = i_seed[5];
        val[7] = i_seed[6];
        return val;
    endfunction

endmodule
