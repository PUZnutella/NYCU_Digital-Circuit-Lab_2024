`timescale 1ns / 1ps
/////////////////////////////////////////////////////////
module lab5(
  input clk,
  input reset_n,
  input [3:0] usr_btn,      // button 
  input [3:0] usr_sw,       // usr_sw
  output [3:0] usr_led,     // led
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);
reg [72-1:0] ascii1;
reg [72-1:0] ascii2;
reg [72-1:0] ascii3;
reg [127:0] row_A = "     |2|8|3|    "; // Initialize the text of the first row. 
reg [127:0] row_B = "     |1|9|1|    ";// Initialize the text of the second row.

assign usr_led = 4'b0000; // turn off led
LCD_module lcd0(
  .clk(clk),
  .reset(~reset_n),
  .row_A(row_A),
  .row_B(row_B),
  .LCD_E(LCD_E),
  .LCD_RS(LCD_RS),
  .LCD_RW(LCD_RW),
  .LCD_D(LCD_D)
);
    
/*
127:120
119:112
111:104
103:96
95:88
87:80
79:72
71:64
63:56
55:48
47:40
39:32
31:24
23:16
15:8
7:0
    */
reg [27-1:0] counter1;
reg [27-1:0] counter3;
reg [28-1:0] counter2;

reg [4-1:0] state;
reg error;
reg [24-1:0] record;

always @(posedge clk) begin
    if(~reset_n)begin
    state<=0;
    error<=0;
    counter1<=0;
    counter2<=0;
    counter3<=0;
    ascii1<={8'h31, 8'h33, 8'h35, 8'h37, 8'h39, 8'h32, 8'h34, 8'h36, 8'h38};
    ascii2<={8'h39, 8'h38, 8'h37, 8'h36, 8'h35, 8'h34, 8'h33, 8'h32, 8'h31};
    ascii3<={8'h31, 8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38, 8'h39};
    row_A <= "     |2|8|3|    ";
    row_B <= "     |1|9|1|    ";
    end
    else if(~usr_sw[0]&&!error)begin
    if(state[3]||state[2]||state[1])begin
    if(state[3]&&usr_sw[3]||state[2]&&usr_sw[2]||state[1]&&usr_sw[1]) begin
            row_A <= "      ERROR     ";
            row_B <="  game stopped  ";
            error<=1;
    end
    end
    if(!usr_sw[0]&&state[3]&&state[2]&&state[1])begin
        if(!(!usr_sw[1]&&!usr_sw[2]&&!usr_sw[3]))begin
            row_A <= "      ERROR     ";
            row_B <="  game stopped  ";
            error<=1;
        end
    end
    
    
    else begin
        if(usr_sw[1]&&!state[1])begin
            if(counter1>27'h5F5E100)begin
                counter1<=0;
                row_A[47:40] <= ascii1[63:56];
                row_B[47:40] <= ascii1[71:64];
                record[7:0] <= ascii1[71:64];
                ascii1 <= {ascii1[63:0],ascii1[71:64]};
            end
            else counter1 <= counter1 + 1;
        end
        else state[1]<=1;
        if(usr_sw[2]&&!state[2])begin
            if(counter2>28'hBEBC200)begin
                counter2<=0;
                row_A[63:56]<=ascii2[63:56];
                row_B[63:56]<=ascii2[71:64];
                record[15:8] <= ascii2[71:64];
                ascii2 <= {ascii2[63:0],ascii2[71:64]};
            end
            else counter2 <= counter2 + 1;
        end
        else state[2]<=1;

        if(usr_sw[3]&&!state[3])begin
            if(counter3>27'h5F5E100)begin
                counter3<=0;
                row_A[79:72] <= ascii3[63:56];
                row_B[79:72] <= ascii3[71:64];
                record[23:16] <= ascii3[71:64];
                ascii3 <= {ascii3[63:0],ascii3[71:64]};
            end
            else counter3 <= counter3 + 1;
        end
        else state[3]<=1;
        
        if(~usr_sw[1]&~usr_sw[2]&~usr_sw[3])begin
          if ((record[7:0] == record[15:8]) && (record[7:0] == record[23:16])&&(record[15:8]==record[23:16])) begin
          row_A <= {8'h20, 8'h20, 8'h20, 8'h20, "Jackpots!", 8'h20, 8'h20, 8'h20};
          row_B <= {8'h20, 8'h20,8'h20, 8'h20,"Game",8'h20,"over",8'h20, 8'h20,8'h20};
          end
          else if ((record[7:0] != record[15:8])&&(record[7:0] != record[23:16])&&(record[15:8]!=record[23:16])) begin
              row_A <= {8'h20, 8'h20, 8'h20,8'h20,8'h20,"Loser!",8'h20, 8'h20, 8'h20,8'h20,8'h20};
              row_B <= {8'h20, 8'h20,8'h20, 8'h20,"Game",8'h20,"over",8'h20, 8'h20,8'h20};
          end
          else begin
            row_A <= {8'h20, 8'h20, 8'h20,"Free",8'h20,"Game!",8'h20, 8'h20, 8'h20};
            row_B <= {8'h20, 8'h20,8'h20, 8'h20,"Game",8'h20,"over",8'h20, 8'h20,8'h20};
          end
        end
      end
    end
end


endmodule