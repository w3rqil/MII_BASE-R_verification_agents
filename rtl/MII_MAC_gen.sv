module mac_mii_top #(
    parameter PAYLOAD_MAX_SIZE = 1500,
    parameter [7:0] PAYLOAD_CHAR_PATTERN = 8'h55,
    parameter PAYLOAD_LENGTH = 8
)(
    input wire clk,
    input wire i_rst_n,
    input wire i_start,               // Start frame generation
    input wire [47:0] i_dest_address, // Destination MAC address
    input wire [47:0] i_src_address,  // Source MAC address
    input wire [15:0] i_eth_type,     // EtherType
    input wire [15:0] i_payload_length,
    input wire [7:0] i_payload[PAYLOAD_LENGTH-1:0],
    input wire [7:0] i_interrupt,

    output wire        o_txValid,
    output wire [63:0] o_mii_data,     // MII data output (8-bit)
    output wire [7:0] o_mii_valid     // MII ctrl signal
);

    // Signals to connect mac_frame_generator and MII_gen
    wire        mac_valid;
    wire [63:0] mac_frame_out;
    wire        mac_done;
    
    wire [(PAYLOAD_MAX_SIZE)*8 + 112+ 32 + 64 -1:0] register;

    wire [63:0] mii_tx_data;
    wire [7:0]  mii_control;

    // Instantiate mac_frame_generator
    mac_frame_generator #(
        .PAYLOAD_MAX_SIZE(PAYLOAD_MAX_SIZE),
        .PAYLOAD_CHAR_PATTERN(PAYLOAD_CHAR_PATTERN),
        .PAYLOAD_LENGTH(PAYLOAD_LENGTH)
    ) mac_gen_inst (
        .clk(clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        .i_dest_address(i_dest_address),
        .i_src_address(i_src_address),
        .i_eth_type(i_eth_type),
        .i_payload_length(i_payload_length),
        .i_payload(i_payload),
        .i_interrupt(i_interrupt),
        .o_valid(mac_valid),
        .o_frame_out(mac_frame_out),
        .o_register(register),
        .o_done(mac_done)
    );

    // Instantiate MII_gen
    MII_gen #(
        .PAYLOAD_MAX_SIZE(PAYLOAD_MAX_SIZE),
        .PAYLOAD_CHAR_PATTERN(PAYLOAD_CHAR_PATTERN),
        .PAYLOAD_LENGTH(PAYLOAD_LENGTH)
    ) mii_gen_inst (
        .clk(clk),
        .i_rst_n(i_rst_n),
        .i_mii_tx_en(mac_valid),       // Enable MII when MAC frame is valid
        .i_valid(mac_valid),
        .i_mac_done(mac_done),
        .i_mii_tx_er(1'b0),            // No transmission error in this simulation
        .i_mii_tx_d(mac_frame_out),    // Frame data from MAC
        .i_register(register),
        .i_interrupt(i_interrupt),
        .i_payload_length(i_payload_length),
        .o_txValid (o_txValid),
        .o_mii_tx_d(mii_tx_data),      // Unused in this version, processed internally
        .o_control(mii_control)        // Control signal from MII_gen
    );

    // Outputs from MII_gen
    assign o_mii_data = mii_tx_data;  // Output 8 bits at a time
    assign o_mii_valid = mii_control;   // Output valid flag

endmodule
