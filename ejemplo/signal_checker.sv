
module signal_checker #(
    // Parameters
    parameter DATA_WIDTH = 64,                 // Interface data width (must be a multiple of 8 bits)
    parameter [7:0] DATA_CHAR_PATTERN = 8'hAA, // Expected pattern for data characters
    parameter [7:0] CTRL_CHAR_PATTERN = 8'h55  // Expected pattern for control characters
)(
    // Ports
    input  logic clk,                               // Clock signal
    input  logic rst_n,                             // Active-low reset signal
    input  logic [DATA_WIDTH-1:0]        data_in,   // Input data bus
    input  logic [(DATA_WIDTH/8)-1:0]    ctrl_in,   // Input control signals (1 bit per byte)
    output logic [31:0] total_char_count,           // Total number of characters received
    output logic [31:0] data_char_count,            // Number of data characters received
    output logic [31:0] ctrl_char_count,            // Number of control characters received
    output logic [31:0] data_error_count,           // Number of data character errors detected
    output logic [31:0] ctrl_error_count            // Number of control character errors detected
);

    // State machine states
    typedef enum logic [1:0] {
        WAITING    = 2'b00, // Waiting for the first valid data
        MONITORING = 2'b01  // Monitoring and counting characters and errors
    } state_t;

    state_t current_state, next_state; // State variables

    // Internal signal to detect receipt of valid data
    logic received_valid_data;

    // State register: Update current state on each clock edge or reset
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= WAITING; // On reset, start in WAITING state
        end else begin
            current_state <= next_state; // Transition to next state
        end
    end

    // Next state logic: Determine the next state based on current state and inputs
    always_comb begin
        next_state = current_state; // Default to staying in the current state
        case (current_state)
            WAITING: begin
                if (received_valid_data) begin
                    next_state = MONITORING; // Transition to MONITORING when valid data is detected
                end
            end
            MONITORING: begin
                // Remain in MONITORING state indefinitely
                next_state = MONITORING;
            end
            default: begin
                next_state = WAITING; // Default to WAITING state
            end
        endcase
    end

    // Detect when valid data is received
    // Here, we assume valid data is present when any bit in ctrl_in or data_in is non-zero
    always_comb begin
        received_valid_data = |ctrl_in || |data_in; // Logical OR reduction across all bits
    end

    // Counters: Update counts based on received data and control signals
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all counters to zero
            total_char_count  <= 0;
            data_char_count   <= 0;
            ctrl_char_count   <= 0;
            data_error_count  <= 0;
            ctrl_error_count  <= 0;
        end else begin
            if (current_state == MONITORING) begin
                // Temporary accumulators for counts within this clock cycle
                static int temp_total_char_count      = 0;
                static int temp_data_char_count       = 0;
                static int temp_ctrl_char_count       = 0;
                static int temp_data_error_count      = 0;
                static int temp_ctrl_error_count      = 0;

                // Loop over each byte (octet) in the data and control inputs
                for (int i = 0; i < DATA_WIDTH/8; i++) begin
                    // Increment total character count
                    temp_total_char_count = temp_total_char_count + 1;

                    if (ctrl_in[i] == 1'b0) begin
                        // Data character detected
                        temp_data_char_count = temp_data_char_count + 1;
                        // Check if the data character matches the expected pattern
                        if (data_in[i*8 +: 8] != DATA_CHAR_PATTERN) begin
                            // Data character error detected
                            temp_data_error_count = temp_data_error_count + 1;
                        end
                    end else begin
                        // Control character detected
                        temp_ctrl_char_count = temp_ctrl_char_count + 1;
                        // Check if the control character matches the expected pattern
                        if (data_in[i*8 +: 8] != CTRL_CHAR_PATTERN) begin
                            // Control character error detected
                            temp_ctrl_error_count = temp_ctrl_error_count + 1;
                        end
                    end
                end

                // Update output counters with accumulated values
                total_char_count  <= total_char_count  + temp_total_char_count;
                data_char_count   <= data_char_count   + temp_data_char_count;
                ctrl_char_count   <= ctrl_char_count   + temp_ctrl_char_count;
                data_error_count  <= data_error_count  + temp_data_error_count;
                ctrl_error_count  <= ctrl_error_count  + temp_ctrl_error_count;
            end
            // If in WAITING state, do not update counts
        end
    end
endmodule

