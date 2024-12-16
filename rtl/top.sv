module top
(
    input wire clk,
    input wire i_start,
    input wire i_rst_n
);


locaparam DATA_WIDTH = 8;


localparam CTRL_WIDTH = 8;
logic [DATA_WIDTH-1:0] o_tx_data;
logic [CTRL_WIDTH-1:0] o_tx_ctrl;
logic other_error, payload_error, intergap_error;

// Instantiate the generator module


// Instantiate the checker module
mii_checker #(
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH)
) uut (
    .clk(clk),
    .i_rst(!i_rst_n),
    .i_tx_data(o_mii_data),
    .i_tx_ctrl(o_tx_ctrl),
    .payload_error(payload_error),
    .intergap_error(intergap_error),
    .other_error(other_error),
    .o_captured_data(buffferMII2MAC)//buffer
);

///----------------------------------



mac_checker #
(
    .DATA_WIDTH      (DATA_WIDTH),
    .CTRL_WIDTH      (CTRL_WIDTH),
    .FCS_WIDTH       (FCS_WIDTH ), 

    .IDLE_CODE       (8'h07),
    .START_CODE      (8'hfb),
    .TERM_CODE       (8'hfd), 
    .PREAMBLE_CODE   (8'h55),
    .SFD_CODE        (8'hd5),
    .DST_ADDR_CODE   (),
    .SRC_ADDR_CODE   ()
)checkunit
(
    .clk(clk),
    .i_rst(~i_rst_n),
    .i_rx_data(buffferMII2MAC),
    //.i_rx_ctrl(),
    .i_rx_fcs(),
    .preamble_error(),
    .fcs_error(),   
    .header_error(),
    .payload_error(),
    .o_data_valid()
);

//-----------------------------------------------

// fcs_crc  fcs_unit(
//     .clk(clk),                  // Señal de reloj
//     .rst_n(i_rst_n),                // Señal de reset activo en bajo
//     .data_valid(),           // Señal para habilitar la operación de cálculo de CRC
//     .data_in(),      // Entrada de datos de 32 bits
//     .crc_out      // Salida del CRC-32
// );

// ----------------------------------------------





    // Parameters
localparam PAYLOAD_LENGTH = 1000;
localparam CLK_PERIOD = 10;  // 100 MHz clock
localparam PAYLOAD_MAX_SIZE = 64;

// Signals


reg [47:0] i_dest_address;
reg [47:0] i_src_address;
reg [15:0] i_eth_type;
reg [15:0] i_payload_length;
reg [7:0] i_payload[PAYLOAD_LENGTH-1:0];
reg [7:0] i_interrupt;

wire [63:0] o_mii_data;
wire [7:0] o_mii_valid;

// Clock generation

        // Initialize inputs


i_dest_address = 48'hFFFFFFFFFFFF;  // Broadcast address
i_src_address = 48'h123456789ABC;   // Example source address
i_eth_type = 16'h0800;              // IP protocol
i_payload_length = PAYLOAD_LENGTH;
i_interrupt = 8'd0;                // No interrupt
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


endmodule
