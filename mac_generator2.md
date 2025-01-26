
# Entity: mac_frame_generator 
- **File**: mac_generator2.sv

## Diagram
![Diagram](mac_frame_generator.svg "Diagram")
## Generics

| Generic name         | Type  | Value | Description                                    |
| -------------------- | ----- | ----- | ---------------------------------------------- |
| PAYLOAD_MAX_SIZE     |       | 1500  | Maximum payload size in bytes (should be 1514) |
| PAYLOAD_CHAR_PATTERN | [7:0] | 8'h55 | fixed char patter                              |
| PAYLOAD_LENGTH       |       | 8     | len type - payload length in bytes             |

## Ports

| Port name        | Direction | Type                                            | Description                                                             |
| ---------------- | --------- | ----------------------------------------------- | ----------------------------------------------------------------------- |
| clk              | input     |                                                 | Clock signal                                                            |
| i_rst_n          | input     |                                                 | Active-low reset                                                        |
| i_start          | input     |                                                 | Start signal to begin frame generation                                  |
| i_dest_address   | input     | [47:0]                                          | Destination MAC address                                                 |
| i_src_address    | input     | [47:0]                                          | Source MAC address                                                      |
| i_eth_type       | input     | [15:0]                                          | EtherType or Length field                                               |
| i_payload_length | input     | [15:0]                                          | ----------------------------------------------------------------------- |
| i_payload        | input     | [7:0]                                           | Payload data (preloaded)                                                |
| i_interrupt      | input     | [7:0]                                           | Set of interruptions to acomplish different behavors                    |
| o_valid          | output    |                                                 | Output valid signal                                                     |
| o_frame_out      | output    | [63:0]                                          | 64-bit output data                                                      |
| o_register       | output    | wire [(PAYLOAD_MAX_SIZE)*8 + 112+ 32 + 64 -1:0] | register output with the full data                                      |
| o_done           | output    |                                                 | Indicates frame generation is complete                                  |

## Signals

| Name                 | Type                                  | Description                    |
| -------------------- | ------------------------------------- | ------------------------------ |
| state                | reg [2:0]                             |                                |
| next_state           | reg [2:0]                             |                                |
| payload_reg          | reg [PAYLOAD_SIZE*8 - 1:0]            |                                |
| byte_counter         | reg [15:0]                            |                                |
| header_shift_reg     | logic [111:0]                         |                                |
| payload_shift_reg    | logic [63:0]                          |                                |
| payload_index        | reg [15:0]                            |                                |
| padding_counter      | reg [15:0]                            |                                |
| gen_shift_reg        | logic [(PAYLOAD_LENGTH)*8 + 112 -1:0] | register for PAYLOAD + ADDRESS |
| min_size_flag        | integer                               |                                |
| size                 | integer                               |                                |
| i                    | integer                               |                                |
| j                    | integer                               |                                |
| valid                | reg                                   |                                |
| next_valid           | reg                                   |                                |
| next_done            | reg                                   |                                |
| frame_out            | reg [63:0]                            |                                |
| next_frame_out       | reg [63:0]                            |                                |
| next_payload_index   | reg [15:0]                            |                                |
| next_byte_counter    | reg [15:0]                            |                                |
| next_padding_counter | reg [15:0]                            |                                |
| crc                  | reg [31:0]                            |                                |
| next_crc             | reg [31:0]                            |                                |
| data_xor             | reg [63:0]                            |                                |

## Constants

| Name             | Type | Value                                      | Description |
| ---------------- | ---- | ------------------------------------------ | ----------- |
| FIXED_PAYLOAD    |      | 8'd1                                       |             |
| PAYLOAD_SIZE     |      | (PAYLOAD_LENGTH < 46)? 46 : PAYLOAD_LENGTH |             |
| IDLE             |      | 3'd0                                       |             |
| SEND_PREAMBLE    |      | 3'd1                                       |             |
| SEND_HEADER      |      | 3'd2                                       |             |
| SEND_PAYLOAD     |      | 3'd3                                       |             |
| SEND_PADDING     |      | 3'd4                                       |             |
| DONE             |      | 3'd5                                       |             |
| POLYNOMIAL       |      | 32'h04C11DB7                               |             |
| PREAMBLE_SFD     |      | 64'hD555555555555555                       |             |
| MIN_PAYLOAD_SIZE |      | 46                                         |             |
| FRAME_SIZE       |      | 64                                         |             |

## Processes
- size_block: (  )
  - **Type:** always_comb
- unnamed: (  )
  - **Type:** always_comb
- unnamed: ( @(posedge clk or negedge i_rst_n) )
  - **Type:** always_ff
