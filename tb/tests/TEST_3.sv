// Set the data sel 0
i_data_sel      = 4'b0000   ;
i_valid         = 1'b0      ;
repeat(15) @(posedge clk)   ;
i_valid         = 1'b1      ;

#600                        ;
@(posedge clk)              ;