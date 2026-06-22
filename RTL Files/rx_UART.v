`timescale 1ns / 1ps

module rx_UART(clk,rst,rx_en,par_en,baud_tic,hf_baud,rx_data,rx_read,rx_val,RX,par_error,fr_error,overrun,baud_en);
input clk,rst,rx_en,par_en,baud_tic,hf_baud,RX,rx_read;
output reg rx_val,par_error,fr_error;
output reg overrun,baud_en;
output reg [7:0] rx_data;

reg [1:0] state;
parameter IDLE=2'b00, RECEIVE=2'b01, DONE=2'b10 ;
reg par_done;
reg [2:0] bit_cnt;

always@(posedge clk or posedge rst) begin 
    if(rst) begin 
        rx_val <= 1'b0;
        par_error <= 1'b0;
        fr_error <= 1'b0;
        overrun <= 1'b0;
        rx_data <= 0;
        par_done <= 1'b0;
        state <= IDLE;
        bit_cnt <= 0;
        baud_en <= 1'b0;
    end
    
    else begin
        case(state)
            IDLE : begin 
                if(!RX && hf_baud && rx_en)
                    baud_en <= 1'b0;
                else if(!RX) 
                    baud_en <= 1'b1;
                else 
                    baud_en <= 1'b0;
                    
                state <= (!RX && hf_baud && rx_en) ? RECEIVE : IDLE;
                
                if (rx_val && hf_baud && !RX && rx_en)
                    overrun <= 1'b1;
                if (rx_read) begin
                    rx_val <= 1'b0;
                    overrun <= 1'b0;
                end
            end
            RECEIVE : begin 
                baud_en <= 1'b1;
                if(rx_en && baud_tic) begin
                    rx_data[bit_cnt] <= RX;
                    bit_cnt <= bit_cnt+1;
                    state <= (bit_cnt==3'b111) ? DONE : RECEIVE ;
                end
            end
            DONE : begin
                if(baud_tic && rx_en) begin
                    if(par_en && !par_done) begin
                        par_error <= (^rx_data) ^ RX;
                        par_done <= 1'b1;
                    end
                    else begin 
                        fr_error <= RX ? 1'b0 : 1'b1;
                        state <= IDLE ;
                        rx_val <= 1'b1;
                        par_done <= 1'b0;
                        baud_en <= 1'b0;
                    end
                end
            end
        endcase
    end
end

endmodule
