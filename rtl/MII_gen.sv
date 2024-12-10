module MII_gen
#(
    parameter PAYLOAD_MAX_SIZE = 1500                                                                                   , // Maximum payload size in bytes
    parameter [7:0] PAYLOAD_CHAR_PATTERN = 8'h55                                                                        ,
    parameter PAYLOAD_LENGTH = 8
)
(
    input wire clk          ,
    input wire i_rst_n      ,
    input wire i_mii_tx_en  ,
    input wire i_valid      ,
    input wire i_mac_done   ,
    input wire i_mii_tx_er  , // 4'b0000
    input wire [63:0] i_mii_tx_d,

    output wire [63:0] o_mii_tx_d,
    output wire [7:0 ] o_control

);  
                                // PAYLOAD_LENGTH > min ? PAYLOAD_LENGTH + addr(12) + type(2) + preamble & sfd (8) : 
    localparam MAC_FRAME_LENGTH = (PAYLOAD_LENGTH >= 46)? (PAYLOAD_LENGTH + 12 + 2 + 8) : (PAYLOAD_LENGTH + 12 + 2 + 8);
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
    reg [7:0] aux_reg; // for the remmaining 1 byte

    integer i;
    integer aux_int;
    reg [(MAC_FRAME_LENGTH)*8 + 112 + 16 +24 -1:0] gen_shift_reg; // 16 -> start & eof
    integer int_counter;

    integer aux_int_sr, byte_counter_int, AUX_TEST;

    localparam TAM = (MAC_FRAME_LENGTH)*8 + 112 + 24 + 16;

    always @(*) begin : act_shift_reg
        gen_shift_reg[7:0] = START_CODE;
        gen_shift_reg[(MAC_FRAME_LENGTH)*8 + 112 + 24 + 16-1 -:8] = EOF_CODE; // last = EOF
        if(i_valid ) begin  //actualizo solo si valid 

            if((int_counter = (PAYLOAD_LENGTH)*8 + 112)) begin // y si no actulizó todo el payload sin contar padding

            gen_shift_reg [(aux_int*64 + 8) +: 64] <= i_mii_tx_d;
            gen_shift_reg[(MAC_FRAME_LENGTH)*8 + 112 + 24 + 16-1 -:8] = EOF_CODE; // last = EOF

            aux_int = aux_int + 1;
            end
            int_counter = int_counter + 8;

            gen_shift_reg[(MAC_FRAME_LENGTH)*8 + 112 + 24 + 16-1 -:8] = EOF_CODE; // last = EOF

        end else begin
            // for(i=0; i < (MAC_FRAME_LENGTH)*8 + 112 + 16; i = i +1) begin //inicializo en 0
            //     gen_shift_reg[i*8 +: 8] = 8'h00;
            // end

            gen_shift_reg[(MAC_FRAME_LENGTH)*8 + 112 + 24 + 16-1 -:8] = EOF_CODE; // last = EOF

            aux_int = 0;
            int_counter = 0;
        end
    end



    always @(*) begin : state_machine
        gen_shift_reg[(MAC_FRAME_LENGTH)*8 + 112 + 24 + 16-1 -:8] = EOF_CODE; // last = EOF

        next_counter = counter;
        next_state = state;
        next_valid = valid;
        case(state) 
            IDLE: begin
                //aux_int = 0;
                aux_int_sr = 0;
                byte_counter_int = 0;
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
                //if(i_valid)begin
                    
                    // if(counter == 0) begin
                    //     next_tx_data = {i_mii_tx_d[55:0], START_CODE};
                    //     aux_reg      = i_mii_tx_d [63:56];
                    //     next_tx_control = 8'h01;

                    //     next_counter = counter + 7;
                    //     next_state = PAYLOAD;
    
                    // end else begin

                    //     if(counter >= (MAC_FRAME_LENGTH - 8)) begin // counter equals the mac message size in bytes (before the last message)
                    //         next_tx_data[7:0] = aux_reg;
                    //         next_tx_control[0] = 1'b0;

                    //         for(int i = 1; i < 8; i++) begin

                    //             if(i < MAC_FRAME_LENGTH - counter) begin //
                    //                 next_tx_data[i*8 +: 8] = i_mii_tx_d[(i-1)*8 +: 8];
                    //                 next_tx_control[i] = 1'b0;

                    //             end else if(i == MAC_FRAME_LENGTH - counter) begin //
                    //                 next_tx_data[i*8 +: 8] = EOF_CODE;
                    //                 next_tx_control[i] = 1'b1;

                    //             end else begin //
                    //                 next_tx_data[i*8 +: 8] = IDLE_CODE;
                    //                 next_tx_control[i] = 1'b1;
                    //             end
                    //         end
                            
                    //         next_counter = counter;
                    //         next_state = i_mac_done ? DONE : PAYLOAD;

                    //     end else begin
                    //         next_tx_data = {i_mii_tx_d[55:0], aux_reg};
                    //         aux_reg      = i_mii_tx_d [63:56];
                    //         next_tx_control = 8'h00;

                    //         next_counter = counter + 8;
                    //         next_state = PAYLOAD;
                    //     end

                        

                    // end
                // if(byte_counter_int*8 >= TAM) begin
                //     if((byte_counter_int - TAM) == 0) begin
                //         next_valid = 0;
                //     end else if( (TAM % 64) != 0) begin
                //         next_tx_data = {{byte_counter_int*8 - TAM{IDLE_CODE}}, gen_shift_reg[ TAM -: TAM%64]};
                //     end
                // end
                if(valid) begin
                    next_tx_data = gen_shift_reg[aux_int_sr*64 +: 64];

                    for ( i=0; i < 64; i= i +1) begin
                        if(next_tx_data[i*8 +:8] == START_CODE || next_tx_data[i*8 +:8] == EOF_CODE ) begin
                            next_tx_control[i] = 1'b1;
                        end else
                            next_tx_control[i] = 1'b0;
                    end
                    byte_counter_int = byte_counter_int + 8;
                    aux_int_sr = aux_int_sr + 1;
                end

                //next_tx_data = gen_shift_

                //end else begin
                    if(i_mac_done) begin 
                        if(byte_counter_int*8 >= TAM) begin
                            if((byte_counter_int - TAM) == 0) begin
                                next_valid = 0;
                            end else if( (TAM % 64) != 0) begin
                                AUX_TEST= TAM%64;
                                next_tx_data = {{(64 - TAM%64){IDLE_CODE}}, gen_shift_reg[ TAM-1 -: TAM%64]};
                            end
                        end
                    //next_tx_data = {8{IDLE_CODE}};
                    next_tx_control = 8'hFF;
                    next_valid = 1'b0;
                    next_counter = 8;
                    next_state = IDLE;
                    end
                //end
            end
            DONE: begin
                if(MAC_FRAME_LENGTH - counter == 8) begin
                    next_tx_data = {{7{IDLE_CODE}}, EOF_CODE};
                    next_counter = 7;

                end else begin
                    next_tx_data = {8{IDLE_CODE}};
                    next_counter = 8;
                end
                next_tx_control = 8'hFF;

                next_state = IDLE;
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