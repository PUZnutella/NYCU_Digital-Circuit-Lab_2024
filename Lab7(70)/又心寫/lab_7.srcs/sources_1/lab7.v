`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of CS, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2018/10/10 16:10:38
// Design Name: UART I/O example for Arty
// Module Name: lab6
// Project Name: 
// Target Devices: Xilinx FPGA @ 100MHz
// Tool Versions: 
// Description: 
// 
// The parameters for the UART controller are 9600 baudrate, 8-N-1-N
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab6(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  input  uart_rx,
  output uart_tx,
    // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;
localparam INIT_DELAY = 100_000; // 1 msec @ 100 MHz

localparam MSG_STR= 0;  // starting index of the prompt message
//localparam MSG_LEN = 201; 
localparam MSG_LEN = 349-90-60; 
localparam MEM_SIZE=MSG_LEN;


// declare system variables
//wire enter_pressed;
wire print_enable, print_done;
reg [$clog2(MEM_SIZE):0] send_counter;
reg [4:0] P, P_next;
reg [1:0] Q, Q_next;
reg [$clog2(INIT_DELAY):0] init_counter;
reg [7:0] data[0:MEM_SIZE-1];


reg [0:MSG_LEN*8-1] MSG = {
    "\015\012The matrix operation result is:\015\012",
    "[#####,#####,#####,#####,#####]\015\012",
    "[#####,#####,#####,#####,#####]\015\012",
    "[#####,#####,#####,#####,#####]\015\012",
    "[#####,#####,#####,#####,#####]\015\012",
    "[#####,#####,#####,#####,#####]\015\012", 8'h00
};/*
reg  [0:MSG_LEN*8-1] MSG = {"\015\012The matrix operation result is:\015\012",
"[00000,00000,00000,00000,00000]\015\012",
"[00000,00000,00000,00000,00000]\015\012",
"[00000,00000,00000,00000,00000]\015\012",
"[00000,00000,00000,00000,00000]\015\012",
"[00000,00000,00000,00000,00000]\015\012", 8'h00 };
*/
// declare UART signals
wire transmit;
wire received;
wire [7:0] rx_byte;
reg  [7:0] rx_temp;  // if recevied is true, rx_temp latches rx_byte for ONLY ONE CLOCK CYCLE!
wire [7:0] tx_byte;
wire [7:0] echo_key; // keystrokes to be echoed to the terminal
wire is_num_key;
wire is_receiving;
wire is_transmitting;
wire recv_error;

/* The UART device takes a 100MHz clock to handle I/O at 9600 baudrate */
uart uart(
  .clk(clk),
  .rst(~reset_n),
  .rx(uart_rx),
  .tx(uart_tx),
  .transmit(transmit),
  .tx_byte(tx_byte),
  .received(received),
  .rx_byte(rx_byte),
  .is_receiving(is_receiving),
  .is_transmitting(is_transmitting),
  .recv_error(recv_error)
);



// declare system variables
wire [1:0]  btn_level, btn_pressed;
reg  [1:0]  prev_btn_level;
reg  [11:0] user_addr;
reg  [7:0]  user_data;
wire setaddr_done;
reg  [127:0] row_A, row_B;
reg [20-1:0] pooled_A[4:0][4:0];
reg [20-1:0] pooled_B[4:0][4:0];

// declare SRAM control signals
wire [10:0] sram_addr;
wire [7:0]  data_in;
wire [7:0]  data_out;
wire        sram_we, sram_en;

//assign usr_led = 4'h00;
assign usr_led = P;
  
debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);



//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 2'b00;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level & ~prev_btn_level);

// ------------------------------------------------------------------------
// The following code creates an initialized SRAM memory block that
// stores an 1024x8-bit unsigned numbers.
sram ram0(.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However,
                             // if you set 'we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = (P == S_MAIN_ADDR || P == S_MAIN_READ); // Enable the SRAM block.
assign sram_addr = user_addr[11:0];
assign data_in = 8'b0; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the main controller
always @(posedge clk) begin
  if (~reset_n) begin
    P <= S_MAIN_INIT; // read samples at 000 first
  end
  else begin
    P <= P_next;
  end
end
always @(posedge clk) begin
    if (~reset_n || P == S_MAIN_INIT) begin
        read_cnt <= 0;
    end
    else if (P == S_MAIN_READ) begin
        if (read_cnt < 98) begin
            read_cnt <= read_cnt + 1;
        end
    end
end
reg [5:0]mul_wait_cnt;

reg [6:0] read_cnt;
localparam [4:0] S_MAIN_INIT = 4'b0001, 
                 S_MAIN_ADDR = 4'b0010, 
                 S_MAIN_WAIT = 4'b0011, 
                 S_MAIN_WAIT_EXTRA = 4'b0100, 
                 S_MAIN_READ = 4'b0101, 
                 S_MAIN_SHOW = 4'b0110,
                 S_MAIN_POOL_A = 4'b0111, 
                 S_MAIN_POOL_B = 4'b1000,
                 S_MAIN_MUL = 4'b1001;

wire pool_a_done,pool_b_done,mul_done;

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // Wait for initial delay of the circuit.
        if (init_counter < INIT_DELAY) P_next = S_MAIN_INIT;
        else begin
             if (btn_pressed[1]) P_next = S_MAIN_ADDR;
             else P_next = S_MAIN_INIT;
        end
    S_MAIN_ADDR:
            P_next = S_MAIN_WAIT; 
    S_MAIN_WAIT:
            P_next = S_MAIN_WAIT_EXTRA; 
    S_MAIN_WAIT_EXTRA:
            if (wait_counter == 15) 
                P_next = S_MAIN_READ;
            else
                P_next = S_MAIN_WAIT_EXTRA;
    S_MAIN_READ: // fetch the sample from the SRAM
        if(read_cnt<97) P_next=S_MAIN_ADDR;
        else P_next=S_MAIN_POOL_A;
    S_MAIN_POOL_A:
        if(pool_a_done) P_next=S_MAIN_POOL_B;
        else P_next=S_MAIN_POOL_A;
    S_MAIN_POOL_B:
        if(pool_b_done) P_next=S_MAIN_MUL;
        else P_next=S_MAIN_POOL_B;
    S_MAIN_MUL:
            if(mul_A_done) 
                P_next = S_MAIN_SHOW;
            else 
                P_next = S_MAIN_MUL;
    S_MAIN_SHOW:
        P_next=S_MAIN_INIT;
    
  endcase
end

//read
reg [5:0] wait_counter,waitt; // 2-bit counter for additional delay

always @(posedge clk) begin
    if (P == S_MAIN_WAIT_EXTRA) begin
        wait_counter <= wait_counter + 1;
    end else begin
        wait_counter <= 0;
    end
end

always @(posedge clk) begin
    if (P == S_MAIN_MUL) begin
        waitt<= waitt + 1;
    end else begin
        waitt <= 0;
    end
end

integer rowa,ca,rowb,cb;
reg out_into_mat_cnt;
reg [7*8-1:0] mat_A[6:0];
reg [7*8-1:0] mat_B[6:0];
reg [20-1:0] result [4:0][4:0];
always @(posedge clk) begin
    if(~reset_n||P == S_MAIN_INIT)begin
        mat_A[0] <= 0;
        mat_A[1] <= 0;
        mat_A[2] <= 0;
        mat_A[3] <= 0;
        mat_A[4] <= 0;
        mat_A[5] <= 0;
        mat_A[6] <= 0;
        mat_B[0] <= 0;
        mat_B[1] <= 0;
        mat_B[2] <= 0;
        mat_B[3] <= 0;
        mat_B[4] <= 0;
        mat_B[5] <= 0;
        mat_B[6] <= 0;
        rowa<=0;
        rowb<=0;
        ca<=0;
        cb<=0;
         user_addr<=0;
    end

    else if (P == S_MAIN_ADDR) begin
        if (user_addr<49) begin
            // 填入 mat_A
            mat_A[rowa][(ca+1)*8-1 -: 8] <= data_out;
            ca <= ca + 1;
            if (ca == 6) begin
                ca <= 0;
                rowa <= rowa + 1;
                
            end
            user_addr<=user_addr+1;
        end
        else if (user_addr < 98) begin
            // 填入 mat_B
            mat_B[rowb][(cb+1)*8-1 -: 8] <= data_out;
            cb <= cb + 1;
            if (cb == 6) begin
                cb <= 0;
                rowb <= rowb + 1;
            end
            user_addr<=user_addr+1;
        end
    end
end
reg eightto20;
assign pool_a_done=~(rowaa<=4);
reg [8:0] ecnt;
assign pool_b_done=~(rowbb<=4);
reg [3:0] rowaa,rowbb,caa,cbb;
always @(posedge clk) begin
    if (~reset_n || P == S_MAIN_INIT) begin
        eightto20<=0;
        rowaa <= 0;
        rowbb<=0;
        caa<=0;
        ecnt<=0;
        cbb<=0;
    end
    else if (P == S_MAIN_POOL_A && ~pool_a_done) begin
        if (rowaa <=4) begin
            if (caa <= 4) begin
                pooled_A[caa][rowaa]<= max_3x3(
                    mat_A[rowaa][caa*8+:8],       // 左上
                    mat_A[rowaa][(caa+1)*8+:8],  // 上中
                    mat_A[rowaa][(caa+2)*8+:8],   // 右上
                    mat_A[rowaa+1][caa*8+:8], // 左中
                    mat_A[rowaa+1][(caa+1)*8+:8], // 中心
                    mat_A[rowaa+1][(caa+2)*8+:8], // 右中
                    mat_A[rowaa+2][caa*8+:8],     // 左下
                    mat_A[rowaa+2][(caa+1)*8+:8], // 下中
                    mat_A[rowaa+2][(caa+2)*8+:8]  // 右下
                );
                caa <= caa + 1;
                end
                else begin
                    caa <= 0;
                    rowaa<= rowaa + 1;
                end 
        end
    end
    else if (P == S_MAIN_POOL_B&&~pool_b_done) begin
        if (rowbb <= 4) begin
            if (cbb <=4) begin
                pooled_B[rowbb][cbb]<= max_3x3(
                    mat_B[rowbb][cbb*8+:8],       // 左上
                    mat_B[rowbb][(cbb+1)*8+:8],  // 上中
                    mat_B[rowbb][(cbb+2)*8+:8],   // 右上
                    mat_B[rowbb+1][cbb*8+:8], // 左中
                    mat_B[rowbb+1][(cbb+1)*8+:8], // 中心
                    mat_B[rowbb+1][(cbb+2)*8+:8], // 右中
                    mat_B[rowbb+2][cbb*8+:8],     // 左下
                    mat_B[rowbb+2][(cbb+1)*8+:8], // 下中
                    mat_B[rowbb+2][(cbb+2)*8+:8]  // 右下
                );
                
                cbb <= cbb + 1;
                end
            else begin
                    cbb <= 0;
                    rowbb <= rowbb + 1;
            end
        end
    end
end

// mul
reg muling, adding;
reg [20-1:0] multmp [4:0];
wire mul_A_done;
assign mul_A_done = (mul_row == 4 && mul_col == 5);

reg [5:0] mul_row, mul_col;
always @(posedge clk) begin
    if (~reset_n || P == S_MAIN_INIT) begin
        muling <= 1;
        adding <= 0;
        mul_col <= 0;
        mul_row <= 0;
    end
    else if (P == S_MAIN_MUL && muling) begin

        multmp[0] <= pooled_A[mul_row][0] * pooled_B[0][mul_col];
        multmp[1] <= pooled_A[mul_row][1] * pooled_B[1][mul_col];
        multmp[2] <= pooled_A[mul_row][2] * pooled_B[2][mul_col];
        multmp[3] <= pooled_A[mul_row][3] * pooled_B[3][mul_col];
        multmp[4] <= pooled_A[mul_row][4] * pooled_B[4][mul_col];

        muling <= 0;
        adding <= 1;
    end
    else if (P == S_MAIN_MUL && adding) begin
        result[mul_row][mul_col] <= multmp[0] + multmp[1] + multmp[2] + multmp[3] + multmp[4];

        if (mul_col < 4) begin
            mul_col <= mul_col + 1;
        end else if (mul_row < 4) begin
            mul_col <= 0;
            mul_row <= mul_row + 1;
        end else begin
          mul_col <= mul_col + 1;
        end
        muling <= 1;
        adding <= 0;
    end
end
//show
integer i,j;
always @(posedge clk) begin
    if (~reset_n) begin
        for (i = 0; i < MSG_LEN; i = i + 1)   data[i] = MSG[i*8 +: 8];
    end
    else if (P == S_MAIN_SHOW) begin
        
        for(i = 0; i < 5; i = i + 1) begin
            for(j = 0; j < 5; j = j + 1) begin
                data[34 + i*33 + j*6]   <= ((result[i][j][19:16]  > 9) ? "7" : "0") + result[i][j][19:16];
                data[34 + i*33 + j*6+1] <= ((result[i][j][15:12]  > 9) ? "7" : "0") + result[i][j][15:12];
                data[34 + i*33 + j*6+2] <= ((result[i][j][11:8] > 9) ? "7" : "0") +result[i][j][11:8];
                data[34 + i*33 + j*6+3] <= ((result[i][j][7:4]  > 9) ? "7" : "0") + result[i][j][7:4];
                data[34 + i*33 + j*6+4] <= ((result[i][j][3:0] > 9) ? "7" : "0") +result[i][j][3:0];
            end
        end
    end
end


// FSM output logics: print string control signals.
assign print_enable = (P != S_MAIN_SHOW && P_next == S_MAIN_SHOW);
assign print_done = (tx_byte == 8'h0);


// Initialization counter.
always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + 1;
  else init_counter <= 0;
end

// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the controller that sends a string to the UART.
always @(posedge clk) begin
  if (~reset_n) Q <= S_UART_IDLE;
  else Q <= Q_next;
end

always @(*) begin // FSM next-state logic
  case (Q)
    S_UART_IDLE: // wait for the print_string flag
      if (print_enable) Q_next = S_UART_WAIT;
      else Q_next = S_UART_IDLE;
    S_UART_WAIT: // wait for the transmission of current data byte begins
      if (is_transmitting == 1) Q_next = S_UART_SEND;
      else Q_next = S_UART_WAIT;
    S_UART_SEND: // wait for the transmission of current data byte finishes
      if (is_transmitting == 0) Q_next = S_UART_INCR; // transmit next character
      else Q_next = S_UART_SEND;
    S_UART_INCR:
      if (tx_byte == 8'h0) Q_next = S_UART_IDLE; // string transmission ends
      else Q_next = S_UART_WAIT;
  endcase
end

// FSM output logics: UART transmission control signals
assign transmit = (Q_next == S_UART_WAIT ||
                  (P==S_MAIN_SHOW && received) ||
                   print_enable);
//assign is_num_key = (rx_byte > 8'h2F) && (rx_byte < 8'h3A) && (key_cnt < 5);
assign echo_key = (is_num_key || rx_byte == 8'h0D)? rx_byte : 0;
assign tx_byte  = (P==S_MAIN_SHOW && received)? echo_key : data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
  case (P_next)
    S_MAIN_READ: send_counter <= MSG_STR;
    S_MAIN_SHOW: send_counter <= MSG_STR;
    default: send_counter <= send_counter + (Q_next == S_UART_INCR);
  endcase
end


// The following logic stores the UART input in a temporary buffer.
// The input character will stay in the buffer for one clock cycle.
always @(posedge clk) begin
  rx_temp <= (received)? rx_byte : 8'h0;
end

function [7:0] max_3x3;
    input [7:0] d0, d1, d2, 
                d3, d4, d5, 
                d6, d7, d8; 
    reg [7:0] max;
    begin
        max = d0;
        if (d1 > max) max = d1;
        if (d2 > max) max = d2;
        if (d3 > max) max = d3;
        if (d4 > max) max = d4;
        if (d5 > max) max = d5;
        if (d6 > max) max = d6;
        if (d7 > max) max = d7;
        if (d8 > max) max = d8;
        
        max_3x3 = max;
    end
endfunction

endmodule

/*
01 02 03 04 05 06 07
08 09 0A 0B 0C 0D 0E
0F 10 11 12 13 14 15
16 17 18 19 1A 1B 1C
1D 1E 1F 20 21 22 23
24 25 26 27 28 29 2A
2B 2C 2D 2E 2F 30 31

11 12 13 14 15
18 19 1A 1B 1C
1F 20 21 22 23
26 27 28 29 2A
2D 2E 2F 30 31

11 18 1F 26 2D
12 19 20 27 2E
13 1A 21 28 2F
14 1B 22 29 30
15 1C 23 2A 31
*/

