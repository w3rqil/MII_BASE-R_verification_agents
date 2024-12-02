`timescale 1ns/100ps

module top
(
    input  logic clk,             // System clock
    input  logic rst,             // Asynchronous reset
    input  logic start,           // Signal to start frame generation
    input  logic fixed_flag,      // Fixed or input values for MAC Generator
    input  logic [7:0] interrupt, // Interrupt scenarios for MAC Generator

    // Input data for MAC Generator
    input  logic [41:0] dst_addr,
    input  logic [41:0] src_addr,
    input  logic [15:0] frame_type,
    input  logic [15:0] opcode,

    // Outputs from MII Checker
    output logic payload_error,
    output logic intergap_error,
    output logic other_error
);

    localparam DATA_WIDTH = 64;
    localparam CTRL_WIDTH = DATA_WIDTH / 8;

    // MAC Generator Parameters
    localparam IDLE_CYCLES = 12;
    localparam PREAMBLE_CYCLES = 6;
    localparam DST_ADDR_CYCLES = 6;
    localparam SRC_ADDR_CYCLES = 6;
    localparam LEN_TYP_CYCLES = 2;
    localparam DATA_CYCLES = 10;
    localparam FCS_CYCLES = 4;

    localparam [7:0] IDLE_CODE = 8'h07;
    localparam [7:0] START_CODE = 8'hFB;
    localparam [7:0] PREAMBLE_CODE = 8'h55;
    localparam [7:0] SFD_CODE = 8'hD5;

    localparam [47:0] DST_ADDR_CODE = 48'h0180C2000001;
    localparam [47:0] SRC_ADDR_CODE = 48'h5A5152535455;
    localparam [15:0] LEN_TYP_CODE = 16'h8808;
    localparam [7:0] FCS_CODE = 8'hC0;
    localparam [7:0] TERMINATE_CODE = 8'hFD;

    // MII Checker Parameters
    localparam [7:0] TERM_CODE = 8'hFD;

    // Internal signals to connect mac_generator and mii_checker
    logic [DATA_WIDTH-1:0] tx_data;  // Frame data from MAC Generator
    logic [CTRL_WIDTH-1:0] tx_ctrl; // Control signal from MAC Generator

    // Instantiate mac_generator
    mac_generator #(
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .IDLE_CYCLES(IDLE_CYCLES),
        .PREAMBLE_CYCLES(PREAMBLE_CYCLES),
        .DST_ADDR_CYCLES(DST_ADDR_CYCLES),
        .SRC_ADDR_CYCLES(SRC_ADDR_CYCLES),
        .LEN_TYP_CYCLES(LEN_TYP_CYCLES),
        .DATA_CYCLES(DATA_CYCLES),
        .FCS_CYCLES(FCS_CYCLES),
        .IDLE_CODE(IDLE_CODE),
        .START_CODE(START_CODE),
        .PREAMBLE_CODE(PREAMBLE_CODE),
        .SFD_CODE(SFD_CODE),
        .DST_ADDR_CODE(DST_ADDR_CODE),
        .SRC_ADDR_CODE(SRC_ADDR_CODE),
        .LEN_TYP_CODE(LEN_TYP_CODE),
        .FCS_CODE(FCS_CODE),
        .TERMINATE_CODE(TERMINATE_CODE)
    ) mac_gen_inst (
        .clk(clk),
        .i_rst(rst),
        .i_start(start),
//        .i_fixed_flag(fixed_flag),
        .i_interrupt(interrupt),
        // .i_dst_addr(dst_addr),
        // .i_src_addr(src_addr),
        // .i_type(frame_type),
        // .i_opcode(opcode),
        .o_tx_data(tx_data),
        .o_tx_ctrl(tx_ctrl)
    );

    // Instantiate mii_checker
    mii_checker #(
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .IDLE_CODE(IDLE_CODE),
        .START_CODE(START_CODE),
        .TERM_CODE(TERM_CODE)
    ) mii_chk_inst (
        .clk(clk),
        .i_rst(rst),
        .i_tx_data(tx_data),
        .i_tx_ctrl(tx_ctrl),
        .payload_error(payload_error),
        .intergap_error(intergap_error),
        .other_error(other_error)
    );

endmodule
