`timescale 1ns / 1ps

module baud_gen(clk, rst, en, baud_cnt, baud_tic, hf_baud);
input clk, rst, en;
input [15:0] baud_cnt;
output hf_baud, baud_tic;

reg [15:0] count;

assign baud_tic = (count==baud_cnt) ? 1'b1 : 1'b0 ;
assign hf_baud = (count==(baud_cnt >> 1)) ? 1'b1 : 1'b0 ;

always@(posedge clk or posedge rst) begin 
    if(rst) begin 
        count <= 0;
    end
    else begin 
        if(en)  
            count <= (count==baud_cnt) ? 0 : count+1 ;
        else 
            count <= 0;
    end
end

endmodule
