`timescale 1ns/1ps

module tb_mac_mii_checker;

    // Parameters
    localparam PAYLOAD_LENGTH = 8;
    localparam CLK_PERIOD = 10;  // 100 MHz clock
    localparam PAYLOAD_MAX_SIZE = 64;

    // Signals
    reg clk;
    reg i_rst_n;
    reg i_start;
    reg [47:0] i_dest_address;
    reg [47:0] i_src_address;
    reg [15:0] i_eth_type;
    reg [15:0] i_payload_length;
    reg [7:0] i_payload[PAYLOAD_LENGTH-1:0];
    reg [7:0] i_interrupt;

    wire [63:0] o_mii_data;
    wire [7:0] o_mii_valid;

    // MII Checker Outputs
    wire payload_error, intergap_error, other_error;
    wire [63:0] o_captured_data;

    // MAC Checker Outputs
    wire preamble_error, fcs_error, header_error, mac_payload_error, o_data_valid;

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Instantiate mac_mii_top (combination of mac_frame_generator and MII_gen)
    mac_mii_top #(
        .PAYLOAD_MAX_SIZE(PAYLOAD_MAX_SIZE),
        .PAYLOAD_LENGTH(PAYLOAD_LENGTH)
    ) dut (
        .clk(clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        .i_dest_address(i_dest_address),
        .i_src_address(i_src_address),
        .i_eth_type(i_eth_type),
        .i_payload_length(i_payload_length),
        .i_payload(i_payload),
        .i_interrupt(i_interrupt),
        .o_mii_data(o_mii_data),
        .o_mii_valid(o_mii_valid)
    );

    // Instantiate mii_checker
    mii_checker #(
        .DATA_WIDTH(64),
        .CTRL_WIDTH(8)
    ) mii_checker_inst (
        .clk(clk),
        .i_rst(~i_rst_n),
        .i_tx_data(o_mii_data),
        .i_tx_ctrl(o_mii_valid),
        .payload_error(payload_error),
        .intergap_error(intergap_error),
        .other_error(other_error),
        .o_captured_data(o_captured_data)
    );

    // Instantiate mac_checker
    mac_checker #(
        .DATA_WIDTH(64),
        .CTRL_WIDTH(8),
        .FCS_WIDTH(32)
    ) mac_checker_inst (
        .clk(clk),
        .i_rst(~i_rst_n),
        .i_rx_data(o_captured_data),
        .i_rx_fcs(32'h0),       // Placeholder for FCS input
        .preamble_error(preamble_error),
        .fcs_error(fcs_error),
        .header_error(header_error),
        .payload_error(mac_payload_error),
        .o_data_valid(o_data_valid)
    );

    // Testbench logic
    initial begin
        // Initialize inputs
        i_rst_n = 0;
        i_start = 0;
        i_dest_address = 48'hFFFFFFFFFFFF;  // Broadcast address
        i_src_address = 48'h123456789ABC;   // Example source address
        i_eth_type = 16'h0800;              // IP protocol
        i_payload_length = PAYLOAD_LENGTH;
        i_interrupt = 8'd0;                 // No interrupt

        // Initialize payload data
        preload_payload(8, '{8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'hCA, 8'hFE, 8'hBA, 8'hBE}); // Example payload

        // Reset the system
        #20;
        i_rst_n = 1;

        // Test Case 1: Simple Frame Generation
        $display("Starting Test Case 1: Simple Frame Generation");
        simulate_frame(8);
        #200;

        // Test Case 2: Full Payload
        preload_payload(64, '{default: 8'hAA}); // Preload payload with 0xAA
        $display("Starting Test Case 2: Full Payload");
        simulate_frame(64);
        #200;

        // Test Case 3: Interruption Error
        preload_payload(16, '{8'hBB, 8'hCC, 8'hDD, 8'hEE, 8'hFF, 8'h11, 8'h22, 8'h33,
                              8'h44, 8'h55, 8'h66, 8'h77, 8'h88, 8'h99, 8'hAA, 8'hBB});
        i_interrupt = 8'd1; // Simulate interrupt
        $display("Starting Test Case 3: Interruption Error");
        simulate_frame(16);
        #200;

        // Test Case 4: Invalid Frame
        preload_payload(6, '{8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06}); // Too short
        $display("Starting Test Case 4: Invalid Frame");
        simulate_frame(6);
        #200;

        // Wait for final outputs and stop simulation
        repeat (50) @(posedge clk);
        $stop;
    end

    // Monitor Outputs
    initial begin
        $monitor("Time: %0t | MII Data: %h | Valid: %b | Preamble Err: %b | FCS Err: %b | Header Err: %b | Payload Err: %b",
                 $time, o_mii_data, o_mii_valid, preamble_error, fcs_error, header_error, mac_payload_error);
    end

    // Task to preload the payload array
    task preload_payload(input int len, input byte payload_data[]);
        for (int i = 0; i < len; i++) begin
            i_payload[i] = payload_data[i];
        end
    endtask

    // Task to simulate frame transmission
    task simulate_frame(input int payload_length);
        begin
            i_payload_length = payload_length;
            i_start = 1; // Start frame generation
            repeat (2) @(posedge clk);
            i_start = 0; // Stop frame generation
        end
    endtask

endmodule
