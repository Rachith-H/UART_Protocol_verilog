  `timescale 1ns / 1ps

module tx_UART(clk,rst,tx_en,par_en,baud_tic,tx_data,tx_st,TX,tx_busy,baud_en);

input clk,rst,tx_en,par_en,baud_tic,tx_st;
input [7:0] tx_data;
output reg TX, tx_busy, baud_en;

parameter IDLE=2'b00 , TRANSFER=2'b01 , DONE=2'b10;
reg [1:0] state;
reg [2:0]bit_cnt;
reg par_done;

always@(posedge clk or posedge rst) begin 
    
    if(rst) begin 
        TX <= 1'b1;
        state <= IDLE;
        tx_busy <= 1'b0;
        bit_cnt <= 0;
        par_done <= 1'b0;
        baud_en <= 1'b0;
    end
    
    else begin
        case(state)
        
            IDLE : begin
                state <= (tx_en && tx_st) ? TRANSFER : IDLE ;
                TX <= (tx_en && tx_st) ? 1'b0 : 1'b1 ;
                tx_busy <= (tx_en && tx_st) ? 1'b1 : 1'b0 ;
            end
            
            TRANSFER : begin 
                baud_en <= 1'b1;
                if(baud_tic && tx_en) begin 
                    TX <= tx_data[bit_cnt];
                    bit_cnt <= bit_cnt+1;
                    state <= (bit_cnt==3'b111) ? DONE : TRANSFER ;
                end
            end
            
            DONE : begin 
                if(baud_tic && tx_en) begin
                    if(par_en && !par_done) begin
                        TX <= (^tx_data) ;
                        par_done <= 1'b1;
                    end
                    else begin 
                        TX <= 1'b1;
                        tx_busy <= 1'b0;
                        state <= IDLE ; 
                        par_done <= 1'b0;  
                        baud_en <=1'b0; 
                    end 
                end
            end
            
            default : state <= IDLE;
            
        endcase
    end
    
end

endmodule
