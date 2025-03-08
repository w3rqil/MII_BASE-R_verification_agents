repeat(15) @(posedge clk)   ;
i_valid         = 1'b1      ;
#600                        ;
@(posedge clk)              ;

// Set the data sel 0
i_valid         = 1'b0      ;
i_data_sel      = 4'b0001   ;
repeat(15) @(posedge clk)   ;
i_valid         = 1'b1      ;

#600                        ;
@(posedge clk)              ;
i_valid         = 1'b0      ;
i_data_sel      = 4'b0010   ;
repeat(15) @(posedge clk)   ;
i_valid         = 1'b1      ;

#600                        ;
@(posedge clk)              ;
i_valid         = 1'b0      ;
i_data_sel      = 4'b0011   ;
repeat(15) @(posedge clk)   ;
i_valid         = 1'b1      ;

#600                        ;
@(posedge clk)              ;
i_valid         = 1'b0      ;
i_data_sel      = 4'b0100   ;
repeat(15) @(posedge clk)   ;
i_valid         = 1'b1      ;

#600                        ;
@(posedge clk)              ;
i_valid         = 1'b0      ;
i_data_sel      = 4'b1000   ;
repeat(15) @(posedge clk)   ;
i_valid         = 1'b1      ;

#600                        ;
@(posedge clk)              ;
i_valid         = 1'b0      ;
i_data_sel      = 4'b1111   ;
repeat(15) @(posedge clk)   ;
i_valid         = 1'b1      ;

#600                        ;
@(posedge clk)              ;

// Change the MII input
i_valid         = 1'b0                  ;
i_enable        = 1'b0                  ;
i_txc           = 8'h00                 ;
i_txd           = 64'hFFFFFFFFFFFFFFFF  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;
i_valid         = 1'b0                  ;
i_txd           = 64'hAAAAAAAAAAAAAAAA  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;
i_valid         = 1'b0                  ;
i_txc           = 8'hFF                 ;
i_txd           = 64'h07070707070707FD  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;
i_valid         = 1'b0                  ;
i_txc           = 8'h01                 ;
i_txd           = 64'hAAAAAAAAAAAAAAFB  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;
i_valid         = 1'b0                  ;
i_txc           = 8'h00                 ;
i_txd           = 64'hAAAAAAAAAAAAAAAA  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;
i_valid         = 1'b0                  ;
i_txc           = 8'hFC                 ;
i_txd           = 64'h0707070707FDAAAA  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;
i_valid         = 1'b0                  ;
i_txc           = 8'hFF                 ;
i_txd           = 64'h0707070707070707  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;
i_valid         = 1'b0                  ;
i_txc           = 8'hFF                 ;
i_txd           = 64'hFEFEFEFEFEFEFEFE  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;