`timescale 1ns / 1ps

module tb_mac_frame_generator();

    // Parameters
    localparam CLK_PERIOD = 10; // Clock period in nanoseconds
    localparam PAYLOAD_MAX_SIZE = 1500;
    localparam [7:0] PAYLOAD_CHAR_PATTERN = 8'h55;

    // DUT Inputs
    logic                                   clk;
    logic                                   i_rst_n;
    logic                                   i_prbs_rst_n;
    logic                                   i_start;
    logic [47:0]                            i_dest_address;
    logic [47:0]                            i_src_address;
    logic [15:0]                            i_payload_length;
    logic [7:0]                             i_payload [PAYLOAD_MAX_SIZE-1:0];
    logic [7:0]                             i_prbs_seed;
    logic [7:0]                             i_mode;
    logic [(PAYLOAD_MAX_SIZE + 26)*8 -1:0]  o_register;
    logic                                   o_done;

    // Instantiate the DUT (Device Under Test)
    mac_frame_generator #(
        .PAYLOAD_MAX_SIZE(PAYLOAD_MAX_SIZE),
        .PAYLOAD_CHAR_PATTERN(PAYLOAD_CHAR_PATTERN)
    ) mac_gen_inst (
        .clk(clk),
        .i_rst_n(i_rst_n),
        .i_prbs_rst_n(i_prbs_rst_n),
        .i_start(i_start),
        .i_dest_address(i_dest_address),
        .i_src_address(i_src_address),
        .i_payload_length(i_payload_length),
        .i_payload(i_payload),
        .i_prbs_seed(i_prbs_seed),
        .i_mode(i_mode),
        .o_register(o_register),
        .o_done(o_done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Testbench procedure
    initial begin
        // Initialize inputs
        i_rst_n = 1'b0;
        i_prbs_rst_n = 1'b0;
        i_start = 1'b0;
        i_dest_address = 48'hFF_FF_FF_FF_FF_FF; // Broadcast MAC address
        i_src_address = 48'h11_22_33_44_55_66;  // Example source MAC address
        i_payload_length = '0;
        i_prbs_seed = 8'hFF;
        i_mode = 8'h00;

        // Reset sequence
        #20;
        @(posedge clk);
        i_rst_n = 1'b1;
        i_prbs_rst_n = 1'b1;
        #20;
        @(posedge clk);
        
        // Test Case 1: PRBS8 Frame Generation
        i_mode = 8'd3;
        simulate_frame(64);

        @(posedge o_done);
        $display("MAC REGISTER: %h", o_register);
        simulate_frame(128);

        @(posedge o_done);
        $display("MAC REGISTER: %h", o_register);

        i_prbs_rst_n = 1'b0;
        #20;
        @(posedge clk);
        i_prbs_rst_n = 1'b1;
        simulate_frame(8);

        @(posedge o_done);
        $display("MAC REGISTER: %h", o_register);
        
        // End of simulation
        $finish;
    end

    // Task to preload the payload array
    task preload_payload(input int len, input byte payload_data[]);
        begin
            for (int i = 0; i < PAYLOAD_MAX_SIZE; i=i+1) begin
                if(i < len) begin
                    i_payload[i] = payload_data[i];
                    // $display("I: %h", i);
                end
                else begin
                    i_payload[i] = 8'h00;
                end
            end
        end
    endtask

    // Task to simulate frame transmission
    task simulate_frame(input int payload_length);
        begin
            i_payload_length = payload_length;
            i_start = 1; // Start frame generation
            repeat (1) @(posedge clk);
            i_start = 0; // Stop frame generation
        end
    endtask

endmodule
