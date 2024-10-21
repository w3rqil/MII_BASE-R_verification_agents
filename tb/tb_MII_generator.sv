// Code your testbench here
// or browse Examples
module tb_EthernetFrameGenerator;
// Clock and reset signals
logic clk;
logic reset;
logic start;

// Outputs from the EthernetFrameGenerator
logic [7:0] tx_data;
logic       tx_ctrl;
logic       tx_clk;

// Instantiate the EthernetFrameGenerator
EthernetFrameGenerator 
#(
    .IDLE_CYCLES(12),
    .PREAMBLE_CYCLES(7),
    .SFD_CYCLES(1),
    .DATA_CYCLES(46),
    .IDLE_CODE(8'h00),
    .PREAMBLE_CODE(8'h55),
    .SFD_CODE(8'hD5),
    .EOF_CODE(8'h00)
  
)uut (
    .clk(clk),
    .reset(reset),
    .tx_data(tx_data),
    .tx_ctrl(tx_ctrl),
    .tx_clk(tx_clk),
    .start(start)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz clock
end

// Test sequence
initial begin
    reset = 1;
    start = 0;
    #20 reset = 0;
    #20 start = 1;
    #200 start = 0;
    #1000 ;
    $display(Out: %h, tx_data);
    $finish;
end

// Monitor outputs
initial begin
    $monitor("Time: %0t, tx_data: %h, tx_ctrl: %b, tx_clk: %b", $time, tx_data, tx_ctrl, tx_clk);
end
endmodule
