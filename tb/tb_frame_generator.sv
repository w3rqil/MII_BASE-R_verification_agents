`timescale 1ns/100ps

module EthernetFrameGenerator_tb;

    // Parameters
    parameter DATA_WIDTH = 64;
    parameter CTRL_WIDTH = DATA_WIDTH / 8;

    // Signals
    logic clk;
    logic i_rst;
    logic i_start;
    logic [7:0] i_interrupt;
    logic [DATA_WIDTH-1:0] o_tx_data;
    logic [CTRL_WIDTH-1:0] o_tx_ctrl;

    // Instantiate the EthernetFrameGenerator module
    EthernetFrameGenerator #(
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH)
    ) dut (
        .clk(clk),
        .i_rst(i_rst),
        .i_start(i_start),
        .i_interrupt(i_interrupt),
        .o_tx_data(o_tx_data),
        .o_tx_ctrl(o_tx_ctrl)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Test procedure
    initial begin
        // Initialize signals
        i_rst = 1;
        i_start = 0;
        i_interrupt = 8'h00;

        // Wait for a few clock cycles
        #20;

        // Release reset
        i_rst = 0;

        // Wait for a few clock cycles
        #20;

        // Start frame generation
        i_start = 1;

        // Wait for frame generation to complete
        #1000;

        // Interrupt the frame generation
        //i_interrupt = 8'h02; // Stop data transmission

        // Wait for a few clock cycles
        #200;

        // Stop the simulation
        $stop;
    end

    // Monitor output
    initial begin
        $monitor("Time=%0t | o_tx_data=%h | o_tx_ctrl=%b", $time, o_tx_data, o_tx_ctrl);
    end

endmodule
