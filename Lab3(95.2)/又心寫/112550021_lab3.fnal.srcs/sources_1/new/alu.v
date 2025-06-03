`timescale 1ns / 1ps

module alu(
    // DO NOT modify the interface!
    // input signal
    input [7:0] accum,
    input [7:0] data,
    input [2:0] opcode,
    input reset,
    
    // result
    output [7:0] alu_out,
    
    // PSW
    output  zero,
    output  overflow,
    output  parity,
    output  sign
    );
    reg signed [9-1:0] out;
    assign alu_out=out[8-1:0];
    reg zero_r,overflow_r,parity_r,sign_r;
    assign zero=zero_r;
    assign overflow=overflow_r;
    assign parity=parity_r;
    assign sign=sign_r;
    reg signed [8-1:0] accum_s;
    reg signed [8-1:0] data_s;
    
    always @(*) begin
        if (reset) begin
            out=8'b0;
            zero_r=1;
            overflow_r=0;
            parity_r=0;
            sign_r=0;
        end 
        else begin
            zero_r = 0;
            overflow_r = 0;
            parity_r = 0;
            sign_r = 0;

            case (opcode)
            
            //pass accum
            3'b000:out<=accum;
            
            //accum+data
            3'b001:begin
            out=accum+data;
            if(accum[7]==1&&data[7]==1&&out[7]==0)begin
            out=9'b110000000;
            overflow_r=1;
            end
            else if(accum[7]==0&&data[7]==0&&out[7]==1)begin
            out=9'b001111111;
            overflow_r=1;
            end
            end
            
            //accum-data
            3'b010:begin
            out=accum-data;
            if(accum[7]==1&&data[7]==0&&out[7]==0)begin
            out=9'b110000000;
            overflow_r=1;
            end
            else if(accum[7]==0&&data[7]==1&&out[7]==1)begin
            out=9'b001111111;
            overflow_r=1;
            end
            end

            //accum arthmetric right shift data bit 右移 x bits?
            3'b011:begin
            accum_s=accum;
            out=accum_s>>>data;
            end
            
            //accum xor data
            3'b100:out<=accum^data;
            
            //ABS(accum)
            3'b101:begin
                if(accum[7]==0)begin
                    out<=accum;
                end
                else begin
                    out<=~accum+8'b1;
                end
            end
            
            //accum*data
            3'b110:begin
            if(accum[3]==0&&data[3]==0)begin
                out<=accum[4-1:0]*data[4-1:0];
            end
            else if(accum[3]==1&&data[3]==0)begin
                out<=~((~{4'b1111,accum[4-1:0]}+1)*data)+1;
            end
            else if(accum[3]==0&&data[3]==1)begin
                out<=~((~{4'b1111,data[4-1:0]}+1)*accum)+1;
            end
            else begin
                out<=(~accum[4-1:0]+4'b1)*(~data[4-1:0]+4'b1);
            end
     
            end
            
            //-(accum)
            3'b111:begin
                out<=~accum+8'b1;
            end
            
            //x
            default:out<=8'b0;

        endcase
            zero_r=(alu_out==8'b0);
            parity_r=^alu_out;
            sign_r=alu_out[7];
        end
    end
endmodule
