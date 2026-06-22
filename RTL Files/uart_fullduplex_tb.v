`timescale 1ns / 1ps

module uart_fullduplex_tb;
reg clkA, clkB, rstA, rstB, selA, selB, enA, enB;
reg [2:0] offsetA, offsetB;
reg [31:0] d_inA, d_inB;
wire readyA, readyB;
wire [31:0] d_outA, d_outB;
wire com1, com2;

parameter ctrl=3'b000 , status=3'b001 , txdata=3'b010 , rxdata=3'b011 , baud=3'b100 ;

UART_top uart_A (clkA, rstA, offsetA, d_inA, d_outA, selA, enA, com1, com2,readyA);
UART_top uart_B (clkB, rstB, offsetB, d_inB, d_outB, selB, enB, com2, com1,readyB);

task apply_rstA;
    begin
        rstA = 1;
        @(posedge clkA); #1;
        rstA = 0;
    end
endtask

task apply_rstB;
    begin
        rstB = 1;
        @(posedge clkB); #1;
        rstB = 0;
    end
endtask

task wr_A;
    input [31:0] data;
    input [2:0] offset;
    begin
        selA=1; enA=1;
        d_inA = data;
        offsetA = offset;
        @(posedge clkA); #1;
        selA=0; enA=0;
        offsetA = 0;
        d_inA = 0;
    end
endtask

task wr_B;
    input [31:0] data;
    input [2:0] offset;
    begin
        selB=1; enB=1;
        d_inB = data;
        offsetB = offset;
        @(posedge clkB); #1;
        selB=0; enB=0;
        offsetB = 0;
        d_inB = 0;
    end
endtask

task rd_A;
    input [2:0] offset;
    begin
        selA=1 ; enA=0;
        offsetA = offset;
        @(posedge clkA); #1;
        selA=0 ; enA=0;
        offsetA = 0;
    end    
endtask

task rd_B;
    input [2:0] offset;
    begin
        selB=1 ; enB=0;
        offsetB = offset;
        @(posedge clkB); #1;
        selB=0 ; enB=0;
        offsetB = 0;
    end    
endtask

always #5 clkA = ~clkA;     //100MHz
always #10 clkB = ~clkB;    // 50MHz 

initial begin
    clkA = 0;
    apply_rstA;
    
    wr_A(32'd10416,baud);    
    wr_A(32'd7,ctrl);
    
    wr_A(32'd170,txdata);
    
    @(posedge uart_A.rx_val);
    rd_A(rxdata); #10;
    wr_A(32'd100,txdata);
    
    @(posedge uart_A.rx_val);
    rd_A(rxdata); #10;
    
end

initial begin 
    clkB = 0;
    apply_rstB;
    
    wr_B(32'd5208,baud);
    wr_B(32'd7,ctrl);
    
    wr_B(32'd85,txdata);
    
    @(posedge uart_B.rx_val);
    rd_B(rxdata);
    wr_B(32'd127,txdata);
    
    @(posedge uart_B.rx_val);
    rd_B(rxdata); #10;
end

endmodule
