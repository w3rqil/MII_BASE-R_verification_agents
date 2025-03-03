module mac_mii_top #(
    parameter PAYLOAD_MAX_SIZE = 1500,
    parameter [7:0] PAYLOAD_CHAR_PATTERN = 8'h55
)(
    input wire         clk                                      ,
    input wire         i_rst_n                                  ,
    input wire         i_start                                  , // Start frame generation
    input wire [47:0]  i_dest_address                           , // Destination MAC address
    input wire [47:0]  i_src_address                            , // Source MAC address
    input wire [15:0]  i_payload_length                         ,
    input wire [7:0]   i_payload         [PAYLOAD_MAX_SIZE-1:0]   ,
    input wire [7:0]   i_mode                              ,

    output wire        o_txValid                                ,
    output wire [63:0] o_mii_data                               , // MII data output (8-bit)
    output wire [7:0]  o_mii_ctrl                                // MII ctrl signal
);

    // Signals to connect mac_frame_generator and MII_gen
    wire        mac_done        ;
    
    wire [(PAYLOAD_MAX_SIZE)*8 + 112+ 32 + 64 -1:0] register;

    wire [63:0] mii_tx_data;
    wire [7:0]  mii_tx_ctrl;

    // Instantiate mac_frame_generator
    mac_frame_generator #(
        .PAYLOAD_MAX_SIZE(PAYLOAD_MAX_SIZE),
        .PAYLOAD_CHAR_PATTERN(PAYLOAD_CHAR_PATTERN)
    ) mac_gen_inst (
        .clk(clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        .i_dest_address(i_dest_address),
        .i_src_address(i_src_address),
        .i_payload_length(i_payload_length),
        .i_payload(i_payload),
        .i_mode(i_mode),
        .o_register(register),
        .o_done(mac_done)
    );

    // Instantiate MII_gen
    MII_gen #(
        .PAYLOAD_MAX_SIZE(PAYLOAD_MAX_SIZE)
    ) mii_gen_inst (
        .clk(clk),
        .i_rst_n(i_rst_n),
        .i_register(register),
        .i_mode(i_mode),
        .i_payload_length(i_payload_length),
        .o_txValid (o_txValid),
        .o_mii_tx_d(mii_tx_data),      // Unused in this version, processed internally
        .o_mii_tx_c(mii_tx_ctrl)        // Control signal from MII_gen
    );

    // Outputs from MII_gen
    assign o_mii_data  = mii_tx_data;  // Output data
    assign o_mii_ctrl = mii_tx_ctrl;   // Output control

endmodule
