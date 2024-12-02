`timescale 1ns/100ps

module tb_top;

    // Parameters
    localparam DATA_WIDTH = 64;
    localparam CTRL_WIDTH = DATA_WIDTH / 8;
    localparam CLK_PERIOD = 10; // Clock period in ns

    // Signals
    logic clk;
    logic rst;
    logic start;
    logic fixed_flag;
    logic [7:0] interrupt;

    logic [41:0] dst_addr;
    logic [41:0] src_addr;
    logic [15:0] frame_type;
    logic [15:0] opcode;

    logic payload_error;
    logic intergap_error;
    logic other_error;

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk; // Toggle clock every half period
    end

    // Reset generation
    initial begin
        rst = 1;
        #20 rst = 0; // De-assert reset after 20 ns
    end

    // DUT Instantiation
    top dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .fixed_flag(fixed_flag),
        .interrupt(interrupt),
        .dst_addr(dst_addr),
        .src_addr(src_addr),
        .frame_type(frame_type),
        .opcode(opcode),
        .payload_error(payload_error),
        .intergap_error(intergap_error),
        .other_error(other_error)
    );

    // Test stimulus
    initial begin
        // Initialize inputs
        start = 0;
        fixed_flag = 1; // Use fixed values by default
        interrupt = 0;
        dst_addr = 42'h0123456789;
        src_addr = 42'hABCDE12345;
        frame_type = 16'h0800; // Example frame type (IPv4)
        opcode = 16'h0001; // Example opcode

        // Wait for reset to complete
        @(negedge rst);

        // Test case 1: Basic frame generation and checking
        $display("[%0t ns] Starting basic frame generation test...", $time);
        start = 1; // Start frame generation
        @(posedge clk); // Wait for one clock
        start = 0;

        // Wait for frame transmission and checking to complete
        wait(payload_error || intergap_error || other_error || (!payload_error && !intergap_error && !other_error));
        $display("[%0t ns] Frame generation and checking complete.", $time);
        if (payload_error) $display("ERROR: Payload out of range detected!");
        if (intergap_error) $display("ERROR: Insufficient intergap detected!");
        if (other_error) $display("ERROR: Other error detected!");
        if (!payload_error && !intergap_error && !other_error) $display("SUCCESS: Frame passed all checks!");

        // Test case 2: Inject an interrupt scenario
        $display("[%0t ns] Injecting interrupt scenario (STOP_DATA)...", $time);
        interrupt = 8'h02; // Interrupt to stop data prematurely
        interrupt = 0;
        repeat (20) begin
            start = 1;
            @(posedge clk);
            start = 0;
        end

        // Wait for frame transmission and checking to complete
        wait(payload_error || intergap_error || other_error || (!payload_error && !intergap_error && !other_error));
        $display("[%0t ns] Interrupt scenario complete.", $time);
        if (payload_error) $display("ERROR: Payload out of range detected!");
        if (intergap_error) $display("ERROR: Insufficient intergap detected!");
        if (other_error) $display("ERROR: Other error detected!");
        if (!payload_error && !intergap_error && !other_error) $display("SUCCESS: Frame passed all checks!");
        //repeat (20)  @(posedge clk);
        // Add additional test cases as needed
        $display("[%0t ns] Test completed.", $time);
        $stop;
    end

    // Monitor for debugging
    always @(posedge clk) begin
        if (!rst) begin
            $display("[%0t ns] TX Data: %h, TX Ctrl: %h, Payload Error: %b, Intergap Error: %b, Other Error: %b",
                     $time, dut.tx_data, dut.tx_ctrl, payload_error, intergap_error, other_error);
        end
    end

endmodule
