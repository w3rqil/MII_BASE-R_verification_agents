`timescale 1ns/100ps

module EthernetFrameGenerator 
#(
    /*
    *---------WIDTH---------
    */
    parameter int DATA_WIDTH = 64,
    parameter int CTRL_WIDTH = DATA_WIDTH / 8,
    /*
    *---------CYCLES---------
    */
    parameter int IDLE_CYCLES = 12          ,   //! Idle length 
    parameter int PREAMBLE_CYCLES = 6       ,   //! Preamble length
    parameter int DST_ADDR_CYCLES = 6       ,   
    parameter int SRC_ADDR_CYCLES = 6       ,
    parameter int LEN_TYP_CYCLES = 2        ,
    parameter int DATA_CYCLES = 46          ,   //! Data length
    parameter int FCS_CYCLES = 4            ,
    /*
    *---------CODES---------
    */
    parameter [7:0] IDLE_CODE = 8'h07       ,
    parameter [7:0] START_CODE = 8'hFB      ,
    parameter [7:0] PREAMBLE_CODE = 8'h55   ,
    parameter [7:0] SFD_CODE = 8'hD5        ,

    parameter [47:0] DST_ADDR_CODE = 48'h0180C2000001   ,
    parameter [47:0] SRC_ADDR_CODE = 48'h5A5152535455   ,
    parameter [15:0] LEN_TYP_CODE = 16'h8808            ,
    parameter [31:0] FCS_CODE = 8'hC0C0C0C0             ,
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

    // Parameters for frame sections
    localparam int PACKET_SIZE = IDLE_CYCLES + PREAMBLE_CYCLES + DST_ADDR_CYCLES + SRC_ADDR_CYCLES
                                + LEN_TYP_CYCLES + DATA_CYCLES + FCS_CYCLES;

    localparam [7:0]
                    DATA_CHAR_PATTERN = 8'hAA,
                    CTRL_CHAR_PATTERN = 8'h55;

    localparam [3:0]
                    IDLE        = 0,
                    START       = 1,
                    PREAMBLE    = 2,
                    SFD         = 3,
                    DST_ADDR    = 4,
                    SRC_ADDR    = 5,
                    LEN_TYP     = 6,
                    DATA        = 7,
                    FCS         = 8,
                    EOF         = 9;

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

    // Output signals
    assign o_tx_data = tx_data_block;
    assign o_tx_ctrl = tx_ctrl_block;

    // Function to handle state transitions
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

    // Initialize frame content
    always_comb begin
        next_counter = counter;
        next_state = state;
        next_tx_data = tx_data;
        next_tx_data_block = tx_data_block;
        next_tx_ctrl_block = tx_ctrl_block;

        case (state)
            IDLE: begin
                if(!i_start) begin
                    next_tx_data_block    = {8{IDLE_CODE}};
                    next_tx_ctrl_block    = 8'hFF; // All bytes are control bytes (IDLE)
                    next_state            = IDLE;
                end else begin                                  
                    next_state            = START;
                    next_counter          = 0;
                end
            end

            START: begin
                next_tx_data_block    = {START_CODE, {7{IDLE_CODE}}};
                next_tx_ctrl_block    = 8'b00000001; // Only the first byte is data (START)
                next_state            = PREAMBLE;
                next_counter          = 0;
            end

            PREAMBLE: begin
                handle_state(PREAMBLE_CODE, PREAMBLE_CYCLES, SFD);
                next_tx_ctrl_block = 8'h00; // All bytes are data bytes (PREAMBLE)
            end

            SFD: begin
                next_tx_data_block = {SFD_CODE, {7{PREAMBLE_CODE}}};
                next_tx_ctrl_block = 8'b00000001; // Only the first byte is data (SFD)
                next_state = DST_ADDR;
                next_counter = 0;
            end

            DST_ADDR: begin
                handle_state(DST_ADDR_CODE, DST_ADDR_CYCLES, SRC_ADDR);
                next_tx_ctrl_block = 8'h00; // All bytes are data bytes (DST_ADDR)
            end

            SRC_ADDR: begin
                handle_state(SRC_ADDR_CODE, SRC_ADDR_CYCLES, LEN_TYP);
                next_tx_ctrl_block = 8'h00; // All bytes are data bytes (SRC_ADDR)
            end

            LEN_TYP: begin
                handle_state(LEN_TYP_CODE, LEN_TYP_CYCLES, DATA);
                next_tx_ctrl_block = 8'h00; // All bytes are data bytes (LEN_TYP)
            end

            DATA: begin
                if(i_interrupt == STOP_DATA) begin             
                    next_tx_data_block = {8{8'h00}};    
                end else begin
                    next_tx_data_block = {8{DATA_CHAR_PATTERN}};
                end

                if(counter < (DATA_CYCLES-1)) begin
                    next_state   = DATA;
                    next_counter = counter + 1;
                end else begin
                    next_state = FCS;
                    next_counter = 0;
                end
            end

            FCS: begin
                handle_state(FCS_CODE, FCS_CYCLES, EOF);
                next_tx_ctrl_block = 8'h00; // All bytes are data bytes (FCS)
            end

            EOF: begin
                next_tx_data_block = {TERMINATE_CODE, {7{IDLE_CODE}}};
                next_tx_ctrl_block = 8'b00000001; // Only the first byte is data (TERMINATE)
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
            tx_data_block <= {DATA_WIDTH{1'b0}};
            tx_ctrl_block <= {CTRL_WIDTH{1'b0}};
            counter <= 0;
            state <= IDLE;
        end else begin
            tx_data_block <= next_tx_data_block;
            tx_ctrl_block <= next_tx_ctrl_block;
            counter <= next_counter;
            state <= next_state;
        end
    end
endmodule
