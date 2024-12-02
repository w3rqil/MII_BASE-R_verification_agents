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

    localparam MAC_FRAME_LENGTH = (PAYLOAD_LENGTH + 14);
    localparam [7:0]
                    IDLE_CODE   = 8'h07,
                    START_CODE  = 8'hFB,
                    EOF_CODE    = 8'hFD;
    localparam []
    localparam [3:0]    
                    IDLE    = 4'b0001,
                    PAYLOAD = 4'b0010,
                    DONE    = 4'b0100;

    logic [3:0] state, next_state;

    logic [15:0] counter, next_counter;
    logic [63:0] next_tx_data;


    reg [7:0] aux_reg; // for the remmaining 1 byte

    integer i:


    always @(*) begin
        next_counter = counter;
        next_state = state;
        case(state) 
            IDLE: begin
                if(i_mii_tx_en) begin //mac start
                    if ((counter >= 12)) begin
                        next_state = PAYLOAD;
                        next_counter = 0;
                    end else begin
                        next_state = IDLE;
                    end
                end
                next_tx_data = {8{IDLE_CODE}};
                next_counter = counter + 8;

            end
            PAYLOAD: begin
                if(i_valid)begin
                    
                    if(counter == 0) begin
                        next_tx_data = {i_mii_tx_d[55:0], START_CODE};
                        aux_reg      = i_mii_tx_d [63:56];
                        next_counter = counter + 7;
    
                    end else begin

                        if(counter >= (MAC_FRAME_LENGTH - 8)) begin // counter equals the mac message size in bytes
                                                                   //
                            if(!((MAC_FRAME_LENGTH - 8) % 64)) begin

                                next_tx_data    = {(8 - ((MAC_FRAME_LENGTH - counter) + 2)){IDLE_CODE}  ,   // segun nosotros.  8           - [ MAC_FRAME_LENGTH - counter)     +       2               ]
                                                                                                            //                  (64 bits)   - [ (TX DATA SIZE )                 +  (2 bytes aux y eof)  ]
                                                                                        EOF_CODE        ,
                                                   i_mii_tx_d[(MAC_FRAME_LENGTH - counter)*8    : 0]    , 
                                                                                        aux_reg         };

                                next_counter    = (8 - ((MAC_FRAME_LENGTH - counter) + 2))              ;
                                next_state      = IDLE;
                            end else begin
                                next_tx_data = {i_mii_tx_d[55:0], aux_reg};
                                aux_reg      = i_mii_tx_d [63:56];
                                next_state = DONE;
                            end
                            
                        end else begin
                            next_tx_data = {i_mii_tx_d[55:0], aux_reg};
                            aux_reg      = i_mii_tx_d [63:56];
                            next_counter = counter + 8;
        
                            next_state = PAYLOAD;
                        end


                        
                    end
    

                end 

                next_state = IDLE;

            end
            DONE: begin
                next_tx_data = {6{IDLE_CODE}, EOF_CODE, aux_reg};
                next_counter = 6;
                next_state = IDLE;
                
            end
        endcase
        
    end


    always @(posedge clk or negedge i_rst_n) begin 
    end


endmodule