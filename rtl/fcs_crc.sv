module fcs_crc (
    input logic clk,                  // Señal de reloj
    input logic rst_n,                // Señal de reset activo en bajo
    input logic data_valid,           // Señal para habilitar la operación de cálculo de CRC
    input logic [31:0] data_in,      // Entrada de datos de 32 bits
    output logic [31:0] crc_out      // Salida del CRC-32
);

// Polinomio CRC-32 (IEEE 802.3)
localparam logic [32:0] CRC_POLYNOMIAL = 33'h04C11DB7;

// Registro para almacenar el valor actual del CRC
logic [32:0] crc_reg;
logic [32:0] temp_data;
integer i;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Resetear el registro CRC en caso de reset
        crc_reg <= 33'hFFFFFFFF;
    end else if (data_valid) begin
        // XOR de los datos de entrada con el valor actual de CRC
        temp_data = {data_in, 1'b0} ^ crc_reg;
        for (i = 0; i < 32; i++) begin
            if (temp_data[32]) begin
                temp_data = (temp_data << 1) ^ CRC_POLYNOMIAL;
            end else begin
                temp_data = temp_data << 1;
            end
        end
        crc_reg <= temp_data;
    end
end

// Asignar el CRC calculado a la salida (invertir según la norma IEEE 802.3)
assign crc_out = ~crc_reg[31:0];

endmodule