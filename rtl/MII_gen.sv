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


    reg [7:0] aux_reg; // for the remmaining 1 byte

    integer i;
    integer aux_int;

    always @(*) begin
        next_counter = counter;
        next_state = state;
        case(state) 
            IDLE: begin
                next_tx_data = {8{IDLE_CODE}};
                next_tx_control = 8'hFF;

                if(i_mii_tx_en) begin //mac start
                    if ((counter >= 12)) begin
                        next_counter = 0;
                        next_state = PAYLOAD;
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
                if(i_valid)begin
                    
                    if(counter == 0) begin
                        next_tx_data = {i_mii_tx_d[55:0], START_CODE};
                        aux_reg      = i_mii_tx_d [63:56];
                        next_tx_control = 8'h01;

                        next_counter = counter + 7;
                        next_state = PAYLOAD;
    
                    end else begin

                        if(counter >= (MAC_FRAME_LENGTH - 8)) begin // counter equals the mac message size in bytes
                            next_tx_data[7:0] = aux_reg;
                            next_tx_control[0] = 1'b0;

                            for(int i = 1; i < 8; i++) begin

                                if(i < MAC_FRAME_LENGTH - counter) begin
                                    next_tx_data[i*8 +: 8] = i_mii_tx_d[(i-1)*8 +: 8];
                                    next_tx_control[i] = 1'b0;

                                end else if(i == MAC_FRAME_LENGTH - counter) begin
                                    next_tx_data[i*8 +: 8] = EOF_CODE;
                                    next_tx_control[i] = 1'b1;

                                end else begin
                                    next_tx_data[i*8 +: 8] = IDLE_CODE;
                                    next_tx_control[i] = 1'b1;
                                end
                            end
                            
                            next_counter = counter;
                            next_state = i_mac_done ? DONE : PAYLOAD;

                        end else begin
                            next_tx_data = {i_mii_tx_d[55:0], aux_reg};
                            aux_reg      = i_mii_tx_d [63:56];
                            next_tx_control = 8'h00;

                            next_counter = counter + 8;
                            next_state = PAYLOAD;
                        end
                    end
    

                end else begin
                    next_tx_data = {8{IDLE_CODE}};
                    next_tx_control = 8'hFF;

                    next_counter = 8;
                    next_state = IDLE;
                end
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
            //o_control   <= 0;
            //o_mii_tx_d  <= 0;
            
        end else begin
            state <= next_state;
            counter <= next_counter;
            //o_mii_tx_d <= next_tx_data;
            //o_control   <= 8'hFF;
        end 
    end

    assign o_mii_tx_d   = next_tx_data;
    assign o_control    = next_tx_control;


endmodule