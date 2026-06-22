`timescale 1ns / 1ps

module UART_top(clk, rst, offset, d_in, d_out, sel, en, TX, RX,ready);
input clk, rst, en, sel, RX;
input [31:0] d_in;
input [2:0] offset;
output TX;
output reg ready;
output reg [31:0] d_out;

reg [7:0] ctrl, tx_data ;
wire [7:0] rx_data;
reg [15:0] baud_cnt;
wire tx_baud_tic, rx_baud_tic, hf_baud, tx_st, tx_busy, rx_read, rx_val, par_error, fr_error, overrun, tx_baud_en, rx_baud_en;
wire [7:0] status;

assign status = {3'b000, overrun, par_error, fr_error, rx_val, tx_busy};  
assign tx_st = (sel && en && (offset==3'b010)) ;
assign rx_read = (sel && !en && (offset==3'b011));

always@(*) begin 
    d_out = 0;
    if (sel && !en) begin 
        case(offset)  
            3'd0 : d_out = {{24{1'b0}},ctrl};
            3'd1 : d_out = {{24{1'b0}},status};
            3'd2 : d_out = {{24{1'b0}},tx_data};
            3'd3 : d_out = {{24{1'b0}},rx_data};
            3'd4 : d_out = {{16{1'b0}},baud_cnt};
            default : d_out = 0;
        endcase
    end
end

always@(posedge clk or posedge rst) begin
    if(rst) begin 
        ctrl <= 0;
        tx_data <= 0;
        baud_cnt <= 0;
        ready <= 0;
    end
    else begin 
        ready <= 0;
        if(sel && en) begin 
            ready <= 1;
            case(offset)
                3'd0 : ctrl <= d_in[7:0];
                3'd2 : tx_data <= d_in[7:0];
                3'd4 : baud_cnt <= d_in[15:0];
            endcase
         end
    end
end

tx_UART transmit (clk,rst,ctrl[0],ctrl[2],tx_baud_tic,tx_data,tx_st,TX,tx_busy,tx_baud_en);
rx_UART receive (clk,rst,ctrl[1],ctrl[2],rx_baud_tic,hf_baud,rx_data,rx_read,rx_val,RX,par_error,fr_error,overrun,rx_baud_en);
baud_gen tx_baud_rate (clk, rst, tx_baud_en, baud_cnt, tx_baud_tic,        );
baud_gen rx_baud_rate (clk, rst, rx_baud_en, baud_cnt, rx_baud_tic, hf_baud);

endmodule
