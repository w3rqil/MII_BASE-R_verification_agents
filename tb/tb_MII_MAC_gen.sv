`timescale 1ns/1ps

module tb_mac_mii_top;

    // Parameters
    localparam PAYLOAD_LENGTH = 8;
    localparam CLK_PERIOD = 10;  // 100 MHz clock

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

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Instantiate DUT
    mac_mii_top #(
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

    // Testbench logic
    initial begin
        // Initialize inputs
        i_rst_n = 0;
        i_start = 0;
        i_dest_address = 48'hFFFFFFFFFFFF;  // Broadcast address
        i_src_address = 48'h123456789ABC;   // Example source address
        i_eth_type = 16'h0800;              // IP protocol
        i_payload_length = PAYLOAD_LENGTH;
        i_interrupt = 8'd0;                // No interrupt
        
        // Initialize payload data
        i_payload[0] = 8'hDE;
        i_payload[1] = 8'hAD;
        i_payload[2] = 8'hBE;
        i_payload[3] = 8'hEF;
        i_payload[4] = 8'hCA;
        i_payload[5] = 8'hFE;
        i_payload[6] = 8'hBA;
        i_payload[7] = 8'hBE;

        // Reset the system
        #20;
        i_rst_n = 1;

        // Start frame generation
        #10;
        i_start = 1;
        #CLK_PERIOD;
        i_start = 0;

        // Wait for frame to complete
        #200;

        // End simulation
        $stop;
    end

    // Monitor signals
    initial begin
        $monitor("Time: %0t | MII Data: %h | MII Valid: %b", $time, o_mii_data, o_mii_valid);
    end

endmodule
