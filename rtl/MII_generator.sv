`timescale 1ns/100ps

// 07070707 - fbaaaaaa - 
module MII_generator 
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
    parameter [7:0] TERMINATE_CODE = 8'hFD
    )
    (
    input  logic                    tx_clk            ,   //! Clock input
    input  logic                    i_rst          ,   //! Asynchronous reset
    input  logic                    i_start        ,   //! Signal to start frame transmission
    input  logic [7:0]              i_interrupt    ,   //! Interrupt the frame into different scenarios
    output logic [7:0]              o_tx_data      ,   //! Transmitted data (8 bits per cycle)
    output logic                    o_tx_ctrl      ,   //! Transmit control signal (indicates valid data)
    );

    localparam [7:0]
                    DATA_CHAR_PATTERN = 8'hAA,
                    CTRL_CHAR_PATTERN = 8'h55;

    localparam [3:0]
                    IDLE        = 0,
                    START       = 1,
                    DATA        = 2,
                    EOF         = 3;

    localparam [7:0] 
                    STOP_TX     = 8'h01,
                    STOP_DATA   = 8'h02;
    
    // State
    state_t     state;
    state_t     next_state;

    // TXD Characters 
    logic [7:0] tx_data;
    logic [7:0] next_tx_data;

    // Counter
    logic [6:0] counter;
    logic [6:0] next_counter;

    // TXC
    logic       tx_ctrl;
    logic       next_tx_ctrl;

    function automatic void handle_state(
        input logic [7:0] i_data        , // Transmit code
        input logic       i_ctrl        , // Control bit
        input int         i_cycle_limit , // Cycles to change state
        input state_t     i_next_st       // Next state
    );
        next_tx_data = i_data;
        next_tx_ctrl = i_ctrl;
        if (counter < (i_cycle_limit - 1)) begin
            next_counter = counter + 1;
            next_state   = state;         // Mantener el mismo estado hasta cumplir con el ciclo
        end else begin
            next_counter = 0;
            next_state   = i_next_st;     // Cambiar al próximo estado
        end
    endfunction

    always_comb begin

        case (state)

            IDLE: begin
                if(!i_start) begin
                    next_tx_data    = IDLE_CODE                                     ;
                    next_tx_ctrl    = 1'b1                                          ;
                    next_state      = IDLE                                          ;
                end else begin                                  
                    next_state      = START                                         ;
                    next_counter    = 0                                             ;
                end
            end

            START: begin
                handle_state(START_CODE, 1'b1, 1, DATA);
            end

            DATA: begin
                if(i_interrupt == STOP_DATA) begin             
                    next_tx_data = 8'h00                                        ;    
                end else begin
                    next_tx_data = DATA_CHAR_PATTERN                            ;
                end

                if(counter < (DATA_CYCLES-1)) begin
                    next_state   = DATA                                             ;
                    next_counter = counter + 1                                      ;
                end else begin
                    next_state = EOF                                                ;
                    next_counter = 0                                                ;
                end
            end

            EOF: begin
                handle_state(EOF_CODE, 1'b1, 1, IDLE);
            end

            default: begin
                next_tx_data = 8'h00;
                next_tx_ctrl = 8'h00;
                next_counter = 0;
                next_state = IDLE;
            end
        endcase
    end

    // Control de transmisión de frames
    always_ff @(posedge tx_clk or posedge i_rst) begin
        if (i_rst) begin 
            tx_data     <= 8'd0                                                     ;
            tx_ctrl    <= 8'd0                                                     ;
            counter     <= 0                                                        ;
            state       <= IDLE                                                     ;
        end
        else begin
            tx_data <= next_tx_data                                                 ;
            tx_ctrl <= next_tx_ctrl                                               ;
            counter <= next_counter                                                 ;
            state <= next_state                                                     ;
        end

    end

    // Asignar los datos transmitidos y la señal de control
    assign o_tx_data = tx_data;
    assign o_tx_ctrl = tx_ctrl;

endmodule
