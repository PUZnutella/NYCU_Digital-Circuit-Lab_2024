`timescale 1ns / 1ps

module lab4(
    input [4-1:0] usr_btn,     
    output [4-1:0] usr_led, 
    input clk,                
    input reset_n           
);

wire [4-1:0] ded_btn;      
reg [3-1:0] light_level;       
reg [4-1:0] counter;          
reg [20-1:0] pwm;      
reg [4-1:0] led;
assign usr_led=led;

Debouncing_btn de_btn0(.clk(clk), .btn_in(usr_btn[0]), .btn_out(ded_btn[0]), .reset_n(reset_n));
Debouncing_btn de_btn1(.clk(clk), .btn_in(usr_btn[1]), .btn_out(ded_btn[1]), .reset_n(reset_n));
Debouncing_btn de_btn2(.clk(clk), .btn_in(usr_btn[2]), .btn_out(ded_btn[2]), .reset_n(reset_n));
Debouncing_btn de_btn3(.clk(clk), .btn_in(usr_btn[3]), .btn_out(ded_btn[3]), .reset_n(reset_n));

always @(posedge clk) begin
    if (~reset_n) begin
        counter <= 0;
        pwm <= 0;
        light_level <= 0;
        led <= 0;
    end else begin
        //counter:btn[0]-- btn[1]++
        if (ded_btn[1] == 1 && counter < 15) 
            counter <= counter + 1; 
        else if (ded_btn[0] == 1 && counter > 0) 
            counter <= counter - 1;

        //light_level:btn[2]-- btn[3]++
        if (ded_btn[3] == 1 && light_level > 0) 
            light_level <= light_level - 1;
        else if (ded_btn[2] == 1 && light_level < 4) 
            light_level <= light_level + 1;
    end
    case (light_level)
        3'b000: if (pwm < 50000) led <= counter ^ (counter >> 1); else led <= 0;
        3'b001: if (pwm < 250000) led <= counter ^ (counter >> 1); else led <= 0;
        3'b010: if (pwm < 500000) led <= counter ^ (counter >> 1); else led <= 0;
        3'b011: if (pwm < 750000) led <= counter ^ (counter >> 1); else led <= 0;
        3'b100: led <= counter ^ (counter >> 1); 
    endcase

    if (pwm < 1000000) 
        pwm <= pwm + 1;
    else 
        pwm <= 0;
end
endmodule

module Debouncing_btn(
    input clk,
    input btn_in,
    input reset_n,
    output reg btn_out
);
    reg [20-1:0] ms;   
    reg btn_now,btn_prev;      
    
    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) begin
            ms <= 0;
            btn_out <= 0;
            btn_now <= 0;
            btn_prev <= 0;
        end 
        else begin
            if (btn_in != btn_now) begin
                ms <= 0;
                btn_now <= btn_in;
            end 
            else if (ms == 20'hFFFFF) begin
                btn_prev <= btn_now;
                if (btn_now == 1 && btn_prev == 0) begin
                    btn_out <= 1;  
                end 
                else begin
                    btn_out <= 0; 
                end
            end 
            else begin
                ms <= ms + 1; 
            end
        end
    end
endmodule