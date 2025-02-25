`timescale 1ns/100ps

module mac_checker #
(
    parameter int DATA_WIDTH        = 64,
    parameter int CTRL_WIDTH        = 8,
    parameter int FCS_WIDTH         = 32, 

    parameter [7:0] IDLE_CODE       = 8'h07,
    parameter [7:0] START_CODE      = 8'hFB,
    parameter [7:0] TERM_CODE       = 8'hFD, 
    parameter [7:0] PREAMBLE_CODE   = 8'h55,
    parameter [7:0] SFD_CODE        = 8'hD5,
    parameter [47:0] DST_ADDR_CODE  = 48'hFFFFFFFFFFFF,
    parameter [47:0] SRC_ADDR_CODE  = 48'h123456789ABC
)
(
    input logic                         clk,
    input logic                         i_rst_n,
    input logic [DATA_WIDTH-1:0]        i_rx_data [0:255],
    input logic [MAX_FRAME_SIZE*8-1:0]  i_rx_array_data,
    input logic [CTRL_WIDTH-1:0]        i_rx_ctrl,
    input logic                         i_data_valid,
    output logic                        preamble_error,
    output logic                        fcs_error,   
    output logic                        header_error,
    output logic                        payload_error
);

    // Parámetros de los tamaños de los campos en bytes 
    localparam int PREAMBLE_SIZE        = 6;    // PREAMBLE STATE
    localparam int SFD_SIZE             = 1;    // PREAMBLE STATE
    localparam int DA_SIZE              = 6;    // HEADER STATE
    localparam int SA_SIZE              = 6;    // HEADER STATE
    localparam int LENGTH_TYPE          = 2;    // HEADER STATE
    localparam int FCS_SIZE             = 4;    // FCS STATE
    localparam int MIN_MAC_CLIENT_DATA  = 46;   // PAYLOAD STATE
    localparam int MAX_MAC_CLIENT_DATA  = 1504; // PAYLOAD STATE

    localparam int MIN_FRAME_SIZE       = 64;
    localparam int MAX_FRAME_SIZE       = 1518;

    logic [15:0] length_type; // 2 bytes
    logic [47:0] sa; // 6 bytes
    logic [47:0] da; // 6 bytes
    logic [FCS_WIDTH-1:0] fcs; // 4 bytes
    integer payload_size; // Tamaño del payload
    integer payload_counter; // Contador de bytes del payload
    logic [31:0] calculated_fcs;
    logic [31:0] calculated_crc32_v2;

    // Archivo de log
    integer log_file;
    integer counter; 
    reg [PREAMBLE_SIZE*8-1:0] preamble_accum;

    initial begin
        // Abrir archivo de log
        log_file = $fopen("D:/Escritorio/mac_checker.log", "w");
        if (log_file == 0) begin
            $display("Error: No se pudo abrir el archivo de log.");
            $finish;
        end
    end

    always_ff @(posedge i_data_valid or negedge i_rst_n) begin
        if (!i_rst_n) begin
            preamble_error <= 'd0;
            header_error <= 'd0;
            payload_error <= 'd0;
            fcs_error <= 'd0;
            counter <= 1;
            payload_size <= 0;
            payload_counter <= 0;
        end else if (i_data_valid) begin
            // Inicialización de errores y acumuladores
            preamble_error <= 'd0;
            header_error <= 'd0;
            payload_error <= 'd0;
            fcs_error <= 'd0;
            preamble_accum <= 48'b0;
            payload_counter <= 0;
            payload_size <= 0;

            $fdisplay(log_file, "\n=========================================\n");

            // Log del frame actual
            $fdisplay(log_file, "FRAME %d", counter);
            $fdisplay(log_file, "----> PREAMBULO y SFD <----");
    
            // Verificar el preámbulo y SFD del frame en i_rx_array_data
            for (int i = 0; i < 8; i++) begin
                logic [7:0] current_byte;
                current_byte = i_rx_array_data[(i * 8) +: 8]; // Extraer byte actual
    
                if (i == 0 && current_byte == START_CODE) begin
                    $fdisplay(log_file, "START CODE: %h", current_byte);
                end else if (i > 0 && i < 7 && current_byte == PREAMBLE_CODE) begin
                    preamble_accum = {preamble_accum[PREAMBLE_SIZE*8-9:0], current_byte};
                end else if (i == 7 && current_byte == SFD_CODE) begin
                    $fdisplay(log_file, "PREAMBLE CODE: %h", preamble_accum);
                    $fdisplay(log_file, "SFD CODE: %h", current_byte);
                end else begin
                    preamble_error <= 'd1;
                    $fdisplay(log_file, "ERROR: Byte inesperado %h", current_byte);
                end
            end

            // Verificar el header del frame 
            // SA - DA - LENGTH_TYPE
            $fdisplay(log_file, "----> HEADER (SA, DA, LENGTH_TYPE) <----");

            da = i_rx_array_data[64 +: 48];
            if (da == DST_ADDR_CODE) begin
                $fdisplay(log_file, "DA: %h", da);
            end else begin
                header_error <= 'd1;
                $fdisplay(log_file, "ERROR: DA inesperado %h", da);
            end

            sa = i_rx_array_data[112 +: 48];
            if (sa == SRC_ADDR_CODE) begin
                $fdisplay(log_file, "SA: %h", sa);
            end else begin
                header_error <= 'd1;
                $fdisplay(log_file, "ERROR: SA inesperado %h", sa);
            end

            length_type = i_rx_array_data[160 +: 16];
            $fdisplay(log_file, "LENGTH_TYPE: %h", length_type);

            if(length_type < 1500 && length_type >= 46) begin
                payload_size = length_type;
            end else if(length_type < 46) begin 
                payload_size = 46;
            end else begin
                payload_size = -1;
            end

            // Verificar el payload del frame
            $fdisplay(log_file, "----> PAYLOAD <----");
            if (payload_size > 1 && payload_size < 1500) begin
                if(payload_size >= 46) begin
                    $fdisplay(log_file, "PAYLOAD SIZE: %d", payload_size);
                end
                else begin
                    $fdisplay(log_file, "ERROR: LENGTH FIELD %d < 46", payload_size);
                end
            end else begin
                $fdisplay(log_file, "[PAYLOAD SIZE]: XXX");
            end
                
            // Contar Bytes de payload 
            for(int k = 176; k < 1500; k = k+8) begin
                logic [7:0] current_byte;
                current_byte = i_rx_array_data[k +: 8]; 
                // $fdisplay(log_file, "BYTE %d: %h Counter %d", k, current_byte, payload_counter);

                if(current_byte != TERM_CODE) begin
                    payload_counter = payload_counter + 1;
                end else begin
                    $fdisplay(log_file, "TERMINATION CODE %h", current_byte);
                    payload_counter = payload_counter - 4; 
                    // 1 byte term code y 4 de FCS
                    fcs = i_rx_array_data[(k - 32) +: 32];
                    break;
                end
            end
            
            $fdisplay(log_file, "PAYLOAD COUNTER: %d", payload_counter);

            if(payload_counter >= 46 && payload_counter <= 1500) begin 
                if(payload_counter == payload_size) begin
                    $fdisplay(log_file, "PAYLOAD OK");
                end else begin
                    payload_error <= 'd1;
                    $fdisplay(log_file, "ERROR: PAYLOAD %d ", payload_counter);
                end
            end
            else begin
                $fdisplay(log_file, "ERROR: PAYLOAD %d < 46", payload_counter);
            end
           
            // Verificar FCS
            $fdisplay(log_file, "----> FCS <----");
            $fdisplay(log_file, "FCS: %h", fcs);
            calculated_fcs = calculate_crc32(i_rx_array_data, payload_counter + 14);
            //$fdisplay(log_file, "CALCULATED FCS: %h", calculated_fcs);
            calculated_crc32_v2 = calculate_crc32_v2(i_rx_array_data, payload_counter + 22);
            $fdisplay(log_file, "CALCULATED FCS: %h", calculated_crc32_v2);
            //$fdisplay(log_file, "CAlCULATED FCS V3: %h", calculate_crc32_v3(i_rx_array_data, payload_counter + 24));
            
            if(fcs == calculated_crc32_v2) begin
                $fdisplay(log_file, "FCS OK");
            end else begin
                fcs_error <= 'd1;
                $fdisplay(log_file, "ERROR: FCS %h - CRC_CALCULATE: %0h", fcs, calculated_crc32_v2);
            end

            counter = counter + 1;
        end else begin
            preamble_error <= 'd0;
            header_error <= 'd0;
            payload_error <= 'd0;
            fcs_error <= 'd0;
        end
        $fflush(log_file);
    end    

    final begin
        // Cerrar el archivo al finalizar la simulación
        if (log_file != 0) begin
            $fclose(log_file);
        end
    end

    function automatic logic [31:0] calculate_crc32(
        input logic [MAX_FRAME_SIZE*8-1:0] frame_data,
        input integer frame_size
    );

        // Polinomio CRC-32 (IEEE 802.3)
        localparam logic [31:0] CRC_POLYNOMIAL = 32'h04C11DB7;

        logic [31:0] crc_reg;
        integer i, j;

        // Inicialización del CRC con 0xFFFFFFFF
        crc_reg = 32'hFFFFFFFF;

        // Recorrer bit a bit el frame
        for (i = 64; i < frame_size * 8; i = i + 1) begin
            logic bit_in = frame_data[i] ^ crc_reg[31];
            crc_reg = (crc_reg << 1) | bit_in;

            if (bit_in) begin
                crc_reg = crc_reg ^ CRC_POLYNOMIAL;
            end
        end

        // Complemento final
        return ~crc_reg;
    endfunction


    function automatic logic [31:0] calculate_crc32_v2
    (
        input logic [MAX_FRAME_SIZE*8-1:0] frame_data,
        input integer frame_size
    );

        logic [31:0] next_crc;
        logic [31:0] data_xor;
        int i, j;

        next_crc = 32'hFFFFFFFF;
        $display("FRAME SIZE: %h", frame_size);

        for(i = 64; i < (frame_size*8); i = i + 8) begin
            logic [7:0] next_frame_out;
            next_frame_out = frame_data[i +: 8];

            if (i == 64) begin
                data_xor = 32'hFFFFFFFF ^ {next_frame_out, 24'b0};
            end else begin
                data_xor = next_crc ^ {next_frame_out, 24'b0};
            end
            
            for (j = 0; j < 32; j = j + 1) begin
                if (data_xor[31]) begin
                    data_xor = (data_xor << 1) ^ 32'h04C11DB7;
                end else begin
                    data_xor = (data_xor << 1);
                end
            end
            
            next_crc = ~data_xor[31:0];
            $display("bit %d: FRAME CHECKER: %h   CRC CHECKER: %h", (i-64), next_frame_out, next_crc);
        end
        
        return next_crc;
    endfunction
    
    function automatic logic [31:0] calculate_crc32_v3(
        input logic [MAX_FRAME_SIZE*8-1:0] frame_data,
        input integer frame_size
    );
        // Polinomio CRC-32 (IEEE 802.3)
        localparam logic [31:0] CRC_POLYNOMIAL = 32'h04C11DB7;

        logic [31:0] crc_reg;
        integer i;
    
        // Inicialización del CRC con 0xFFFFFFFF
        crc_reg = 32'hFFFFFFFF;
    
        // Recorrer byte a byte el frame
        for (i = 8; i < frame_size; i = i + 1) begin
            logic [7:0] byte_in = frame_data[i*8 +: 8];

            // Loggear cada byte procesado
            $fdisplay(log_file, "Processing Byte Index: %0d, Value: %h", i, byte_in);

            // XOR del byte con los 8 bits más bajos del CRC
            crc_reg = crc_reg ^ (byte_in << 24);

            // Procesar los 8 bits del byte usando el polinomio
            repeat (8) begin
                if (crc_reg[31])
                    crc_reg = (crc_reg << 1) ^ CRC_POLYNOMIAL;
                else
                    crc_reg = (crc_reg << 1);
            end
        end

        // Complemento final
        return ~crc_reg;
    endfunction


endmodule

