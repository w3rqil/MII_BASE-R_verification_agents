// Change the MII input
i_enable        = 1'b0                      ;
i_valid         = 1'b0                      ;
repeat(2) begin
    @(negedge clk)                          ;
    i_txc           = 8'h00                 ;
    i_txd           = 64'hABABABABABABABAB  ;
    @(negedge clk)                          ;
    i_txc           = 8'hFE                 ;
    i_txd           = 64'h434343434343FD55  ;
    @(negedge clk)                          ;
    i_txc           = 8'h00                 ;
    i_txd           = 64'h7777777777777777  ;
    @(negedge clk)                          ;
    i_txc           = 8'hF0                 ;
    i_txd           = 64'h30303030FD060606  ;
end

@(posedge clk)                              ;
i_valid         = 1'b1                      ;

repeat(100) begin
    @(negedge clk)                          ;
    i_txc           = 8'h00                 ;
    i_txd           = 64'hABABABABABABABAB  ;
    @(negedge clk)                          ;
    i_txc           = 8'hFE                 ;
    i_txd           = 64'h434343434343FD55  ;
    @(negedge clk)                          ;
    i_txc           = 8'h00                 ;
    i_txd           = 64'h7777777777777777  ;
    @(negedge clk)                          ;
    i_txc           = 8'hF0                 ;
    i_txd           = 64'h30303030FD060606  ;
end