module testbench();
    // Parameters
    parameter DATA_WIDTH = 64;                 // Must be a multiple of 8 bits (octets)
    parameter int DATA_CHAR_PROBABILITY = 50;  // Probability in percentage (0-100)
    parameter [7:0] DATA_CHAR_PATTERN = 8'hAA; // Data character pattern
    parameter [7:0] CTRL_CHAR_PATTERN = 8'h55; // Control character pattern
    parameter int ERROR_INJECTION_PROBABILITY = 50; // Probability of injecting error (0-100)
    parameter int NUM_CYCLES = 1000;           // Number of cycles to run

    // Testbench signals
    logic clk;
    logic rst_n;
    logic [DATA_WIDTH-1:0] data;
    logic [(DATA_WIDTH/8)-1:0] ctrl;

    // Signals after error injection
    logic [DATA_WIDTH-1:0] data_err_injected;
    logic [(DATA_WIDTH/8)-1:0] ctrl_err_injected;

    // Signal to indicate if an error has been injected per character
    logic [(DATA_WIDTH/8)-1:0] error_injected_per_char;

    // Signals to capture counts from checker
    logic [31:0] total_char_count;
    logic [31:0] data_char_count;
    logic [31:0] ctrl_char_count;
    logic [31:0] data_error_count;
    logic [31:0] ctrl_error_count;

    // Declare variables used in error injection and logging
    int rand_num;
    int bit_to_flip;
    int i; // Loop variable

    // Instantiate generator and checker modules
    signal_generator #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_CHAR_PROBABILITY(DATA_CHAR_PROBABILITY),
        .DATA_CHAR_PATTERN(DATA_CHAR_PATTERN),
        .CTRL_CHAR_PATTERN(CTRL_CHAR_PATTERN)
    ) u_generator (
        .clk(clk),
        .rst_n(rst_n),
        .data_out(data),
        .ctrl_out(ctrl)
    );

    signal_checker #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_CHAR_PATTERN(DATA_CHAR_PATTERN),
        .CTRL_CHAR_PATTERN(CTRL_CHAR_PATTERN)
    ) u_checker (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_err_injected),
        .ctrl_in(ctrl_err_injected),
        .total_char_count(total_char_count),
        .data_char_count(data_char_count),
        .ctrl_char_count(ctrl_char_count),
        .data_error_count(data_error_count),
        .ctrl_error_count(ctrl_error_count)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz clock

    // Error injection (only in data signal)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_err_injected       <= '0;
            ctrl_err_injected       <= '0;
            error_injected_per_char <= '0;
        end else begin
            // Use blocking assignments for immediate updates
            data_err_injected       = data;
            ctrl_err_injected       = ctrl;
            error_injected_per_char = '0;

            // For each character, decide whether to inject an error in data
            for (i = 0; i < DATA_WIDTH/8; i++) begin
                rand_num = $urandom_range(0, 99);
                if (rand_num < ERROR_INJECTION_PROBABILITY) begin
                    error_injected_per_char[i] = 1'b1; // Blocking assignment
                    // Flip a random bit in data
                    bit_to_flip = $urandom_range(0, 7); // 0-7 for data bits
                    data_err_injected[i*8 + bit_to_flip] = ~data_err_injected[i*8 + bit_to_flip]; // Blocking assignment
                end
            end
        end
    end

    // Optional logging
    parameter LOGGING_ENABLED = 0; // Set to 1 to enable logging

    always @(posedge clk) begin
        if (LOGGING_ENABLED) begin
            // Log summary in a single line
            $display("Time: %0t | Total Chars: %0d | Data Chars: %0d | Ctrl Chars: %0d | Data Errors: %0d | Ctrl Errors: %0d",
                     $time, total_char_count, data_char_count, ctrl_char_count, data_error_count, ctrl_error_count);
        end
    end

    // VCD dump
    initial begin
        $dumpfile("simulation.vcd");
        $dumpvars(0, testbench);
    end

    // Simulation control
    initial begin
        // Initialize signals
        rst_n                   = 0;
        data_err_injected       = '0;
        ctrl_err_injected       = '0;
        error_injected_per_char = '0;

        // Apply reset
        #20;
        rst_n = 1;

        // Run simulation for NUM_CYCLES
        repeat (NUM_CYCLES) @(posedge clk);

        // Finish simulation
        $display("Simulation finished after %0d cycles.", NUM_CYCLES);
        $display("Final Results:");
        $display("Total Characters Received: %0d", total_char_count);
        $display("Data Characters Received: %0d", data_char_count);
        $display("Control Characters Received: %0d", ctrl_char_count);
        $display("Data Character Errors Detected: %0d", data_error_count);
        $display("Control Character Errors Detected: %0d", ctrl_error_count);

        $finish;
    end
endmodule