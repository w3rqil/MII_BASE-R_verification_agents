// Change the MII input
i_enable        = 1'b0                  ;
// Set TXC and TXD as Error
i_txc           = 8'hFF                 ;
i_txd           = 64'hFEFEFEFEFEFEFEFE  ;
i_valid         = 1'b0                  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;
// Set TXD as Idle
i_txd           = 64'h0707070707070707  ;
i_valid         = 1'b0                  ;
repeat(15) @(posedge clk)               ;
i_valid         = 1'b1                  ;

#600                                    ;
@(posedge clk)                          ;