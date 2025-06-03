
`timescale 1ns / 1ps

module lab8(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,

  // SD card specific I/O ports
  output spi_ss,
  output spi_sck,
  output spi_mosi,
  input  spi_miso,

  // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D,
  
  // tri-state LED
  output [3:0] rgb_led_r,
  output [3:0] rgb_led_g,
  output [3:0] rgb_led_b
);
localparam [2:0] S_MAIN_INIT = 3'b000, S_MAIN_PRESS = 3'b001,
                 S_MAIN_WAIT = 3'b010, S_MAIN_READ_1 = 3'b011,
                 S_MAIN_SHOW = 3'b101,S_MAIN_SHOW0=3'b100,
                 S_MAIN_WAITT = 3'b110, S_MAIN_READ_2 = 3'b111;

// Declare system variables
wire btn_level, btn_pressed;
reg  prev_btn_level;
reg  [2:0] P, P_next;
reg  [9:0] sd_counter;
reg  [31:0] blk_addr;

reg  [127:0] row_A = "SD card cannot  ";
reg  [127:0] row_B = "be initialized! ";

// Declare SD card interface signals
wire clk_sel;
wire clk_500k;
reg  rd_req;
wire init_finished;
wire [7:0] sd_dout;
wire sd_valid;

// Declare the control/data signals of an SRAM memory block
wire [7:0] data_in;
wire [7:0] data_out;
wire [8:0] sram_addr;
wire       sram_we, sram_en;

assign clk_sel = (init_finished)? clk : clk_500k; // clock for the SD controller
assign usr_led = P;

clk_divider#(200) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(clk_500k)
);

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level)
);

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

sd_card sd_card0(
  .cs(spi_ss),
  .sclk(spi_sck),
  .mosi(spi_mosi),
  .miso(spi_miso),

  .clk(clk_sel),
  .rst(~reset_n),
  .rd_req(rd_req),
  .block_addr(blk_addr),
  .init_finished(init_finished),
  .dout(sd_dout),
  .sd_valid(sd_valid)
);

sram ram0(
  .clk(clk),
  .we(sram_we),
  .en(sram_en),
  .addr(sram_addr),
  .data_i(data_in),
  .data_o(data_out)
);

always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 0;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level == 1 && prev_btn_level == 0)? 1 : 0;

// ------------------------------------------------------------------------
// The following code sets the control signals of an SRAM memory block
// that is connected to the data output port of the SD controller.
// Once the read request is made to the SD controller, 512 bytes of data
// will be sequentially read into the SRAM memory block, one byte per
// clock cycle (as long as the sd_valid signal is high).
assign sram_we = sd_valid;          // Write data into SRAM when sd_valid is high.
assign sram_en = 1;                 // Always enable the SRAM block.
assign data_in = sd_dout;           // Input data always comes from the SD controller.
assign sram_addr = sd_counter[8:0]; // Set the driver of the SRAM address signal.
// End of the SRAM memory block
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
reg read1,read2;
reg [15:0] ans_cnt;
reg [70:0] store_idx_now;
always @(posedge clk) begin
    if(~reset_n) P <= S_MAIN_INIT;
    else P <= P_next;
end
always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: 
      if (init_finished) P_next = S_MAIN_PRESS;
      else P_next = S_MAIN_INIT;
    S_MAIN_PRESS:
      if (btn_pressed) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_PRESS;
    S_MAIN_WAIT:
      P_next = S_MAIN_READ_1;
    S_MAIN_READ_1: 
      if(str == "DCL_START") P_next = S_MAIN_READ_2;
      else if (sd_counter == 512) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_READ_1;
    S_MAIN_READ_2:
      if(str[55:0] == "DCL_END") P_next = S_MAIN_SHOW0;
      else if(sd_counter == 512) P_next = S_MAIN_WAITT;
      else P_next = S_MAIN_READ_2;
    S_MAIN_WAITT:
      P_next = S_MAIN_READ_2;
    S_MAIN_SHOW0:
    if(store_cnt-6==store_idx_now) P_next<=S_MAIN_SHOW;
    else P_next<=S_MAIN_SHOW0;
    S_MAIN_SHOW:
      if (btn_pressed) P_next = S_MAIN_PRESS;
    else P_next = S_MAIN_SHOW;
    default:
      P_next = S_MAIN_PRESS;
  endcase
end
    
always @(*) begin
  rd_req = (P == S_MAIN_WAIT) || (P == S_MAIN_WAITT);
end

reg [3:0] cnt_R,cnt_G,cnt_B,cnt_Y,cnt_P,cnt_else;
reg [3:0] red,green,blue;
reg [0:54*8-1] store;
reg[70:0] store_cnt;
reg [70:0] set;
reg [50:0] timer;
always @(posedge clk) begin
    if (~reset_n)begin
        store_idx_now<=0;
        timer<=0;
        red<=0;
        blue<=0;
        set<=0;
        green<=0;
    end
    else if(P==S_MAIN_SHOW0)begin
        if(store_idx_now<4)begin
            timer<=0;
            store_idx_now<=store_idx_now+1;
        end
        if(~set[store_idx_now]) begin
        case (store[store_idx_now*8+:8])
          "R","r": begin
            red<={red[2:0],1'b1};
            blue<={blue[2:0],1'b0};
            green<={green[2:0],1'b0};
          end 
          "G","g": begin
            red<={red[2:0],1'b0};
            blue<={blue[2:0],1'b0};
            green<={green[2:0],1'b1};
          end 
          "B","b": begin
            red<={red[2:0],1'b0};
            blue<={blue[2:0],1'b1};
            green<={green[2:0],1'b0};
          end 
          "Y","y": begin
            red<={red[2:0],1'b1};
            blue<={blue[2:0],1'b0};
            green<={green[2:0],1'b1};
          end 
          "P","p": begin
            red<={red[2:0],1'b1};
            blue<={blue[2:0],1'b1};
            green<={green[2:0],1'b0};
          end 
          default: begin
            red<={red[2:0],1'b0};
            blue<={blue[2:0],1'b0};
            green<={green[2:0],1'b0};
          end 
        endcase
        
        set[store_idx_now]<=1;
        end 
        else begin
            red<=red;
            blue<=blue;
            green<=green;
        end
    if(timer>40'h005ffffff)begin
        timer<=0;
        store_idx_now<=store_idx_now+1;
    end
    else timer<=timer+1;
    end
    else if(P==S_MAIN_SHOW0)begin
        red<=0;
        blue<=0;
        green<=0;
    end
end
reg fir;
reg [3:0] cnt_else_2;
always @(posedge clk) begin
    if (~reset_n || P == S_MAIN_WAIT)begin
        cnt_R<=0;
        cnt_G<=0;
        cnt_B<=0;
        cnt_Y<=0;
        cnt_P<=0;
        cnt_else<=0;
        cnt_else_2<=0;
        store<=0;
        fir=0;
        store_cnt<=0;
    end
    else if (P == S_MAIN_READ_2 && sd_valid) begin
          case (str[7:0])
          "R","r": begin
            cnt_R <= cnt_R + 1;
          end 
          "G","g": begin
            cnt_G <= cnt_G + 1;
          end 
          "B","b": begin
            cnt_B <= cnt_B + 1;
          end 
          "Y","y": begin
            cnt_Y <= cnt_Y + 1;
          end 
          "P","p": begin
            cnt_P <= cnt_P + 1;
          end 
          default: begin
            if(fir)begin
            if(cnt_else>=6)begin
                    cnt_else_2<=cnt_else_2+1; end
            else begin
                cnt_else <= cnt_else + 1;
            end
            end
          end 
          endcase
          if(~fir)begin
            fir<=1;
          end
          else begin
          store[store_cnt*8+:8]<=str[7:0];
          store_cnt<=store_cnt+1;
          end
    end
end

always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_PRESS) blk_addr <= 32'h2000;
  else if(P == S_MAIN_WAIT || P == S_MAIN_WAITT) blk_addr <= blk_addr + 1;
end

always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_WAIT || P == S_MAIN_WAITT)
    sd_counter <= 0;
  else if (sd_valid == 1)
    sd_counter <= sd_counter + 1;
end

reg [71:0] str;

always@(posedge clk) begin
    if(~reset_n) str <= 72'h0;
    else if(sd_valid && (P == S_MAIN_READ_1 || P == S_MAIN_READ_2)) begin
        str <= {str[63:0],sd_dout};
    end
end
// End of the FSM of the SD card reader
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// LCD Display function.
always @(posedge clk) begin
  if (~reset_n) begin
    row_A = "SD card cannot  ";
    row_B = "be initialized! ";
    read1<=0;
    read2<=0;
  end
  else if (P == S_MAIN_READ_1&&~read1) begin
    if(~read1) read1<=1;
    row_A<="searching for   ";
    row_B<="title           ";
  end
  else if (P == S_MAIN_SHOW) begin
    row_A <= "RGBPYX          ";
    row_B<={((cnt_R > 9)? "7" : "0") + cnt_R,
              ((cnt_G > 9)? "7" : "0") + cnt_G,
              ((cnt_B > 9)? "7" : "0") + cnt_B,
              ((cnt_P > 9)? "7" : "0") + cnt_P,
              ((cnt_Y > 9)? "7" : "0") + cnt_Y,
              ((cnt_else_2 > 9)? "7" : "0") + cnt_else_2,"          "};
  end
      else if(P==S_MAIN_SHOW0)begin
        row_A<="calculating...  ";
        row_B<="                ";
        end
  else if (P == S_MAIN_PRESS) begin
    row_A <= "Hit BTN2 to read";
    row_B <= "the SD card ... ";
  end
end
// End of the LCD display function
// ------------------------------------------------------------------------


localparam brightness = 50000; 
reg [19:0] pwm_counter;   
reg [2:0] pwm_duty_cycle;  
reg [3:0] led_r,led_g,led_b;
assign rgb_led_b=led_b;
assign rgb_led_g=led_g;
assign rgb_led_r=led_r;
localparam MAX_PWM = 1000000; 
always @(posedge clk) begin
    if (~reset_n) begin
        pwm_counter <= 0;
    end else begin
        if (pwm_counter < MAX_PWM)
            pwm_counter <= pwm_counter + 1;
        else
            pwm_counter <= 0;
    end
end
always @(posedge clk) begin
    if (~reset_n||P==S_MAIN_SHOW) begin
        led_b=0;
            led_g=0;
            led_r=0;
    end else begin
        if (pwm_counter < brightness)begin
            led_b=blue;
            led_g=green;
            led_r=red; 
        end
        else begin
             led_b=0;
            led_g=0;
            led_r=0;
        end
    end
end
endmodule

