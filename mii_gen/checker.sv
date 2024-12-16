`timescale 1ns/100ps

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
    input  logic                  i_rst,
    input  logic [DATA_WIDTH-1:0] i_tx_data,
    input  logic [CTRL_WIDTH-1:0] i_tx_ctrl,
    output logic                  payload_error,  // Error: payload fuera de rango
    output logic                  intergap_error, // Error: intergap insuficiente
    output logic                  other_error    // Error: otros errores
);

    // Constantes de validación (40 a 136 bytes)
    localparam int MIN_PAYLOAD_BYTES = 40;
    localparam int MAX_PAYLOAD_BYTES = 136;

    localparam int MIN_INTERGAP = 12; // 16 Bytes mínimo entre tramas
    localparam int MAX_INTERGAP = 40; // 40 Bytes máximo entre tramas

    typedef enum logic [1:0] {
        WAIT_START = 2'b00,
        COUNT_DATA = 2'b01,
        CHECK_INTERGAP = 2'b10
    } state_t;

    // Señales internas
    state_t state, next_state;
    int payload_counter, next_payload_counter;  // Contador de ciclos de datos
    int intergap_counter, next_intergap_counter; // Contador de ciclos de intergap
    logic o_error, p_error, itg_error; 
    logic [7:0] start_data_byte;
    logic [7:0] term_data_byte;
    logic tx_ctrl_bit;
    int i, j;
    logic found_term, found_start, valid_idle, idle_error;

    assign start_data_byte = i_tx_data[7:0];
    assign tx_ctrl_bit  = i_tx_ctrl[0];

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

        case (state)
        WAIT_START: begin
            if (start_data_byte == START_CODE && tx_ctrl_bit == 1'b1) begin
                next_state = COUNT_DATA;
                next_payload_counter = 7; // Reinicia el contador de datos
            end
        end

        COUNT_DATA: begin
            found_term = 1'b0; // Señal para indicar si encontramos TERM_CODE en este ciclo
            next_payload_counter = payload_counter;
            next_intergap_counter = 0;
        
            for (i = 0; i < 8; i = i + 1) begin
                if (!found_term) begin
                    if (i_tx_data[i*8 +: 8] == TERM_CODE && i_tx_ctrl[i] == 1'b1) begin
                        // Encontramos TERM_CODE, contamos solo los bytes válidos antes de este
                        next_payload_counter = next_payload_counter + i; // i indica cuántos bytes válidos había antes
                        next_intergap_counter = intergap_counter + (7-i); // i indica cuántos bytes de intergap había antes
                        found_term = 1'b1; // Marcamos que encontramos el terminador
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
                    idle_error = 1'b1; // Error si lo que sigue al TERM_CODE no es IDLE_CODE
                end else begin
                    // Verificar si el payload está dentro de los límites
                    if (next_payload_counter < MIN_PAYLOAD_BYTES || next_payload_counter > MAX_PAYLOAD_BYTES) begin
                        p_error = 1'b1;
                    end
                    next_state = CHECK_INTERGAP;
                end
            end else begin
                next_payload_counter = next_payload_counter + 8;
            end
        end
        
        CHECK_INTERGAP: begin
            next_intergap_counter = intergap_counter; // Mantener el valor actual del contador
            next_payload_counter = 0; // Reiniciar el contador de payload

            for (i = 0; i < CTRL_WIDTH; i = i + 1) begin
                if (!found_start) begin
                    if (i_tx_ctrl[i] == 1'b1 && i_tx_data[i*8 +: 8] == START_CODE) begin
                       next_intergap_counter = intergap_counter + i; 
                        next_payload_counter = payload_counter + (7-i); 
                        found_start = 1'b1; // Indicar que hemos encontrado START_CODE
                    end
                end 
            end

            if(found_start) begin
                if (next_intergap_counter < MIN_INTERGAP || next_intergap_counter > MAX_INTERGAP) begin
                    itg_error = 1'b1;
                end
                next_state = COUNT_DATA;
            end else begin
                next_intergap_counter = intergap_counter + CTRL_WIDTH; // Incrementar el contador de intergap
            end     
        end    
        
        endcase
    end

    // Actualización sincrónica de los registros internos
    always_ff @(posedge clk or posedge i_rst) begin
        if (i_rst) begin
            state <= WAIT_START;
            payload_counter <= 0;
            //o_error <= 1'b0;
            //p_error <= 1'b0;
            //itg_error <= 1'b0;
            //intergap_counter <= 0;
            //found_term <= 1'b0;
            //found_start <= 1'b0;
        end else begin
            state <= next_state;
            payload_counter <= next_payload_counter;
            intergap_counter <= next_intergap_counter;
            payload_error <= p_error;
            intergap_error <= itg_error;
            other_error <= o_error;
        end
    end

    // Logger (solo para simulación)
    `ifndef SYNTHESIS
    always @(posedge clk) begin
        if (payload_error) begin
            $display("----------------------------------------------------------");
            $display("[%0t ns] ERROR: Payload fuera de rango detectado", $time);
            $display("Bytes enviados: %0d", payload_counter * (DATA_WIDTH / 8));
            $display("----------------------------------------------------------");
        end
        if (intergap_error) begin
            $display("----------------------------------------------------------");
            $display("[%0t ns] ERROR: Intergap", $time);
            $display("Bytes enviados: %0d", intergap_counter * (DATA_WIDTH / 8));
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
