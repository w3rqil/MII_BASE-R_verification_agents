i_enable    = 1'b1          ;
i_random    = 1'b1          ;
i_valid     = 1'b0          ;
repeat(15) @(posedge clk)   ;
i_valid     = 1'b1          ;

#600                        ;
@(posedge clk)              ;