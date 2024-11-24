module mac_frame_generator #(
    parameter PAYLOAD_MAX_SIZE = 1500 // Maximum payload size in bytes
)(
    input               logic   clk                 ,   // Clock signal
    input               logic   i_rst_n             ,   // Active-low reset
    input               logic   i_start             ,   // Start signal to begin frame generation
    input       [47:0]          i_dest_address      ,   // Destination MAC address
    input       [47:0]          i_src_address       ,   // Source MAC address
    input       [15:0]          i_eth_type          ,   // EtherType or Length field
    input       [7:0]           i_payload_data      ,   // Input payload byte (provided externally)
    input                       i_payload_valid     ,   // Valid signal for payload data
    output      logic           o_valid             ,   // Output o_valid signal
    output      logic [63:0]    o_frame_out         ,   // 64-bit output data
    output      logic           o_done                  // Indicates frame generation is complete
);
    integer PAYLOAD_SIZE = (PAYLOAD_MAX_SIZE < 1512) ? 1512 : PAYLOAD_MAX_SIZE;
    // State machine states
    localparam [2:0]
        IDLE            = 3'd0,
        SEND_PREAMBLE   = 3'd1,
        SEND_HEADER     = 3'd2,
        SEND_PAYLOAD    = 3'd3,
        DONE            = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers
    logic [15:0] byte_counter                           ;   // Tracks bytes sent
    logic [PAYLOAD_MAX_SIZE + 46 :0] header_shift_reg   ;   // Shift register for sending preamble + header
    logic [63:0]  payload_shift_reg                     ;   // Shift register for 64-bit payload output
    logic [15:0]  payload_size                          ;   // Number of payload bytes to send

    // Preamble and SFD
    localparam [63:0] PREAMBLE_SFD = 64'h55555555555555D5; // Preamble (7 bytes) + SFD (1 byte)

    // Sequential logic: State transitions
    always_ff @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= IDLE                               ;
        end else begin
            state <= next_state                         ;
        end
    end

    // State machine next state logic
    always_comb begin
        case (state)
            IDLE: begin
                if (i_start) begin
                    next_state = SEND_PREAMBLE          ;
                end else begin
                    next_state = IDLE                   ;
                end
            end
            SEND_PREAMBLE: begin
                next_state = SEND_HEADER                ;
            end
            SEND_HEADER: begin
                if (byte_counter >= 14) begin // 14 bytes for header
                    next_state = SEND_PAYLOAD           ;
                end else begin
                    next_state = SEND_HEADER            ;
                end
            end
            SEND_PAYLOAD: begin
                if (byte_counter >= (14 + payload_size)) begin
                    next_state = DONE                   ;
                end else begin
                    next_state = SEND_PAYLOAD           ;
                end
            end
            DONE: begin
                if (!i_start) begin
                    next_state = IDLE                   ;
                end else begin
                    next_state = DONE                   ;
                end
            end
            default: next_state = IDLE                  ;
        endcase
    end

    // Sequential logic: Frame generation
    always_ff @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_valid <= 1'b0                             ;
            o_frame_out <= 64'b0                        ;
            o_done <= 1'b0                              ;
            byte_counter <= 16'd0                       ;
            payload_size <= 16'd0                       ;
            header_shift_reg <= 512'b0                  ;
            payload_shift_reg <= 64'b0                  ;
        end else begin
            case (state)
                IDLE: begin
                    o_valid         <= 1'b0                 ;
                    o_frame_out     <= 64'b0                ;
                    o_done          <= 1'b0                 ;
                    byte_counter    <= 16'd0                ;

                    // Prepare header (14 bytes = 112 bits): Destination + Source + EtherType
                    header_shift_reg <= {PREAMBLE_SFD, i_dest_address, i_src_address, i_eth_type, 224'b0}; // Pad to 512 bits
                end
                SEND_PREAMBLE: begin
                    o_valid <= 1'b1;
                    o_frame_out <= header_shift_reg[511:448]            ; // Send the Preamble and SFD (64 bits)
                    header_shift_reg <= {header_shift_reg[447:0], 64'b0}; // Shift left
                end
                SEND_HEADER: begin
                    o_valid <= 1'b1                                     ;
                    o_frame_out <= header_shift_reg[511:448]            ; // Send the next 64 bits of the header
                    header_shift_reg <= {header_shift_reg[447:0], 64'b0}; // Shift left
                    byte_counter <= byte_counter + 8                    ; // Increment byte counter by 8
                end
                SEND_PAYLOAD: begin
                    if (i_payload_valid) begin
                        o_valid <= 1'b1;
                        o_frame_out <= {payload_shift_reg[55:0], i_payload_data}        ; // Shift in payload byte
                        payload_shift_reg <= {payload_shift_reg[55:0], i_payload_data}  ;
                        byte_counter <= byte_counter + 1                                ;
                        payload_size <= payload_size + 1                                ;
                    end
                end
                DONE: begin
                    o_valid <= 1'b0                                                     ;
                    o_done <= 1'b1                                                      ;
                end
            endcase
        end
    end

endmodule
