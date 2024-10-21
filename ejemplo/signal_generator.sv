module signal_generator #(
    parameter DATA_WIDTH = 64,                 // Must be a multiple of 8 bits (octets)
    parameter int DATA_CHAR_PROBABILITY = 70,  // Probability in percentage (0-100)
    parameter [7:0] DATA_CHAR_PATTERN = 8'hAA, // Pattern for data character
    parameter [7:0] CTRL_CHAR_PATTERN = 8'h55  // Pattern for control character
)(
    input  logic clk,
    input  logic rst_n,
    output logic [DATA_WIDTH-1:0]        data_out,
    output logic [(DATA_WIDTH/8)-1:0]    ctrl_out
);
    // Internal variables
    int random_num;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= '0;
            ctrl_out <= '0;
        end else begin
            // For each octet, decide whether to generate a data or control character
            for (int i = 0; i < DATA_WIDTH/8; i++) begin
                random_num = $urandom_range(0, 99);
                if (random_num < DATA_CHAR_PROBABILITY) begin
                    // Data character
                    data_out[i*8 +: 8] <= DATA_CHAR_PATTERN;
                    ctrl_out[i]        <= 1'b0;
                end else begin
                    // Control character
                    data_out[i*8 +: 8] <= CTRL_CHAR_PATTERN;
                    ctrl_out[i]        <= 1'b1;
                end
            end
        end
    end
endmodule
