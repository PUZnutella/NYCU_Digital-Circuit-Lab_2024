module SeqMultiplier(
		input wire clk, 
		input wire enable,
		input wire [7:0] A, 
		input wire [7:0] B,
		output wire [15:0] C
	);
reg [15:0] prod; 
reg [7:0] mult;
reg [3:0] counter;
wire shift;
assign C = prod;
assign shift = |(counter^7); //1 if counter<7; 0 if counter==7
/*
Every bit of counter exclusive or 7(4'b0111), and or together
ex: When counter = 4'd2 = 4'b0010, then counter^7 = 4'b0101, shift = 0|1|0|1 = 1
That is, only when counter^7 == 4'b0000 --> counter == 7 will shift be 0. 
*/

always @ (posedge clk) begin

        if (!enable) begin //Reset

            mult <= B; //We will change the value of it, so we put it in another register.

            prod <= 0;

            counter <= 0;

        end

        else begin

            mult <= mult << 1; //shift left
            prod <= (prod + (A & {8{mult[7]}})) << shift;

/*



Replication, {8{mult[7]}} == {mult [7], mult[7], mult[7], mult[7], mult [7], mult [7], mult [7], mult [7]}

Every bit of A will '&'(bit-wise operator) the highest bit of mult, ex: 01000101 & 11111111 = 01000101 / 01000101 & 00000000 = 00000000

add the result to prod (product) and prod then shifts left.

Can take page 31 of labl's ppt as example:

X

00010111 → multiplicand 00010011 → multiplier

00000000 <--|

counter = 0: prod = 0000000000000000

00000000

counter = 1: prod = 0000000000000000

00000000

counter = 2: prod = 0000000000000000

00010111

counter = 3: prod = 0000000000010111

00000000

counter = 4: prod = 0000000000101110

00000000

counter = 5: prod = 0000000001011100

00010111 |

counter = 6: prod = 0000000011001111

counter = 7: prod = 0000000110110101

+

000000110110101| product

   
*/
             counter <= counter + shift; //counter+1 when counter < 7

        end
end

endmodule