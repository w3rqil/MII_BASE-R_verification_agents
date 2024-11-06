`timescale 1ns/100ps

module frame_generator 
#(
    /*
    *---------WIDTH---------
    */
    parameter int DATA_WIDTH = 64,
    parameter int CTRL_WIDTH = DATA_WIDTH / 8,
    /*
    *---------LENGTH---------
    */
    parameter int IDLE_LENGTH = 12          ,   //! Idle length
    parameter int DATA_LENGTH = 46          ,   //! Data length
    /*
    *---------CODES---------
    */
    parameter [7:0] IDLE_CODE = 8'h07       ,
    parameter [7:0] START_CODE = 8'hFB      ,
    parameter [7:0] DATA_CODE = 8'hAA       ,
    parameter [7:0] TERMINATE_CODE = 8'hFD
    )
    (
    input  logic                    clk            ,   //! Clock input
    input  logic                    i_rst          ,   //! Asynchronous reset
    input  logic                    i_start        ,   //! Signal to start frame transmission
    input  logic [7:0]              i_interrupt    ,   //! Interrupt the frame into different scenarios
    output logic [DATA_WIDTH-1:0]   o_tx_data      ,   //! Transmitted data (64 bits per cycle)
    output logic [CTRL_WIDTH-1:0]   o_tx_ctrl          //! Transmit control signal (indicates valid data)
    );

    localparam int
                    IDLE        = 0,
                    START       = 1,
                    DATA        = 2,
                    EOF         = 3;

    localparam [7:0] 
                    STOP_TX     = 8'h01,
                    STOP_DATA   = 8'h02;

    // State
    state_t state;
    state_t next_state;

    // Counter
    logic [7:0] counter;
    logic [7:0] next_counter;

    // Data block
    logic [DATA_WIDTH-1:0] tx_data;
    logic [DATA_WIDTH-1:0] next_tx_data;
    
    // Ctrl block
    logic [CTRL_WIDTH-1:0] tx_ctrl;
    logic [CTRL_WIDTH-1:0] next_tx_ctrl;

    // Output signals
    assign o_tx_data = tx_data;
    assign o_tx_ctrl = tx_ctrl;

    always_comb begin
        for (int i = 1; i <= IDLE_LENGTH; i++) begin
            next_tx_data[(i % 8) * 8 -: 8] = IDLE_CODE;
            
        end
    end


    // Initialize frame content
    always_comb begin
        next_counter = counter;
        next_state = state;
        next_tx_data = tx_data;
        next_tx_ctrl = tx_ctrl;

        case (state)
            IDLE: begin
                if(!i_start) begin
                    next_tx_data = {8{IDLE_CODE}};
                    next_tx_ctrl = 8'hFF; // All bytes are control bytes (IDLE)
                    next_state            = IDLE;
                end else begin                                  
                    next_state = START;
                    next_counter = 0;
                end
            end

            START: begin
                next_tx_data = {{7{DATA_CODE}}, START_CODE};
                next_tx_ctrl = 8'h01; // Only the first byte is data (START)
                next_state = DATA;
                next_counter = 0;
            end

            DATA: begin

                case ((DATA_LENGTH-7) % 9)
                    : 
                    default: 
                endcase
                if(DATA_LENGTH < 7) begin
                    for (int i = 0; i < DATA_WIDTH/8; i++) begin
                        if(i < DATA_LENGTH - 7) begin
                            next_tx_data[i*8 +: 8] = DATA_CODE;
                        end else begin
                            next_tx_data[i*8 +: 8] = TERMINATE_CODE;
                        end
                        
                    end


                    if (counter < (DATA_LENGTH - 7)) begin //-4 para ayudar con la logica
                        next_tx_data[(i % 8) * 8 -: 8] = IDLE_CODE;

                        if (i_interrupt == STOP_DATA) begin
                            next_tx_data = {8{8'h00}};
                        end else begin
                            next_tx_data = {8{DATA_CODE}};
                        end
                        next_state = DATA;
                        next_counter = counter + 8;
                    end else begin
                        next_tx_data = {{4{FCS_CODE}}, {4{DATA_CODE}}};
                        next_state = EOF;
                        next_counter = 0;
                    end
                end
            end

            EOF: begin
                next_tx_data = {{7{IDLE_CODE}}, TERMINATE_CODE};
                next_tx_ctrl = 8'b00000001; // Only the first byte is data (TERMINATE)
                next_state = IDLE;
                next_counter = 0;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Control de transmisión de frames
    always_ff @(posedge clk or posedge i_rst) begin
        if (i_rst) begin 
            tx_data <= {DATA_WIDTH{1'b0}};
            tx_ctrl <= {CTRL_WIDTH{1'b0}};
            counter <= 0;
            state <= IDLE;
        end else begin
            tx_data <= next_tx_data;
            tx_ctrl <= next_tx_ctrl;
            counter <= next_counter;
            state <= next_state;
        end
    end
endmodule