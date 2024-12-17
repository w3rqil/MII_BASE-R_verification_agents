`timescale 1ns/1ps

module tb_mac_mii_top;

    // Parameters
    localparam PAYLOAD_LENGTH = 50;
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

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Instantiate DUT
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
        
        // // Initialize payload data
        // i_payload[0] = 8'hDE;
        // i_payload[1] = 8'hAD;
        // i_payload[2] = 8'hBE;
        // i_payload[3] = 8'hEF;
        // i_payload[4] = 8'hCA;
        // i_payload[5] = 8'hFE;
        // i_payload[6] = 8'hBA;
        // i_payload[7] = 8'hBE;

        for (int i = 0; i < 64; i++) begin
            i_payload[i] = 8'h00; // Initialize all payload bytes to zero
        end

        // Reset the system
        #20;
        i_rst_n = 1;

        preload_payload(50, '{8'hBB, 8'hAA, 8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'h12, 8'h34, 8'h01, 8'h02,
                              8'h03, 8'h04, 8'h05, 8'h06, 8'h07, 8'h08, 8'h09, 8'h10, 8'h11, 8'h12,
                              8'h13, 8'hA4, 8'h35, 8'h26, 8'hF7, 8'hA8, 8'h19, 8'h1A, 8'h41, 8'h62,
                              8'h23, 8'hB4, 8'h25, 8'h26, 8'hF7, 8'hC8, 8'h29, 8'h1B, 8'h51, 8'h72,
                              8'h33, 8'hC4, 8'h15, 8'h26, 8'hD7, 8'hD8, 8'h39, 8'h2B, 8'h52, 8'h77}); // Preload payload
        i_payload_length = 8; // Payload length = 6 bytes
        i_start = 1; // Trigger frame generation
        repeat (50)@(posedge clk);
        i_start = 0; // Deassert start


        // // Start frame generation
        // #10;
        // i_start = 1;
        // #CLK_PERIOD;
        // i_start = 0;

        // Wait for frame to complete
        #200;

        // End simulation
        $stop;
    end

    // Monitor signals
    initial begin
        $monitor("Time: %0t | MII Data: %h | MII Valid: %b", $time, o_mii_data, o_mii_valid);
    end




    // Task to preload the payload array
task preload_payload(input int len, input byte payload_data[]);
for (int i = 0; i < len; i++) begin
    i_payload[i] = payload_data[i];
end
endtask


endmodule


