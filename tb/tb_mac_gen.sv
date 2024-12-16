`timescale 1ns / 1ps

module tb_mac_frame_generator();

    // Parameters
    localparam CLK_PERIOD = 10; // Clock period in nanoseconds
    localparam PAYLOAD_MAX_SIZE = 1500;

    // DUT Inputs
    logic               clk;
    logic               rst_n;
    logic               start;
    logic [47:0]        dest_address;
    logic [47:0]        src_address;
    logic [15:0]        eth_type;
    logic [15:0]        payload_length;
    logic [7:0]         payload[PAYLOAD_MAX_SIZE-1:0]; // Payload array

    // DUT Outputs
    logic               valid;
    logic [63:0]        frame_out;
    logic               done;
    logic [7:0] interrupt;
    logic [(PAYLOAD_MAX_SIZE)*8 + 112+ 32 + 64 -1:0]  register;

    // Instantiate the DUT (Device Under Test)
    mac_frame_generator #(
        .PAYLOAD_MAX_SIZE(PAYLOAD_MAX_SIZE),
        .PAYLOAD_CHAR_PATTERN(8'h55),
        .PAYLOAD_LENGTH(46)
    ) DUT (
        .clk(clk),
        .i_rst_n(rst_n),
        .i_start(start),
        .i_dest_address(dest_address),
        .i_src_address(src_address),
        .i_eth_type(eth_type),
        .i_payload_length(payload_length),
        .i_payload(payload),
        .i_interrupt(interrupt),
        .o_valid(valid),
        .o_frame_out(frame_out),
        .o_register(register),
        .o_done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Testbench procedure
    initial begin
        // Initialize inputs
        rst_n = 0;
        start = 0;
        dest_address = 48'hFF_FF_FF_FF_FF_FF; // Broadcast MAC address
        src_address = 48'h11_22_33_44_55_66;  // Example source MAC address
        eth_type = 16'h002E;                  // 46 bytes
        payload_length = 0;
        interrupt = 8'h00;
        for (int i = 0; i < PAYLOAD_MAX_SIZE; i++) begin
            payload[i] = 8'h00; // Initialize all payload bytes to zero
        end

        // Reset sequence
        #20 rst_n = 1;

        // Test Case 1: Small payload
        // @(posedge clk);
        // preload_payload(8, '{8'hBB, 8'hAA, 8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'h12, 8'h34}); // Preload payload
        // payload_length = 8; // Payload length = 6 bytes
        // start = 1; // Trigger frame generation
        // repeat (50)@(posedge clk);
        // start = 0; // Deassert start

        // wait(done); // Wait for the frame generation to complete
        // $display("Frame generation (Test Case 1) complete!");

        // Test Case 2: Minimum Ethernet payload size (46 bytes)
        @(posedge clk);
        //preload_payload(46, '{default: 8'hAA}); // Preload payload with 46 bytes of 0xAA
        for (int i = 0; i < 46; i++) begin
            payload[i] = 8'hAA;
        end
        payload_length = 46;
        start = 1;
        @(posedge clk);
        start = 0;
//      
        repeat (1) @(posedge clk);
        $display("output: %h", register);
        wait(done);
        $display("Frame generation (Test Case 2) complete!");

        //// Test Case 3: Maximum payload size (1500 bytes)
        //@(posedge clk);
        //preload_payload(1500, '{default: 8'hFF}); // Preload payload with 1500 bytes of 0xFF
        //payload_length = 1500;
        //start = 1;
        //@(posedge clk);
        //start = 0;
//
        //wait(done);

        $display("Frame generation (Test Case 3) complete!");
        
        // End of simulation
        $stop;
    end

    // Task to preload the payload array
    task preload_payload(input int len, input byte payload_data[]);
        for (int i = 0; i < len; i++) begin
            payload[i] = payload_data[i];
        end
    endtask

    // Monitor the frame output
    always @(posedge clk) begin
        if (valid) begin
            $display("Time: %t | Frame Out: %h", $time, frame_out);
        end
    end

endmodule
