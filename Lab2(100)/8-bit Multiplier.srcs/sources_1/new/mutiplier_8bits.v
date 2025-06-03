module SeqMultiplier(
    
    input wire [8-1:0] A,
    input wire [8-1:0] B,
    output wire [16-1:0] C,
    input wire enable,
    input wire clk
 
);

reg [16-1:0] product;
reg [8-1:0] multiplicand;
reg [4-1:0] counter;
wire shift;

assign shift = |(counter^7);
assign C = product;

always @(posedge clk) begin

    if(!enable) begin
        multiplicand <= B;
        counter <= 0;
        product <= 0;
    end
    else begin
    if(counter<8) begin
        counter <= counter + 1;
        multiplicand <= multiplicand << shift;
        //product <= (product << 1) + (A & {8{multiplicand[7]}});
        product <= (product + (A&{8{multiplicand[7]}})) << shift;
        end
    end

end

endmodule