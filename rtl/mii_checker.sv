`timescale 1ns/100ps

`define SYNTHESIS

module mii_checker 
#(
    parameter int DATA_WIDTH = 64,
    parameter int CTRL_WIDTH = 8, 

    parameter [7:0] IDLE_CODE = 8'h07,
    parameter [7:0] START_CODE = 8'hFB,
    parameter [7:0] TERM_CODE = 8'hFD
)
(
    input  logic                  clk,
    input  logic                  i_rst_n,
    input  logic [DATA_WIDTH-1:0] i_tx_data,
    input  logic [CTRL_WIDTH-1:0] i_tx_ctrl,
    output logic                  payload_error,  // Error: payload fuera de rango
    output logic                  intergap_error, // Error: intergap insuficiente
    output logic                  other_error,    // Error: otros errores
    output logic [DATA_WIDTH-1:0] o_captured_data,
    output logic                  o_data_valid,
    output logic [DATA_WIDTH-1:0] o_buffer_data [0:256-1],
    output logic [(MAX_PACKET_SIZE+3)*8-1:0]     o_array_data
);

    // Constantes de validación
    localparam int MIN_PAYLOAD_BYTES = 46;
    localparam int MAX_PAYLOAD_BYTES = 1500;    //1500
    localparam int MAX = MIN_PAYLOAD_BYTES + MAX_PAYLOAD_BYTES;
    localparam int MAX_FRAME_SIZE = MAX_PAYLOAD_BYTES + 18; //1518
    localparam int MAX_PACKET_SIZE = MAX_FRAME_SIZE + 8;    //1526

    localparam int MIN_INTERGAP = 12; 
    localparam int MAX_INTERGAP = 40;

    localparam int BUFFER_SIZE = 256;

    typedef enum logic [1:0] {
        WAIT_START = 2'b00,
        COUNT_DATA = 2'b01,
        CHECK_INTERGAP = 2'b10
    } state_t;

    // Señales internas
    state_t state, next_state;
    int payload_counter, next_payload_counter; 
    int intergap_counter, next_intergap_counter; 
    logic o_error, p_error, itg_error, idle_error; 
    logic found_term, found_start, valid_idle;
    logic [7:0] start_data_byte;
    logic [7:0] term_data_byte;
    logic tx_ctrl_bit;
    int i, j;

    logic [DATA_WIDTH-1:0] data_buffer [0 : BUFFER_SIZE-1]; 
    int buffer_index, next_buffer_index;
    logic capture_enable;
    logic valid;
    logic [(MAX_PACKET_SIZE+3)*8-1:0] array_data;
    int array_index;

    assign start_data_byte = i_tx_data[7:0];
    assign tx_ctrl_bit  = i_tx_ctrl[0];
    assign o_captured_data = data_buffer[buffer_index];
    assign o_data_valid = valid;
    assign o_buffer_data = data_buffer;
    assign o_array_data = array_data;

    // Lógica combinacional para determinar el próximo estado
    always_comb begin
        next_state = state;
        next_payload_counter = payload_counter;
        next_intergap_counter = intergap_counter;
        o_error = 1'b0;
        p_error = 1'b0;
        itg_error = 1'b0;
        found_term = 1'b0;
        found_start = 1'b0;
        idle_error = 1'b0;
        valid_idle = 1'b0;
        valid = 1'b0;

        case (state)
        WAIT_START: begin
            if (start_data_byte == START_CODE && tx_ctrl_bit == 1'b1) begin
                next_state = COUNT_DATA;
                next_payload_counter = 7;
                capture_enable = 1'b1;
                next_buffer_index = 0;
                array_index = 0;
            end
        end

        COUNT_DATA: begin
            found_term = 1'b0; // Señal para indicar si encontramos TERM_CODE
            next_payload_counter = payload_counter;
            next_intergap_counter = 0;
        
            for (i = 0; i < 8; i = i + 1) begin
                if (!found_term) begin
                    if (i_tx_data[i*8 +: 8] == TERM_CODE && i_tx_ctrl[i] == 1'b1) begin
                       // i indica cuántos bytes válidos había antes
                        next_payload_counter = next_payload_counter + i; 

                        // i indica cuántos bytes de intergap había antes
                        next_intergap_counter = intergap_counter + (7-i); 
                        found_term = 1'b1; 
                    end
                end
            end
        
            if (found_term) begin
                // Verificar si lo que sigue al TERM_CODE es un IDLE_CODE
                valid_idle = 1'b1; // Suponemos que es válido inicialmente
                for (j = 0; j < 8; j = j + 1) begin
                    if (j > i && i_tx_ctrl[j] == 1'b1) begin
                        if (i_tx_data[j*8 +: 8] != IDLE_CODE) begin
                            valid_idle = 1'b0; // Encontramos algo que no es IDLE_CODE
                        end
                    end
                end

                if (!valid_idle) begin
                    idle_error = 1'b1;
                    other_error = 1'b1;
                end else begin
                    // Verificar si el payload está dentro de los límites
                    if (payload_counter < MIN_PAYLOAD_BYTES || payload_counter > MAX_PAYLOAD_BYTES) begin
                        p_error = 1'b1;
                    end
                    next_state = CHECK_INTERGAP;
                end
            end else begin
                next_payload_counter = payload_counter + 8;
                next_buffer_index = buffer_index + 1;
                capture_enable = 1'b1;
            end
        end
        
        CHECK_INTERGAP: begin
            valid = 1'b1;
            next_intergap_counter = intergap_counter; 
            next_payload_counter = 0; 
            capture_enable = 1'b0;

            for (i = 0; i < CTRL_WIDTH; i = i + 1) begin
                if (!found_start) begin
                    if (i_tx_ctrl[i] == 1'b1 && i_tx_data[i*8 +: 8] == START_CODE) begin
                        // $display("MII ARRAY DATA: %h", array_data);
                        //next_intergap_counter = intergap_counter + i; 
                        valid = 1'b0;
                        next_payload_counter = payload_counter + (7-i); 
                        found_start = 1'b1; 
                        capture_enable = 1'b1;
                        next_buffer_index = 0;
                        array_index = 0;
                        array_data = 0;
                    end
                end 
            end

            if(found_start) begin
                if (intergap_counter < MIN_INTERGAP || intergap_counter > MAX_INTERGAP) begin
                    itg_error = 1'b1;
                end
                next_state = COUNT_DATA;
                next_intergap_counter = 0;
                
            end else begin
                next_intergap_counter = intergap_counter + 8; 
            end     
        end    
        
        endcase
    end

    // Actualización sincrónica de los registros internos
    always_ff @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= WAIT_START;
            payload_counter <= 0;
            intergap_counter <= 0;
            capture_enable <= 0;
            buffer_index <= 0;
            array_data <= 0;
            array_index <= 0;
            for (i = 0; i < BUFFER_SIZE; i = i + 1) begin
                data_buffer[i] <= 0;
            end
        end else begin
            state <= next_state;
            payload_counter <= next_payload_counter;
            intergap_counter <= next_intergap_counter;
            payload_error <= p_error;
            intergap_error <= itg_error;
            other_error <= o_error;
            buffer_index <= next_buffer_index;
            if (capture_enable) begin
                data_buffer[next_buffer_index] <= i_tx_data;
                array_data[array_index*64 +: 64] <= i_tx_data;
                array_index <= array_index + 1;
            end
        end
    end

    // Logger (solo para simulación)
    `ifndef SYNTHESIS
    always @(posedge clk) begin
        if (payload_error) begin
            $display("----------------------------------------------------------");
            $display("[%0t ns] ERROR: Payload fuera de rango detectado", $time);
            $display("Bytes enviados: %0d", payload_counter );
            $display("----------------------------------------------------------");
        end
        if (itg_error) begin
            $display("----------------------------------------------------------");
            $display("[%0t ns] ERROR: Intergap", $time);
            $display("Bytes enviados: %0d", intergap_counter);
            $display("----------------------------------------------------------");
        end
        if (other_error) begin
            $display("----------------------------------------------------------");
            $display("[%0t ns] ERROR: Otros errores detectados", $time);
            $display("----------------------------------------------------------");
        end
    end
    `endif

endmodule