module EthernetFrameGenerator 
#(
    parameter int IDLE_CYCLES = 12          ,
    parameter int PREAMBLE_CYCLES = 7       ,
    parameter int SFD_CYCLES = 1            ,
    parameter int DATA_CYCLES = 46          ,// Example data length
    /*+++++ CODES +++++*/
    parameter [7:0] IDLE_CODE = 8'h00       ,
    parameter [7:0] PREAMBLE_CODE = 8'h55   ,
    parameter [7:0] SFD_CODE = 8'hD5        ,
    parameter [7:0] EOF_CODE = 8'h00        
)
(
    input  logic        clk                 ,   //! Clock input
    input  logic        i_rst               ,   //! Asynchronous reset
    input  logic [7:0]  i_interrupt         ,   //! Interrupt the frame into different scenarios
    output logic [7:0]  o_tx_data           ,   //! Transmitted data (8 bits per cycle)
    output logic [7:0]  o_tx_ctrl           ,   //! Transmit control signal (indicates valid data)
    output logic        o_tx_clk            ,   //! Transmit clock
    input  logic        i_start                 //! Signal to start frame transmission
);

    // Parameters for frame sections

    localparam int FRAME_SIZE = IDLE_CYCLES + PREAMBLE_CYCLES + SFD_CYCLES + DATA_CYCLES;
    localparam [7:0] DATA_CHAR_PATTERN = 8'hAA, CTRL_CHAR_PATTERN = 8'h55;

    localparam [3:0]
                    IDLE        = 0000,
                    PREAMBLE    = 0001,
                    SFD         = 0010,
                    DATA        = 0011,
                    EOF         = 0100;

    localparam [7:0] 
                    STOP_TX     = 8'h01,
                    STOP_DATA   = 8'h02;

    // Frame content
    logic [7:0] frame [0:FRAME_SIZE-1]          ;
    logic [7:0] random_data [0:DATA_CYCLES-1]   ;
    //logic [3:0] state, next_state
    // Internal signals
    logic [$clog2(FRAME_SIZE)-1:0] frame_index  ;
    logic                          transmitting ;
    logic [3:0] state, next_state;
    logic [7:0] tx_data, next_tx_data           ;
    logic [6:0] counter, next_counter           ;
    logic [7:0] ctrl_out, next_ctrl_out         ;
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
                if(counter < PREAMBLE_CYCLES) begin
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
                if(counter < SFD_CYCLES) begin
                    next_tx_data = SFD_CODE                                         ;
                    next_counter = counter + 1                                      ;
                    next_state   = SFD                                              ;
                end else begin                                  
                    next_state = DATA                                               ;
                    next_counter = 0                                                ;
                end
            end

            DATA: begin
                
                 
                if(counter < DATA_CYCLES) begin
                    if(i_interrupt == STOP_DATA) begin             
                        next_tx_data = 8'h00                                        ;       
                    end else begin      
                        random_num = $urandom_range(0, 99)                          ;
                        if (random_num < DATA_CHAR_PROBABILITY) begin       
                            // Data character       
                            next_tx_data = DATA_CHAR_PATTERN                        ;
                            next_ctrl_out = {1'b0, ctrl_out[7:1]}                   ;
                        end else begin      
                            // Control character        
                            next_tx_data = CTRL_CHAR_PATTERN                        ;
                            next_ctrl_out = {1'b0, ctrl_out[7:1]}                   ;
                        end     
                    end     
                    next_counter = counter + 1                                      ;
                    next_state   = DATA                                             ;
                end else begin
                    next_state = EOF                                                ;
                    next_counter = 0                                                ;
                end
            end

            EOF: begin
                //frame[0] = EOF_CODE;
                    next_tx_data = EOF_CODE                                         ;
                    next_state = PREAMBLE                                           ;
                    next_counter = 0                                                ;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Clock generation (simplified for example)
    always_ff @(posedge clk or posedge i_rst) begin
        if (i_rst) begin
            tx_clk <= 1'b0                                                          ;
        end else begin
            tx_clk <= ~tx_clk                                                       ;
        end
    end

    // Control de transmisión de frames
    always_ff @(posedge tx_clk or posedge reset) begin
        if (i_rst) begin 
            tx_data     <= 8'd0                                                     ;
            ctrl_reg    <= 8'd0                                                     ;
            counter     <= 0                                                        ;
            state       <= IDLE                                                     ;
        end
        else begin
            tx_data <= next_tx_data                                                 ;
            ctrl_out <= next_ctrl_out                                               ;
            counter <= next_counter                                                 ;
            state <= next_state                                                     ;
        end

    end
    
    // Asignar los datos transmitidos y la señal de control
    assign o_tx_data = tx_data ;
    assign o_tx_ctrl = ctrl_out;
    //assign tx_data = (transmitting && frame_index < FRAME_SIZE) ? frame[frame_index] : 8'd0;
    //assign tx_ctrl = (transmitting && frame_index < FRAME_SIZE) ? 1'b1 : 1'b0; // Control signal indicating valid data
    
endmodule

