`timescale 1ns/100ps

module MII_generator_tb;
    /*
    *---------CYCLES---------
    */
    parameter int IDLE_CYCLES = 12          ;   //! Idle length
    parameter int PREAMBLE_CYCLES = 7       ;   //! Preamble length
    parameter int DST_ADDR_CYCLES = 6       ;   
    parameter int SRC_ADDR_CYCLES = 6       ;
    parameter int LEN_TYP_CYCLES = 2        ;
    parameter int DATA_CYCLES = 46          ;   //! Data length
    parameter int FCS_CYCLES = 4            ;
    /*
    *---------CODES---------
    */
    parameter [7:0] IDLE_CODE = 8'h07       ;
    parameter [7:0] START_CODE = 8'hFB      ;
    parameter [7:0] PREAMBLE_CODE = 8'h55   ;
    parameter [7:0] SFD_CODE = 8'hD5        ;
    parameter [7:0] DST_ADDR_CODE = 8'h01   ;
    parameter [7:0] SRC_ADDR_CODE = 8'h02   ;
    parameter [7:0] LEN_TYP_CODE = 8'h03    ;
    parameter [7:0] FCS_CODE = 8'h04        ;
    parameter [7:0] TERMINATE_CODE = 8'hFD  ;        

    // Inputs
    logic       clk;          //! Clock input
    logic       i_rst;        //! Asynchronous reset
    logic [7:0] i_interrupt;  //! Interrupt the frame into different scenarios
    logic       i_start;      //! Signal to start frame transmission

    // Outputs from the EthernetFrameGenerator
    logic [7:0] o_tx_data;  //! Transmitted data (8 bits per cycle)
    logic [7:0] o_tx_ctrl;  //! Transmit control signal (indicates valid data)

    // Instantiate the EthernetFrameGenerator
    MII_generator #(
        .IDLE_CYCLES     (IDLE_CYCLES)     ,
        .PREAMBLE_CYCLES (PREAMBLE_CYCLES) ,
        .DST_ADDR_CYCLES (DST_ADDR_CYCLES) ,
        .SRC_ADDR_CYCLES (SRC_ADDR_CYCLES) ,
        .LEN_TYP_CYCLES  (LEN_TYP_CYCLES)  ,
        .DATA_CYCLES     (DATA_CYCLES)     ,
        .FCS_CYCLES      (FCS_CYCLES)      ,
        .IDLE_CODE       (IDLE_CODE)       ,
        .START_CODE      (START_CODE)      ,
        .PREAMBLE_CODE   (PREAMBLE_CODE)   ,
        .SFD_CODE        (SFD_CODE)        ,
        .DST_ADDR_CODE   (DST_ADDR_CODE)   ,
        .SRC_ADDR_CODE   (SRC_ADDR_CODE)   ,
        .LEN_TYP_CODE    (LEN_TYP_CODE)    ,
        .FCS_CODE        (FCS_CODE)        ,
        .TERMINATE_CODE  (TERMINATE_CODE)
    
    ) dut (
        .clk             (clk)             ,
        .i_rst           (i_rst)           ,
        .i_start         (i_start)         ,
        .i_interrupt     (i_interrupt)     ,
        .o_tx_data       (o_tx_data)       ,
        .o_tx_ctrl       (o_tx_ctrl)
    );

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // Test sequence
    initial begin
        // Generate .vcd
        $dumpfile("dump.vcd");
        $dumpvars;

        // Monitor outputs
        $monitor("Time: %0t, o_tx_data: %h, o_tx_ctrl: %b",
                 $time, o_tx_data, o_tx_ctrl);
                 
        i_rst       = 1;
        clk         = 0;
        i_start     = 0;
        i_interrupt = 0;

        #200;
        @(posedge clk);
        i_rst = 0;

        #20;
        @(posedge clk);
        i_start = 1;
        @(posedge clk);
        i_start = 0;

        #2000;
        $finish;
    end

endmodule