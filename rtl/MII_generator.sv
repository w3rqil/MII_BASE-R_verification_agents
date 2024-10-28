`timescale 1ns/100ps

module EthernetFrameGenerator 
#(
    /*
    *---------CYCLES---------
    */
    parameter int IDLE_CYCLES = 12          ,   //! Idle length
    parameter int PREAMBLE_CYCLES = 7       ,   //! Preamble length
    parameter int SFD_CYCLES = 1            ,   //! SFD length
    parameter int DST_ADDR_CYCLES = 6       ,   
    parameter int SRC_ADDR_CYCLES = 6       ,
    parameter int LEN_TYP_CYCLES = 2        ,
    parameter int FCS_CYCLES = 4            ,
    parameter int DATA_CYCLES = 46          ,   //! Data length
    /*
    *---------CODES---------
    */
    parameter [7:0] IDLE_CODE = 8'h07       ,
    parameter [7:0] START_CODE = 8'hFB      ,   //! No se usa
    parameter [7:0] PREAMBLE_CODE = 8'h55   ,
    parameter [7:0] SFD_CODE = 8'hD5        ,
    parameter [7:0] DST_ADDR_CODE = 8'h01   ,
    parameter [7:0] SRC_ADDR_CODE = 8'h02   ,
    parameter [7:0] LEN_TYP_CODE = 8'h03    ,
    parameter [7:0] FCS_CODE = 8'h04        ,
    parameter [7:0] TERMINATE_CODE = 8'hFD
)
(
    input  logic        clk            ,   //! Clock input
    input  logic        i_rst          ,   //! Asynchronous reset
    input  logic        i_start        ,   //! Signal to start frame transmission
    input  logic [7:0]  i_interrupt    ,   //! Interrupt the frame into different scenarios
    output logic [7:0]  o_tx_data      ,   //! Transmitted data (8 bits per cycle)
    output logic [7:0]  o_tx_ctrl          //! Transmit control signal (indicates valid data)
);

    // Parameters for frame sections
    localparam int FRAME_SIZE = IDLE_CYCLES + PREAMBLE_CYCLES + SFD_CYCLES + DATA_CYCLES;
    localparam [7:0] 
                    DATA_CHAR_PATTERN = 8'hAA,
                    CTRL_CHAR_PATTERN = 8'h55;

    localparam [3:0]
                    IDLE        = 0,
                    PREAMBLE    = 1,
                    SFD         = 2,
                    DST_ADDR    = 3,
                    SRC_ADDR    = 4,
                    LEN_TYP     = 5,
                    DATA        = 6,
                    FCS         = 7,
                    EOF         = 8;

    localparam [7:0] 
                    STOP_TX     = 8'h01,
                    STOP_DATA   = 8'h02;
    /*
    // Frame content
    logic [7:0] frame [0:FRAME_SIZE-1]          ;
    logic [7:0] random_data [0:DATA_CYCLES-1]   ;

    // Internal signals
    logic [$clog2(FRAME_SIZE)-1:0] frame_index  ;
    logic                          transmitting ;
    */
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
    logic [7:0] tx_ctrl;
    logic [7:0] next_tx_ctrl;

    // Random
    int random_num;

    // Initialize frame content
    always_comb begin
        next_counter = counter                                                      ;
        next_state = state                                                          ;
        next_tx_data = tx_data                                                      ;

        case (state) 
            IDLE: begin
                if(!i_start) begin
                    next_tx_data    = IDLE_CODE                                     ;
                    next_state      = IDLE                                          ;
                end else begin                                  
                    next_state      = PREAMBLE                                      ;
                    next_counter    = 0                                             ;
                end
            end

            PREAMBLE: begin
                //frame[0] = PREAMBLE_CODE;
                if(counter < (PREAMBLE_CYCLES-1)) begin
                    next_tx_data = PREAMBLE_CODE                                    ;
                    next_counter = counter + 1                                      ;
                    next_state   = PREAMBLE                                         ;
                end else begin                                  
                    next_state = SFD                                                ;
                    next_counter = 0                                                ;
                end
            end

            SFD: begin
                //frame[0] = SFD_CODE;
                next_tx_data = SFD_CODE                                             ;
                next_state = DST_ADDR                                               ;
                next_counter = 0                                                    ;
            end

            DST_ADDR: begin
                if(counter < (DST_ADDR_CYCLES-1)) begin
                    next_tx_data = DST_ADDR_CODE                                    ;
                    next_counter = counter + 1                                      ;
                    next_state   = DST_ADDR                                         ;
                end else begin
                    next_state   = SRC_ADDR                                         ;
                    next_counter = 0                                                ;
                end
            end

            SRC_ADDR: begin
                if(counter < (SRC_ADDR_CYCLES-1)) begin
                    next_tx_data = SRC_ADDR_CODE                                    ;
                    next_counter = counter + 1                                      ;
                    next_state   = SRC_ADDR                                         ;
                end else begin
                    next_state   = LEN_TYP                                          ;
                    next_counter = 0                                                ;
                end
            end

            LEN_TYP: begin
                if(counter < (LEN_TYP_CYCLES-1)) begin
                    next_tx_data = LEN_TYP_CODE                                     ;
                    next_counter = counter + 1                                      ;
                    next_state   = LEN_TYP                                          ;
                end else begin
                    next_state   = DATA                                             ;
                    next_counter = 0                                                ;
                end
            end

            DATA: begin
                if(counter < (DATA_CYCLES-1)) begin
                    if(i_interrupt == STOP_DATA) begin             
                        next_tx_data = 8'h00                                        ;    
                    end else begin
                        next_tx_data = DATA_CHAR_PATTERN                            ;
                    end
                    next_counter = counter + 1                                      ;
                    next_state   = DATA                                             ;
                end else begin
                    next_state = FCS                                                ;
                    next_counter = 0                                                ;
                end
            end

            FCS: begin
                if(counter < (FCS_CYCLES-1)) begin
                    next_tx_data = FCS_CODE                                         ;
                    next_counter = counter + 1                                      ;
                    next_state   = FCS                                              ;
                end else begin
                    next_state   = EOF                                              ;
                    next_counter = 0                                                ;
                end
            end

            EOF: begin
                //frame[0] = EOF_CODE;
                    next_tx_data = TERMINATE_CODE                                   ;
                    next_state = IDLE                                               ;
                    next_counter = 0                                                ;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
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
