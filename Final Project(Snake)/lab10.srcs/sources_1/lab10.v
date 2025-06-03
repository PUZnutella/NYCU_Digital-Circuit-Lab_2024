`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: <Your Name>
//
// Description: Snake game demo with additional walls and random apple generation.
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    input  [3:0] usr_sw,
    output [3:0] usr_led,
    
    // VGA ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// =============================================================================
// Parameters
// =============================================================================
localparam VBUF_W = 300;   
localparam VBUF_H = 240;   
localparam CELL_W = 15;    
localparam CELL_H = 15;    
localparam GRID_W = 20;    // 20 * 15 = 300
localparam GRID_H = 16;    // 16 * 15 = 240

localparam SNAKE_IMG_NUM = 3;
localparam IMG_SIZE = CELL_W * CELL_H; // 225 pixels per image (15x15)
reg [9:0] score;
reg [9:0] maxscore;
// Calculate snake image start address
function [17:0] snake_img_addr;
  input [4:0] index;
  begin
    snake_img_addr = (index-1)*IMG_SIZE;
  end
endfunction

// =============================================================================
// Debounce
// =============================================================================
wire [3:0] btn_level, btn_pressed;
reg  [3:0] prev_btn_level;

debounce btn_db0(.clk(clk), .btn_input(usr_btn[0]), .btn_output(btn_level[0]));
debounce btn_db1(.clk(clk), .btn_input(usr_btn[1]), .btn_output(btn_level[1]));
debounce btn_db2(.clk(clk), .btn_input(usr_btn[2]), .btn_output(btn_level[2]));
debounce btn_db3(.clk(clk), .btn_input(usr_btn[3]), .btn_output(btn_level[3]));

always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 4'b0000;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level & ~prev_btn_level);

// =============================================================================
// VGA Sync
// =============================================================================
wire vga_clk;
wire video_on, pixel_tick;
wire [9:0] pixel_x, pixel_y;

vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n),
  .oHS(VGA_HSYNC),
  .oVS(VGA_VSYNC),
  .visible(video_on),
  .p_tick(pixel_tick),
  .pixel_x(pixel_x),
  .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk), .reset(~reset_n),
  .clk_out(vga_clk)
);

// =============================================================================
// SRAM for background and snake
// =============================================================================
wire [17:0] sram_addr_bkg, sram_addr_snake, sram_addr_background;
wire [11:0] data_out_bkg, data_out_snake, data_out_background;
wire [11:0] data_in = 12'h000;
wire sram_we = ~usr_sw[0]; // Disable write to SRAM
wire sram_en = 1;


wire [17:0] sram_addr_apple;                                           ///////有改的地方
wire [11:0] data_out_apple;
wire [17:0] sram_addr_score1;
wire [17:0] sram_addr_score2;
wire [11:0] data_out_score1;
wire [11:0] data_out_score2;
sram #(
  .DATA_WIDTH(12), .ADDR_WIDTH(18),
  .RAM_SIZE(20*225),
  .FILE_NAME("score1.mem")
) ram_score(
  .clk(clk), .we(sram_we), .en(sram_en),
  .addr1(sram_addr_score1), .data_i1(data_in), .data_o1(data_out_score1),
  .addr2(sram_addr_score2), .data_i2(data_in), .data_o2(data_out_score2)
);

sram #(
  .DATA_WIDTH(12), .ADDR_WIDTH(18),
  .RAM_SIZE(IMG_SIZE*SNAKE_IMG_NUM),
  .FILE_NAME("snake_appple.mem")
) ram_snake(
  .clk(clk), .we(1'b0), .en(sram_en),
  .addr1(sram_addr_snake), .data_i1(data_in), .data_o1(data_out_snake),
  .addr2(sram_addr_apple), .data_i2(data_in), .data_o2(data_out_apple)
);

/*sram #(
  .DATA_WIDTH(12), .ADDR_WIDTH(18),
  .RAM_SIZE(VBUF_W*VBUF_H),
  .FILE_NAME("images0.mem")
) ram_ocean(
  .clk(clk), .we(sram_we), .en(sram_en),
  .addr1(sram_addr_bkg), .data_i1(data_in), .data_o1(data_out_background),
  .addr2(18'd0), .data_i2(12'd0), .data_o2()
);*/

sram #(
  .DATA_WIDTH(12), .ADDR_WIDTH(18),
  .RAM_SIZE(VBUF_W*VBUF_H),
  .FILE_NAME("bkg_score.mem")
) ram_bkg(
  .clk(clk), .we(sram_we), .en(sram_en),
  .addr1(sram_addr_bkg), .data_i1(data_in), .data_o1(data_out_bkg),
  .addr2(18'd0), .data_i2(12'd0), .data_o2()
);
// =============================================================================
// Wall Definitions
// =============================================================================
localparam NUM_WALLS = 29; 
reg [4:0] wall_x [0:NUM_WALLS-1];
reg [4:0] wall_y [0:NUM_WALLS-1];

always @(posedge clk or negedge reset_n) begin
  if (~reset_n) begin
    wall_x[0] <= 5'd3;  wall_y[0] <= 5'd0;
    wall_x[1] <= 5'd3;  wall_y[1] <= 5'd1;
    wall_x[2] <= 5'd3;  wall_y[2] <= 5'd2;
    wall_x[3] <= 5'd3;  wall_y[3] <= 5'd3;
    
    wall_x[4] <= 5'd0;  wall_y[4] <= 5'd11;
    wall_x[5] <= 5'd1;  wall_y[5] <= 5'd11;
    wall_x[6] <= 5'd2;  wall_y[6] <= 5'd11;
    wall_x[7] <= 5'd3;  wall_y[7] <= 5'd11;
    wall_x[8] <= 5'd4;  wall_y[8] <= 5'd11;
    wall_x[9] <= 5'd5;  wall_y[9] <= 5'd11;
    
    wall_x[10]<= 5'd9;  wall_y[10]<= 5'd6;
    wall_x[11]<= 5'd9;  wall_y[11]<= 5'd7;
    wall_x[12]<= 5'd9;  wall_y[12]<= 5'd8;
    wall_x[13]<= 5'd9;  wall_y[13]<= 5'd9;
    wall_x[14]<= 5'd9;  wall_y[14]<= 5'd10;
    wall_x[15]<= 5'd9; wall_y[15]<=5'd11;
    
    wall_x[15]<= 5'd15; wall_y[15]<=5'd5;
    wall_x[16]<= 5'd15; wall_y[16]<=5'd6;
    wall_x[17]<= 5'd15; wall_y[17]<=5'd7;
    wall_x[18]<= 5'd15; wall_y[18]<=5'd8;

    wall_x[19]<= 5'd16; wall_y[19]<=5'd5;
    wall_x[20]<= 5'd17; wall_y[20]<=5'd5;
    wall_x[21]<= 5'd18; wall_y[21]<=5'd5;
    wall_x[22]<= 5'd19; wall_y[22]<=5'd5;

    wall_x[23]<= 5'd12; wall_y[23]<=5'd13;
    wall_x[24]<= 5'd13; wall_y[24]<=5'd13;
    wall_x[25]<= 5'd14; wall_y[25]<=5'd13;
    wall_x[26]<= 5'd15; wall_y[26]<=5'd13;
    wall_x[27]<= 5'd16; wall_y[27]<=5'd13;
    wall_x[28]<= 5'd17; wall_y[28]<=5'd13;
  end else begin
    // walls do not change
  end
end

// =============================================================================
// Snake State and Movement
// =============================================================================
localparam MAX_SNAKE_LEN = 20; // Maximum possible snake length
reg [4:0] snake_x [0:MAX_SNAKE_LEN-1];
reg [4:0] snake_y [0:MAX_SNAKE_LEN-1];
reg [4:0] snake_next_x [0:MAX_SNAKE_LEN-1];
reg [4:0] snake_next_y [0:MAX_SNAKE_LEN-1];

reg [1:0] head_dir; // 0=right,1=up,2=left,3=down
integer i;
reg [31:0] snake_rate;
reg [31:0] move_clk;
wire move_tick = (move_clk == snake_rate);

always @(posedge clk) begin
    if (~reset_n) snake_rate <= 32'd30000000;
    else if ((score)>=6 && (score)<10) snake_rate <=  32'd20000000;
    else if ((score)>=10 && (score)<15) snake_rate <=  32'd10000000;
    else if ((score)>=15) snake_rate <=  32'd5000000;
    else snake_rate <= 32'd30000000;
end



reg game_started;
always @(posedge clk or negedge reset_n) begin
  if (~reset_n)
    game_started <= 1;
  else if((score) == 10'd0)
    game_started <= 0;
  // else if (btn_pressed[1])
    // game_started <= 1;
end

reg collision_detected;
// 將restricted_dir改為4 bits避免index超界
reg [3:0] restricted_dir;

// 按鈕0=上,1=右,2=下,3=左
always @(posedge clk or negedge reset_n) begin
  if (~reset_n) begin
    head_dir <= 0; // 初始方向 = 右
    collision_detected <= 0;
    restricted_dir <= 4'b1111; // 初始無方向限制
  end else if (game_started) begin
    if (btn_pressed[0] && head_dir != 3 && (collision_detected ? restricted_dir[1] : 1'b1)) begin
      head_dir <= 1; // 上
      restricted_dir <= 4'b1111;
      collision_detected <= 0;
    end 
    else if (btn_pressed[1] && head_dir != 2 && (collision_detected ? restricted_dir[0] : 1'b1)) begin
      head_dir <= 0; // 右
      restricted_dir <= 4'b1111;
      collision_detected <= 0;
    end 
    else if (btn_pressed[2] && head_dir != 1 && (collision_detected ? restricted_dir[3] : 1'b1)) begin
      head_dir <= 3; // 下
      restricted_dir <= 4'b1111;
      collision_detected <= 0;
    end 
    else if (btn_pressed[3] && head_dir != 0 && (collision_detected ? restricted_dir[2] : 1'b1)) begin
      head_dir <= 2; // 左
      restricted_dir <= 4'b1111;
      collision_detected <= 0;
    end
  end
end

reg [4:0] current_length;

always @(posedge clk or negedge reset_n) begin
  if (~reset_n) begin
    snake_x[0] <= 5'd10; snake_y[0] <= 5'd10;  
    snake_x[1] <= 5'd9;  snake_y[1] <= 5'd10; 
    snake_x[2] <= 5'd8;  snake_y[2] <= 5'd10; 
    snake_x[3] <= 5'd7;  snake_y[3] <= 5'd10; 
    snake_x[4] <= 5'd6;  snake_y[4] <= 5'd10; 
    
    move_clk <= 0;
    collision_detected <= 0;
  end else begin
    move_clk <= move_clk + 1;
    if (move_tick && game_started && !collision_detected) begin
      move_clk <= 0;

      case(head_dir)
        0: begin // right
          snake_next_x[0] = (snake_x[0] == GRID_W-1) ? 0 : snake_x[0] + 1;
          snake_next_y[0] = snake_y[0];
        end
        1: begin // up
          snake_next_y[0] = (snake_y[0] == 0) ? GRID_H-1 : snake_y[0] - 1;
          snake_next_x[0] = snake_x[0];
        end
        2: begin // left
          snake_next_x[0] = (snake_x[0] == 0) ? GRID_W-1 : snake_x[0] - 1;
          snake_next_y[0] = snake_y[0];
        end
        3: begin // down
          snake_next_y[0] = (snake_y[0] == GRID_H-1) ? 0 : snake_y[0] + 1;
          snake_next_x[0] = snake_x[0];
        end
      endcase

      // Check collision with walls
      collision_detected <= 0;
      for (i = 0; i < NUM_WALLS; i = i + 1) begin
        if (snake_next_x[0] == wall_x[i] && snake_next_y[0] == wall_y[i]) begin
          collision_detected <= 1;
          // 簡化: 碰撞後一律將restricted_dir還原或設定
          restricted_dir <= 4'b1111;
        end
      end

      if (!collision_detected) begin
        // Body follow
        for (i = 1; i < current_length; i = i + 1) begin
          snake_next_x[i] = snake_x[i-1];
          snake_next_y[i] = snake_y[i-1];
        end

        for (i = 0; i < (current_length); i = i + 1) begin
          snake_x[i] <= snake_next_x[i];
          snake_y[i] <= snake_next_y[i];
        end
      end
    end
  end
end

reg [4:0] segment_img [0:MAX_SNAKE_LEN-1];
integer j;
always @(*) begin
  if (current_length > 0)
    segment_img[0] = 5'd1; // head
  for (i=1; i<12; i=i+1) begin
    if (i < (current_length - 1))
      segment_img[i] = 5'd2; // body
    else
      segment_img[i] = 5'd0;
    //segment_img[i] = 5'd2; // body
  end
end

// =============================================================================
// Pixel Rendering
// =============================================================================
wire [8:0] mem_x = pixel_x >> 1;
wire [7:0] mem_y = pixel_y >> 1;

reg snake_found;
reg [17:0] snake_addr;
always @(*) begin
  snake_found = 0;
  snake_addr = 0;
  for (i=0; i<12; i=i+1) begin
    if(!snake_found && (i < current_length-1)) begin
      if((mem_x >= snake_x[i]*CELL_W) && (mem_x < (snake_x[i]+1)*CELL_W) &&
         (mem_y >= snake_y[i]*CELL_H) && (mem_y < (snake_y[i]+1)*CELL_H)) begin
        snake_found = 1;
        snake_addr = snake_img_addr(segment_img[i]) +
                     (mem_y - snake_y[i]*CELL_H)*CELL_W +
                     (mem_x - snake_x[i]*CELL_W);
      end
    end
  end
end

assign sram_addr_snake = snake_addr;
assign sram_addr_bkg = (mem_y < VBUF_H && mem_x < VBUF_W) ? (mem_y * VBUF_W + mem_x) : 0;


// =============================================================================
// Random Apple Generation                                                             //這邊都是有改的地方
// =============================================================================
reg [15:0] lfsr;
wire lfsr_feedback = lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3];

always @(posedge clk or negedge reset_n) begin
  if(~reset_n) begin
    lfsr <= 16'hACE1;
  end else begin
    lfsr <= {lfsr[14:0], lfsr_feedback};
  end
end

function [4:0] get_random_x;
  input [15:0] rand_val;
  begin
    get_random_x = rand_val[4:0] % 20; 
  end
endfunction

function [4:0] get_random_y;
  input [15:0] rand_val;
  begin
    get_random_y = rand_val[3:0]; // %16可簡化為直接取低4位元
  end
endfunction

function is_wall;
  input [4:0] x;
  input [4:0] y;
  integer k;
  begin
    is_wall = 0;
    for (k=0; k<NUM_WALLS; k=k+1) begin
      if (wall_x[k] == x && wall_y[k] == y)
        is_wall = 1;
    end
  end
endfunction


reg [4:0] apple_x;
reg [4:0] apple_y;
reg [4:0] candidate_x;
reg [4:0] candidate_y;

reg [5:0] attempt_count; // 用來計數嘗試次數(0~50)
reg found_apple_place;
reg apple_req_new;   // 當蛇吃到蘋果後拉高此flag，要求重新尋找位置

// 狀態機: IDLE、TRYING、DONE
localparam [1:0] S_IDLE   = 2'd0,
                 S_TRYING = 2'd1,
                 S_DONE   = 2'd2;

reg [1:0] apple_state;

always @(posedge clk or negedge reset_n) begin
  if (~reset_n) begin
    maxscore <= 10'd0;  
  end else if(score > maxscore) begin
    maxscore <= score;
  end
end

always @(posedge clk or negedge reset_n) begin
  if (~reset_n) begin
    current_length <= 5;
    score <= 1;
    apple_x <= 5'd2;
    apple_y <= 5'd7;
    apple_state <= S_IDLE;
    found_apple_place <= 0;
    apple_req_new <= 0;
    attempt_count <= 0;
  end else begin
    // 如果蛇吃到蘋果，觸發尋找新蘋果位置
    if (move_tick && snake_x[0] == apple_x && snake_y[0] == apple_y && apple_state == S_IDLE) begin
      score <= score + 10'd1;
      if(current_length <10)
        current_length <= current_length + 1;
      apple_req_new <= 1; // 要求新蘋果位置
    end else if(move_tick && is_wall(snake_x[0],snake_y[0])==1 && game_started) begin
      if(score > 0) begin
        score <= score - 10'd1;
         if(current_length >4)
            current_length <= current_length - 1;
      end
    end else if(game_started == 0) begin
      score <= maxscore;
    end
    case(apple_state)
      S_IDLE: begin
        if (apple_req_new) begin
          // 初始化嘗試
          candidate_x <= get_random_x(lfsr);
          candidate_y <= get_random_y(lfsr);
          found_apple_place <= 0;
          attempt_count <= 0;
          apple_state <= S_TRYING;
          apple_req_new <= 0;
        end
      end

      S_TRYING: begin
        // 每個clock週期嘗試一個位置
        if (is_wall(candidate_x, candidate_y)) begin
          // 若是牆，重新取亂數座標
          candidate_x <= get_random_x({lfsr[7:0], lfsr[15:8]});
          candidate_y <= get_random_y({lfsr[15:8], lfsr[7:0]});
          attempt_count <= attempt_count + 1;
          if (attempt_count >= 50) begin
            // 超過50次依然找不到非牆區域，就接受此最後座標(理論上不會發生)
            apple_x <= candidate_x;
            apple_y <= candidate_y;
            found_apple_place <= 1;
          end
        end else begin
          // 找到非牆位置
          apple_x <= candidate_x;
          apple_y <= candidate_y;
          found_apple_place <= 1;
        end
        // 若已找到位置或超時
        if (found_apple_place || attempt_count >= 50) begin
          apple_state <= S_DONE;
        end
      end

      S_DONE: begin
        // 完成蘋果位置分配後返回IDLE
        apple_state <= S_IDLE;
      end

      default: apple_state <= S_IDLE;
    endcase
  end
end

reg [17:0] sram_addr_score_reg1;
reg [17:0] sram_addr_score_reg2;
reg [17:0] sram_addr_apple_reg;

always @(*) begin
    if((mem_x >= VBUF_W - 30) && (mem_x < VBUF_W - 15) && (mem_y < 30)) begin
        sram_addr_score_reg2 =  ((score)/10)*450 + mem_y*15 + (mem_x - (VBUF_W - 30));  
    end else begin
        sram_addr_score_reg2 = 0;
    end

    // 計算score的顯示位置 (例如顯示在右上角15x30範圍)
    if((mem_x >= VBUF_W - 15) && (mem_x < VBUF_W) && (mem_y < 30)) begin
        sram_addr_score_reg1 = ((score)%10)*450 + mem_y*15 + (mem_x - (VBUF_W - 15));
    end else begin
        sram_addr_score_reg1 = 0;
    end
    // 計算apple的顯示位置 (例如整個15x15的蘋果)
    if((mem_x >= apple_x*CELL_W) && (mem_x < (apple_x+1)*CELL_W) &&
       (mem_y >= apple_y*CELL_H) && (mem_y < (apple_y+1)*CELL_H)) begin
        sram_addr_apple_reg = 450 + (mem_y - apple_y*CELL_H)*CELL_W + (mem_x - apple_x*CELL_W);
    end else begin
        sram_addr_apple_reg = 0;
    end
end
assign sram_addr_score1 = sram_addr_score_reg1;
assign sram_addr_score2 = sram_addr_score_reg2;
assign sram_addr_apple = sram_addr_apple_reg;
// =============================================================================
// VGA color output
// =============================================================================
reg [11:0] rgb_reg;
reg [11:0] rgb_next;

assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;
always @(posedge clk) begin
  if(pixel_tick)
    rgb_reg <= rgb_next;
end
wire [3:0] R = data_out_bkg[11:8];
    wire [3:0] G = data_out_bkg[7:4];
    wire [3:0] B = data_out_bkg[3:0];
    localparam ADD_AMOUNT = 3; // 增加量
    localparam SUB_AMOUNT = 3; // 減少量
    wire [5:0] R_ext = R;
    wire [5:0] G_ext = G;
    wire [5:0] B_ext = B;
    // 擴展位元寬度以防溢出
    wire [5:0] R_mult = R * 3;  // 4位元 * 3 = 6位元
    wire [6:0] G_mult = G * 6;  // 4位元 * 6 = 7位元
    wire [6:0] B_mult = B * 1;  // 4位元 * 1 = 7位元 (擴展為7位元)
    // 計算總和
    wire [7:0] gray_sum = R_mult + G_mult + B_mult; // 6 + 7 + 7 = 8位元
    //wire [3:0] gray = (gray_sum * 8'd26) >> 8; // 26/256 ≈ 0.1015625 ≈ 1/10
    wire [3:0] gray = (gray_sum > 8'd150) ? 4'd15 :
                      (gray_sum > 8'd135) ? 4'd14 :
                      (gray_sum > 8'd120) ? 4'd13 :
                      (gray_sum > 8'd105) ? 4'd12 :
                      (gray_sum > 8'd90)  ? 4'd11 :
                      (gray_sum > 8'd75)  ? 4'd10 :
                      (gray_sum > 8'd60)  ? 4'd9  :
                      (gray_sum > 8'd45)  ? 4'd8  :
                      (gray_sum > 8'd30)  ? 4'd7  :
                      (gray_sum > 8'd20)  ? 4'd6  :
                      (gray_sum > 8'd15)  ? 4'd5  :
                      (gray_sum > 8'd10)  ? 4'd4  :
                      (gray_sum > 8'd5)   ? 4'd3  :
                      (gray_sum > 8'd2)   ? 4'd2  :
                      (gray_sum > 8'd1)   ? 4'd1  :
                                            4'd0;
always @(*) begin
  if(~video_on)
    rgb_next = 12'h000;
  else if(snake_found && data_out_snake != 12'h0f0)
    rgb_next = data_out_snake;
  else if((mem_x >= apple_x*CELL_W) && (mem_x < (apple_x+1)*CELL_W) &&        //有改的地方
       (mem_y >= apple_y*CELL_H) && (mem_y < (apple_y+1)*CELL_H) && data_out_apple != 12'h0f0)
    rgb_next = data_out_apple; 
  else if((mem_x >= VBUF_W - 30) && (mem_x < VBUF_W-15) && (mem_y < 30) && data_out_score2 != 12'h0f0)
    rgb_next = data_out_score2;
  else if((mem_x >= VBUF_W - 15) && (mem_x < VBUF_W) && (mem_y < 30) && data_out_score1 != 12'h0f0)
    rgb_next = data_out_score1;
  else if(mem_x < VBUF_W && mem_y < VBUF_H && (score)<=2)
    rgb_next = data_out_bkg;
  else if(mem_x < VBUF_W && mem_y < VBUF_H && (score)<=3)
    rgb_next = {gray, gray, gray};
  else if(mem_x < VBUF_W && mem_y < VBUF_H && (score)<=4)
    rgb_next = {(R + ADD_AMOUNT > 4'd15) ? 4'd15 : R + ADD_AMOUNT,
    (G + ADD_AMOUNT > 4'd15) ? 4'd15 : G + ADD_AMOUNT, 
    (B < SUB_AMOUNT) ? 4'd0 : B- SUB_AMOUNT};
  else if(mem_x < VBUF_W && mem_y < VBUF_H && (score)<=5)
    rgb_next = {gray, gray, gray};
  else if(mem_x < VBUF_W && mem_y < VBUF_H && (score)<=6)
    rgb_next = {(R < SUB_AMOUNT) ? 4'd0 : R - SUB_AMOUNT,
    (G + ADD_AMOUNT > 4'd15) ? 4'd15 : G + ADD_AMOUNT, 
    (B < SUB_AMOUNT) ? 4'd0 : B - SUB_AMOUNT};
  else if(mem_x < VBUF_W && mem_y < VBUF_H && (score)<=7)
    rgb_next = data_out_bkg + 12'h770 - 12'h005;
  else if(mem_x < VBUF_W && mem_y < VBUF_H && (score)<=8)
    rgb_next = data_out_bkg + 12'h005 -12'h770;
  else if(mem_x < VBUF_W && mem_y < VBUF_H && (score)>8)
    rgb_next = {(R < SUB_AMOUNT) ? 4'd0 : R - SUB_AMOUNT,
          (G + ADD_AMOUNT > 4'd15) ? 4'd15 : G + ADD_AMOUNT,
          (B + ADD_AMOUNT > 4'd15) ? 4'd15 : B + ADD_AMOUNT};
  else
    rgb_next = 12'h000;
end

assign usr_led = 4'b0000;

endmodule