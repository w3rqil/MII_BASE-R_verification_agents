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
    parameter           PAYLOAD_LENGTH = 8
)
(
    input wire          clk                                                                                             ,
    input wire          i_rst_n                                                                                         ,
    input wire          i_mii_tx_en                                                                                     ,
    input wire          i_valid                                                                                         ,
    input wire          i_mac_done                                                                                      ,
    input wire          i_mii_tx_er                                                                                     , // 4'b0000
    input wire  [63:0]  i_mii_tx_d                                                                                      ,
    input wire  [PACKET_MAX_BITS-1:0] i_register                                                                        ,

    output wire         o_txValid                                                                                       ,
    output wire [63:0]  o_mii_tx_d                                                                                      ,
    output wire [7:0 ]  o_control
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

    logic [15:0] counter, next_counter                                                                                  ;
    logic [63:0] next_tx_data                                                                                           ;
    logic [7: 0] next_tx_control                                                                                        ;
                                                                                
    logic valid, next_valid                                                                                             ;
                                                                                
    logic [PACKET_MAX_BITS-1:0]     register                                                                            ;
    reg     [7:0]                   aux_reg                                                                             ;  // for the remmaining 1 byte
    reg     [PACKET_MAX_BITS-1:0]   gen_shift_reg                                                                       ; // 16 -> start & eof

    integer i;
    integer aux_int;
    integer int_counter;
    //reg outValid;

    integer aux_int_sr, byte_counter_int, AUX_TEST                                                                      ;

    always @(*) begin : state_machine
        if(PAYLOAD_LENGTH < 46) begin
            register = {
                        EOF_CODE                                    ,
                        i_register[8*PACKET_LENGTH - 8 - 1 -: 32]   ,
                        {8*(46 - PAYLOAD_LENGTH){1'b0}}             ,
                        i_register[8 +: 8*(PAYLOAD_LENGTH + 21)]    ,
                        START_CODE                                  }                                                   ;
        end
        else begin //
            register = {EOF_CODE, i_register[8*PACKET_LENGTH - 1 : 8], START_CODE}                                      ;
        end
        
        
        next_counter = counter                                                                                          ;
        next_state = state                                                                                              ;
        next_valid = valid                                                                                              ;

        case(state) 
            IDLE: begin
                next_tx_data = {8{IDLE_CODE}}                                                                           ;
                next_tx_control = 8'hFF                                                                                 ;
                //outValid = 1'b0;                                                                      
                if ((counter >= 12)) begin                                                                      
                    next_counter = 0                                                                                    ;
                    next_state = PAYLOAD                                                                                ;
                    next_valid = 1'b1                                                                                   ;
                end else begin                                                                      
                    next_counter = counter + 8                                                                          ;
                    next_state = IDLE                                                                                   ;
                end
            end
            PAYLOAD: begin
                //outValid = 1'b1;
                if(PAYLOAD_LENGTH < 46 && counter >= 64) begin
                    next_tx_data = register[8*counter +: 64]                                                            ;

                    next_tx_control = 8'h00                                                                             ;
                    next_counter = 8                                                                                    ;
                    next_state = DONE                                                                                   ;
                end // to do: better algorithms

                else if(PAYLOAD_LENGTH >= 46 && counter >= PACKET_LENGTH - 8) begin
                    if( (PACKET_LENGTH % 8) == 0) begin
                        next_tx_data = register[8*counter +: 64]                                                        ;

                        next_tx_control = 8'h00                                                                         ;
                        next_counter = 8                                                                                ;
                        next_state = DONE                                                                               ;
                    end 
                    else  begin
                                        //  ( 8 - pk_len + fd byte) % 8
                                        //                          % me da el resto despues de transmitir correctamente los anteriores mensajes

                        next_tx_data = {{8*(8 - (PACKET_LENGTH + 1) % 8){IDLE_CODE}}, 
                                        register[8*(PACKET_LENGTH + 1) - 1 -: 8*((PACKET_LENGTH + 1) % 8)]}             ;

                        next_tx_control = {{(8 - PACKET_LENGTH % 8){1'b1}}, {PACKET_LENGTH % 8{1'b0}}}                  ;
                        next_counter = (8 - (PACKET_LENGTH + 1) % 8); // value of idle code sended
                        next_state = IDLE;
                    end
                end
                else begin
                    next_tx_data = register[8*counter +: 64]                                                            ;

                    next_tx_control = 8'h00                                                                             ;
                    next_counter = counter + 8                                                                          ;
                    next_state = PAYLOAD                                                                                ;
                end
            end
            DONE: begin
                next_tx_data = {{7{IDLE_CODE}}, 8'hFD}                                                                  ;

                next_tx_control = 8'hFF                                                                                 ;
                next_counter = 7                                                                                        ; // sended 7 idle codes
                next_state = IDLE                                                                                       ;
            end
        endcase
    end


    always @(posedge clk or negedge i_rst_n) begin 

        if(!i_rst_n) begin
            state       <= IDLE                                                                                         ;
            counter     <= 0                                                                                            ;
            valid       <= 0                                                                                            ;
            //aux_int <= 0;
            //o_control   <= 0;
            //o_mii_tx_d  <= 0;
            
        end else begin
            state <= next_state                                                                                         ;
            counter <= next_counter                                                                                     ;
            valid <= next_valid                                                                                         ;
            //o_mii_tx_d <= next_tx_data;
            //o_control   <= 8'hFF;
        end 
    end


    assign o_txValid    = valid             ;
    assign o_mii_tx_d   = next_tx_data      ;
    assign o_control    = next_tx_control   ;


endmodule