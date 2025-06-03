`timescale 1ns / 1ps

module mmult(
input clk,                  // Clock signal.
input reset_n,              // Reset signal (negative logic).
input enable,               // Activation signal for matrix
                            //    multiplication (tells the circuit
                            //    that A and B are ready for use).
input [0:9*8-1] A_mat,      // A matrix.
input [0:9*8-1] B_mat,      // B matrix.
output valid,               // Signals that the output is valid
                            //       to read.
output reg [0:9*18-1] C_mat // The result of A x B.
);
integer i, j;
reg[0:1] count;

assign valid=(count >= 3);

always@(posedge clk) begin
    if(reset_n == 0 | enable == 0) begin
        C_mat <= 0;
		count <= 0;
	end
    else if(enable == 1 & count < 3) begin
        for(i = 0; i < 3; i = i+1)
            for(j = 0; j < 3; j = j + 1)
                C_mat[(i*3+j)*18 +: 18] <= C_mat[(i*3+j)*18 +: 18] + A_mat[(i*3+count)*8 +: 8] * B_mat[(count*3+j)*8 +: 8];
        count <= count + 1;
        end

end
endmodule