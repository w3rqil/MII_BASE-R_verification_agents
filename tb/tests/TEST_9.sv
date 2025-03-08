// Corrupt header
i_corrupt_header    = 1'b1                  ;
i_enable            = 1'b0                  ;
// Flujo constante de Idles
i_txd               = 64'h0707070707070707  ;
i_txc               = 8'hFF                 ;

#60                                         ;
@(posedge clk)                              ;
i_valid         = 1'b1                      ;

repeat(35) @(posedge clk)                   ;