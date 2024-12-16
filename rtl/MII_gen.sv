module MII_gen
#(
    parameter           PAYLOAD_MAX_SIZE = 1500                                                                         , // Maximum payload size in bytes

    /* Packet structure:
        - Preamble: 7 bytes
        - SFD: 1 byte
        - Destination adress: 6 bytes
        - Source adress: 6 bytes
        - Length/Type: 2 bytes
        - Client Data (Payload): 46-1500 bytes
        - Frame Check Sequence (CRC): 4 bytes 
    */
    parameter           PACKET_MAX_BITS = 8*(PAYLOAD_MAX_SIZE + 26)                                                     ,
    parameter   [7:0]   PAYLOAD_CHAR_PATTERN = 8'h55                                                                    ,
    parameter           PAYLOAD_LENGTH = 8                                                                              ,
)
(
    input wire  clk,
    input wire  i_rst_n,
    input wire  i_mii_tx_en,
    input wire  i_valid,
    input wire  i_mac_done,
    input wire  i_mii_tx_er, // 4'b0000
    input wire  [63:0] i_mii_tx_d,
    input wire  [PACKET_MAX_BITS-1:0] i_register,

    output wire [63:0] o_mii_tx_d,
    output wire [7:0 ] o_control
);

    localparam PACKET_LENGTH = PAYLOAD_LENGTH + 26;

    localparam [7:0]
                    IDLE_CODE   = 8'h07,
                    START_CODE  = 8'hFB,
                    EOF_CODE    = 8'hFD;
    
    localparam [3:0]    
                    IDLE    = 4'b0001,
                    PAYLOAD = 4'b0010,
                    DONE    = 4'b0100;

    logic [3:0] state, next_state;

    logic [15:0] counter, next_counter;
    logic [63:0] next_tx_data;
    logic [7:0] next_tx_control;

    logic valid, next_valid;

    logic [PACKET_MAX_BITS-1:0] register;
    reg [7:0] aux_reg; // for the remmaining 1 byte
    reg [PACKET_MAX_BITS-1:0] gen_shift_reg; // 16 -> start & eof

    integer i;
    integer aux_int;
    integer int_counter;

    integer aux_int_sr, byte_counter_int, AUX_TEST;

    always @(*) begin : act_shift_reg
        gen_shift_reg[7:0] = START_CODE;
        gen_shift_reg[8*PAYLOAD_LENGTH - 1 -: 8] = EOF_CODE; // last = EOF
        if(i_valid) begin  //actualizo solo si valid 

            if((int_counter = (PAYLOAD_LENGTH)*8 + 112)) begin // y si no actulizó todo el payload sin contar padding

            gen_shift_reg [(aux_int*64 + 8) +: 64] <= i_mii_tx_d;
            gen_shift_reg[PACKET_MAX_BITS - 1 -: 8] = EOF_CODE; // last = EOF

            aux_int = aux_int + 1;
            end
            int_counter = int_counter + 8;

            gen_shift_reg[PACKET_MAX_BITS - 1 -: 8] = EOF_CODE; // last = EOF

        end else begin
            // for(i=0; i < PACKET_MAX_BITS i +1) begin //inicializo en 0
            //     gen_shift_reg[i*8 +: 8] = 8'h00;
            // end

            gen_shift_reg[PACKET_MAX_BITS - 1 -: 8] = EOF_CODE; // last = EOF

            aux_int = 0;
            int_counter = 0;
        end
    end



    always @(*) begin : state_machine

        register = {EOF_CODE, i_register[8*PACKET_LENGTH - 8 - 1 : 8], START_CODE};
        
        next_counter = counter;
        next_state = state;
        next_valid = valid;

        case(state) 
            IDLE: begin
                //aux_int = 0;
                // aux_int_sr = 0;
                // byte_counter_int = 0;
                next_tx_data = {8{IDLE_CODE}};
                next_tx_control = 8'hFF;

                if(i_valid) begin //mac start

                    if ((counter >= 12)) begin
                        next_counter = 0;
                        next_state = PAYLOAD;
                        next_valid = 1'b1;
                    end else begin
                        next_counter = counter + 8;
                        next_state = IDLE;
                    end
                end else begin
                    next_counter = counter + 8;
                    next_state = IDLE;
                end
            end
            PAYLOAD: begin

                if(valid) begin
                    next_tx_data = register[64*counter +: 64];

                    for ( i=0; i < 64; i= i +1) begin
                        if(next_tx_data[i*8 +:8] == START_CODE || next_tx_data[i*8 +:8] == EOF_CODE) begin
                            next_tx_control[i] = 1'b1;
                        end else begin
                            next_tx_control[i] = 1'b0;
                        end
                    end
                    next_counter = counter + 8;
                end
                
                if(i_mac_done) begin 
                    if(counter*8 >= PACKET_LENGTH) begin
                        if((counter - PACKET_LENGTH) == 0) begin
                            next_valid = 0;
                        end else if( (PACKET_LENGTH % 64) != 0) begin
                            next_tx_data = {{(64 - PACKET_LENGTH%64){IDLE_CODE}}, register[PACKET_LENGTH - 1 -: PACKET_LENGTH%64]};
                        end
                    end
                    
                    next_tx_control = 8'hFF;
                    next_valid = 1'b0;
                    next_counter = 8;
                    next_state = IDLE;
                end
            end
        endcase
        
    end


    always @(posedge clk or negedge i_rst_n) begin 

        if(!i_rst_n) begin
            state       <= IDLE;
            counter     <= 0;
            valid = 0;
            //aux_int <= 0;
            //o_control   <= 0;
            //o_mii_tx_d  <= 0;
            
        end else begin
            state <= next_state;
            counter <= next_counter;
            valid <= next_valid;
            //o_mii_tx_d <= next_tx_data;
            //o_control   <= 8'hFF;
        end 
    end

    assign o_mii_tx_d   = next_tx_data;
    assign o_control    = next_tx_control;


endmodule