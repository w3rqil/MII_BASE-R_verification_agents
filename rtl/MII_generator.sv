`timescale 1ns/100ps

module EthernetFrameGenerator 
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
    input  logic                    clk            ,   //! Clock input
    input  logic                    i_rst          ,   //! Asynchronous reset
    input  logic                    i_start        ,   //! Signal to start frame transmission
    input  logic [7:0]              i_interrupt    ,   //! Interrupt the frame into different scenarios
    output logic [7:0]              o_tx_data      ,   //! Transmitted data (8 bits per cycle)
    output logic                    o_tx_ctrl      ,   //! Transmit control signal (indicates valid data)
    output logic [DATA_WIDTH-1:0]   o_tx_data_block,
    output logic [CTRL_WIDTH-1:0]   o_tx_ctrl_block
    );

    // Parameters for frame sections
    localparam int TOTAL_SIZE = IDLE_LENGTH + DATA_LENGTH;

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
    logic [3:0] state;
    logic [3:0] next_state;

    // TXD Characters 
    logic [7:0] tx_data;
    logic [7:0] next_tx_data;

    // Counter
    logic [6:0] counter;
    logic [6:0] next_counter;

    // TXC
    logic       tx_ctrl;
    logic       next_tx_ctrl;

    // Data block
    logic [DATA_WIDTH-1:0] tx_data_block;
    logic [DATA_WIDTH-1:0] next_tx_data_block;
    
    // Ctrl block
    logic [CTRL_WIDTH-1:0] tx_ctrl_block;
    logic [CTRL_WIDTH-1:0] next_tx_ctrl_block;


    // Random
    int random_num;

    function automatic void handle_state(
        input logic [7:0] i_code        , // Transmit code
        input int         i_cycle_limit , // Cycles to change state
        input logic [3:0] i_next_st       // Next state
    );
        next_tx_data = i_code;
        if (counter < (i_cycle_limit - 1)) begin
            next_counter = counter + 1;
            next_state   = state;         // Mantener el mismo estado hasta cumplir con el ciclo
        end else begin
            next_counter = 0;
            next_state   = i_next_st;     // Cambiar al próximo estado
        end
    endfunction

    always_comb begin : block_insert
        for (int i = 0; i < TOTAL_SIZE; i++) begin
            if(i < IDLE_LENGTH) begin
                next_tx_data = IDLE_CODE;
                next_tx_ctrl = 1'b1;
                i++;
            end
            else if (i < DATA_LENGTH) begin
                next_tx_data = DATA_CHAR_PATTERN;
                next_tx_ctrl = 1'b0;
                i++;
            end
        end
    end

    // Control de transmisión de frames
    always_ff @(posedge clk or posedge i_rst) begin
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
    //assign tx_data = (transmitting && frame_index < FRAME_SIZE) ? frame[frame_index] : 8'd0;
    //assign tx_ctrl = (transmitting && frame_index < FRAME_SIZE) ? 1'b1 : 1'b0; // Control signal indicating valid data

endmodule
