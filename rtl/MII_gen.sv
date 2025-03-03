module MII_gen
#(
    /* Packet structure:
        - Preamble: 7 bytes
        - SFD: 1 byte
        - Destination adress: 6 bytes
        - Source adress: 6 bytes
        - Length/Type: 2 bytes
        - Client Data (Payload): 46-1500 bytes
        - Frame Check Sequence (CRC): 4 bytes 
    */
    parameter           PAYLOAD_MAX_SIZE = 1500                                                                         , // Maximum payload size in bytes
    parameter           PACKET_MAX_BITS      = 8*(PAYLOAD_MAX_SIZE + 26)
)
(
    input wire                        clk                                                                               ,
    input wire                        i_rst_n                                                                           ,
    input wire  [PACKET_MAX_BITS-1:0] i_register                                                                        ,
    input wire  [7: 0]                i_mode                                                                            ,
    input wire  [15:0]                i_payload_length                                                                  ,
    output wire                       o_txValid                                                                         ,
    output wire [63:0]                o_mii_tx_d                                                                        ,
    output wire [7:0 ]                o_mii_tx_c
);
    localparam [7:0]
                    IDLE_CODE   = 8'h07,
                    START_CODE  = 8'hFB,
                    EOF_CODE    = 8'hFD;
    
    localparam [7:0]
                    NO_PADDING      = 8'd2;
    localparam [3:0]    
                    IDLE    = 4'b0001,
                    PAYLOAD = 4'b0010,
                    DONE    = 4'b0100;
                    
    logic [15:0] payload_size;
    logic [15:0] packet_length;

    logic [3:0] state, next_state;

    logic [15:0] counter, next_counter                                                                                  ;
    logic [63:0] next_tx_data                                                                                           ;
    logic [7: 0] next_tx_control                                                                                        ;
                                                                                
    logic valid, next_valid                                                                                             ;

    integer i;

    always @(*) begin : state_machine
        
        payload_size = (i_payload_length < 46 && i_mode != NO_PADDING)? 46 : i_payload_length;
        packet_length = payload_size + 26;
        
        next_counter = counter                                                                                          ;
        next_state = state                                                                                              ;
        next_valid = valid                                                                                              ;

        case(state) 
            IDLE: begin
                next_valid = 1'b0                                                                                   ;
                next_tx_data = {8{IDLE_CODE}}                                                                           ;
                next_tx_control = 8'hFF                                                                                 ;
                //outValid = 1'b0;                                                                      
                if ((counter >= 12)) begin                                                                      
                    next_tx_data = {i_register[63:8], START_CODE}                                                       ;
                    next_tx_control = 8'h01                                                                             ;

                    next_counter = 8                                                                                    ;
                    next_state = PAYLOAD                                                                                ;
                end else begin                                                                      
                    next_tx_data = {8{IDLE_CODE}}                                                                       ;
                    next_tx_control = 8'hFF                                                                             ;

                    next_counter = counter + 8                                                                          ;
                    next_state = IDLE                                                                                   ;
                end
            end
            PAYLOAD: begin
                next_valid = 1'b1                                                                                       ;
                if(counter >= packet_length - 8) begin // i_payload_length >= 46
                    if( (packet_length % 8) == 0) begin
                        next_tx_data = i_register[8*counter +: 64]                                                        ;

                        next_tx_control = 8'h00                                                                         ;
                        next_counter = 8                                                                                ;
                        next_state = DONE                                                                               ;
                    end 
                    else  begin
                        //  ( 8 - pk_len + fd byte) % 8
                        //                          % me da el resto despues de transmitir correctamente los anteriores mensajes
                        for(i=0; i<8; i++) begin
                            if(i < (packet_length - 8) % 8) begin
                                next_tx_data[i*8 +: 8] = i_register[8 * (counter + i) +: 8];
                            end
                            else if(i == (packet_length - 8) % 8) begin
                                next_tx_data[i*8 +: 8] = EOF_CODE;
                            end
                            else begin
                                next_tx_data[i*8 +: 8] = IDLE_CODE;
                            end
                        end
                        
                        for(i=0; i<8; i++) begin
                            if((next_tx_data[i*8 +:8] == START_CODE)|| (next_tx_data[i*8 +:8] == EOF_CODE) || (next_tx_data[i*8 +:8] == IDLE_CODE) )begin
                                next_tx_control[i] = 1'b1;
                            end else begin
                                next_tx_control [i]= 1'b0;
                            end
                        end
                        next_counter = (8 - (packet_length + 1) % 8); // value of idle code sended
                        next_state = IDLE;
                    end
                end
                else begin
                    next_tx_data = i_register[8*counter +: 64]                                                          ;
                    next_tx_control = 8'h00                                                                             ;
                    next_counter = counter + 8                                                                          ;
                    next_state = PAYLOAD                                                                                ;
                end
                //end
            end
            DONE: begin
                next_tx_data = {{7{IDLE_CODE}}, 8'hFD}                                                                  ;

                next_tx_control = 8'h01                                                                                 ;
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
            
        end else begin
            state <= next_state                                                                                         ;
            counter <= next_counter                                                                                     ;
            valid <= next_valid                                                                                         ;
        end 
    end


    assign o_txValid    = valid             ;
    assign o_mii_tx_d   = next_tx_data      ;
    assign o_mii_tx_c   = next_tx_control   ;


endmodule