`timescale 1ns / 100ps

module tb_MII_gen;
    parameter           PAYLOAD_MAX_SIZE = 1500         ; // Maximum payload size in bytes
    parameter   [7:0]   PAYLOAD_CHAR_PATTERN = 8'h55    ;
    parameter           PAYLOAD_LENGTH = 58              ;

    reg                clk         ;
    reg                i_rst_n     ;
    reg                i_mii_tx_en ;
    reg                i_valid     ;
    reg                i_mac_done  ;
    reg                i_mii_tx_er ; // 4'b0000
    reg        [63:0]  i_mii_tx_d  ;
    reg        [63:0]  o_mii_tx_d  ;
    reg        [7:0 ]  o_control   ;

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        i_rst_n = 1'b0;
        i_mii_tx_en = 1'b0;
        i_valid = 1'b0;
        i_mac_done = 1'b0;
        i_mii_tx_er = 1'b0;
        i_mii_tx_d = 64'h0;

        #1000;
        @(posedge clk);
        i_rst_n = 1'b1;

        #1000;
        @(posedge clk);
        i_mii_tx_en = 1'b1;
        i_valid = 1'b1;
        
        #1000;
        @(posedge clk);
        i_mii_tx_en = 1'b0;

        #1000;
        @(posedge clk);
        $finish;
    end

    MII_gen #(
        .PAYLOAD_MAX_SIZE       (PAYLOAD_MAX_SIZE       ),
        .PAYLOAD_CHAR_PATTERN   (PAYLOAD_CHAR_PATTERN   ),
        .PAYLOAD_LENGTH         (PAYLOAD_LENGTH         )
    ) dut (
        .clk                    (clk                    ),
        .i_rst_n                (i_rst_n                ),
        .i_mii_tx_en            (i_mii_tx_en            ),
        .i_valid                (i_valid                ),
        .i_mac_done             (i_mac_done             ),
        .i_mii_tx_er            (i_mii_tx_er            ),
        .i_mii_tx_d             (i_mii_tx_d             ),
        .o_mii_tx_d             (o_mii_tx_d             ),
        .o_control              (o_control              )
    );

endmodule