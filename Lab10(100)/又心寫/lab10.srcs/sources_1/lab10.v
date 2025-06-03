`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai 
// 
// Create Date: 2018/12/11 16:04:41
// Design Name: 
// Module Name: lab9
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A circuit that show the animation of a fish swimming in a seabed
//              scene on a screen through the VGA interface of the Arty I/O card.
// 
// Dependencies: vga_sync, clk_divider, sram 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
reg  [31:0] f1_clk,f2_clk,f3_clk;
wire [9:0]  pos_f1,pos_f2,pos_f3;
wire        f1_region,f2_region,f3_region;

// declare SRAM control signals
wire [16:0] sram_addr_bkg,sram_addr_f1,sram_addr_f2,sram_addr_f3;
wire [11:0] data_in;
wire [11:0] data_out_bkg,data_out_f1,data_out_f2,data_out_f3;
wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [17:0] pixel_addr_bkg,pixel_addr_f1,pixel_addr_f2,pixel_addr_f3;

// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam F1_VPOS  = 64; // Vertical location of the fish in the sea image.
localparam FISH_W      = 64; // Width of the fish.
localparam FISH_H      = 32; // Height of the fish.
localparam FISH_H2      = 44;
localparam FISH_H3=72;
localparam F2_VPOS   = 100; 
localparam F3_VPOS   = 150;
reg [17:0] f1_addr[0:7];   // Address array for up to 8 fish images.
reg [17:0] f2_addr[0:3];
reg [17:0] f3_addr[0:3];
// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(
initial begin
  f1_addr[0] = VBUF_W*VBUF_H + 18'd0;         /* Addr for fish image #1 */
  f1_addr[1] = VBUF_W*VBUF_H + FISH_W*FISH_H; /* Addr for fish image #2 */
  f1_addr[2] = VBUF_W*VBUF_H + FISH_W*FISH_H*2;
  f1_addr[3] = VBUF_W*VBUF_H + FISH_W*FISH_H*3; 
  f1_addr[4] = VBUF_W*VBUF_H + FISH_W*FISH_H*4;
  f1_addr[5] = VBUF_W*VBUF_H + FISH_W*FISH_H*5;
  f1_addr[6] = VBUF_W*VBUF_H + FISH_W*FISH_H*6;
  f1_addr[7] = VBUF_W*VBUF_H + FISH_W*FISH_H*7;

  f2_addr[0] = 0;         
  f2_addr[1] = FISH_W*FISH_H2; 
  f2_addr[2] = FISH_W*FISH_H2*2; 
  f2_addr[3] = FISH_W*FISH_H2*3; 

  f3_addr[0] = FISH_W*FISH_H2*4;
  f3_addr[1] = FISH_W*FISH_H2*4 + FISH_W*FISH_H3*1;
  f3_addr[2] = FISH_W*FISH_H2*4 + FISH_W*FISH_H3*2;
  f3_addr[3] = FISH_W*FISH_H2*4 + FISH_W*FISH_H3*3;
end

// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H+FISH_W*FISH_H*8),.FILE_NAME("bkg_fish1.mem"))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr1(sram_addr_bkg), .data_i1(data_in), .data_o1(data_out_bkg),
          .addr2(sram_addr_f1), .data_i2(data_in), .data_o2(data_out_f1));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W*FISH_H2*4+FISH_W*FISH_H3*4),.FILE_NAME("23fish.mem"))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr1(sram_addr_f2), .data_i1(data_in), .data_o1(data_out_f2),
          .addr2(sram_addr_f3), .data_i2(data_in), .data_o2(data_out_f3));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr_bkg = pixel_addr_bkg;
assign sram_addr_f1 = pixel_addr_f1;
assign sram_addr_f2 = pixel_addr_f2;
assign sram_addr_f3 = pixel_addr_f3;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
reg f1_dir;  //0向右 1向左
reg f1_flip; 

assign pos_f1 = f1_clk[31:20]; // the x position of the right edge of the fish image
always @(posedge clk) begin
  if (~reset_n) begin
    f1_clk <= 32'h000fffff; 
    f1_dir <= 0;       
    f1_flip <= 0;
  end
  else begin
    if (f1_dir == 0) begin

      if (f1_clk[31:21] >= VBUF_W) begin
        f1_dir <= 1; 
        f1_flip <= 1;  
      end
      else begin
        f1_clk <= f1_clk + 1; 
      end
    end
    else begin
      if (f1_clk[31:21]-FISH_W == 0) begin
        f1_dir <= 0;
        f1_flip <= 0;  
      end
      else begin
        f1_clk <= f1_clk - 1; 
      end
    end
  end
end

reg f2_dir;  
reg f2_flip;  

assign pos_f2 = f2_clk[31:20]; // the x position of the right edge of the fish image
always @(posedge clk) begin
  if (~reset_n) begin
    f2_clk <= 32'h000fffff; 
    f2_dir <= 0;           
    f2_flip <= 0;
  end
  else begin
    if (f2_dir == 0) begin
      if (f2_clk[31:21] >= VBUF_W) begin
        f2_dir <= 1;
        f2_flip <= 1;
      end
      else begin
        f2_clk <= f2_clk + 1; 
      end
    end
    else begin
      if (f2_clk[31:21]-FISH_W == 0) begin
        f2_dir <= 0;  
        f2_flip <= 0;
      end
      else begin
        f2_clk <= f2_clk - 1; 
      end
    end
  end
end
reg f3_dir;
reg f3_flip;

assign pos_f3 = f3_clk[31:20]; // the x position of the right edge of the fish image
always @(posedge clk) begin
  if (~reset_n) begin
    f3_clk <= 32'h000fffff; 
    f3_dir <= 0;       
    f3_flip <= 1;
  end
  else begin
    if (f3_dir == 0) begin
      if (f3_clk[31:21] >= VBUF_W) begin
        f3_dir <= 1; 
        f3_flip <= 1;
      end
      else begin
        f3_clk <= f3_clk + 2;  
      end
    end
    else begin
      if (f3_clk[31:21]-FISH_W == 0) begin
        f3_dir <= 0; 
        f3_flip <= 0;
      end
      else begin
        f3_clk <= f3_clk - 2; 
      end
    end
  end
end


// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
assign f1_region =
           pixel_y >= (f1_v[31:22]<<1) && pixel_y < (f1_v[31:22]+FISH_H)<<1 &&
           (pixel_x + 127) >= pos_f1 && pixel_x < pos_f1 + 1;
assign f2_region =
           pixel_y >= ((f2_v[31:22])<<1) && pixel_y < ((f2_v[31:22])+FISH_H2)<<1 &&
           (pixel_x + 127) >= pos_f2 && pixel_x < pos_f2 + 1;
assign f3_region =
           pixel_y >= (f3_v[31:22]<<1) && pixel_y < (f3_v[31:22]+FISH_H3)<<1 &&
           (pixel_x + 127) >= pos_f3 && pixel_x < pos_f3 + 1;

always @ (posedge clk) begin
  if (~reset_n)begin
    pixel_addr_bkg <= 0;
    pixel_addr_f1<=0;
    pixel_addr_f2<=0;
    pixel_addr_f3<=0;
  end
  else begin
    if (f1_region) begin
      if (!f1_flip)
        pixel_addr_f1 <= f1_addr[f1_clk[25:23]] +
                    ((pixel_y>>1)-f1_v[31:22])*FISH_W +
                    ((pixel_x +(FISH_W*2-1)-pos_f1)>>1);
      else
        pixel_addr_f1 <= f1_addr[f1_clk[25:23]] +
                    ((pixel_y>>1)-f1_v[31:22])*FISH_W +
                    (FISH_W-1-((pixel_x +(FISH_W*2-1)-pos_f1)>>1));
    end
    else pixel_addr_f1<=f1_addr[0];

    if (f2_region) begin
      if (!f2_flip)
        pixel_addr_f2 <= f2_addr[f2_clk[25:23]%4] +
                    ((pixel_y>>1)-f2_v[31:22])*FISH_W +
                    ((pixel_x +(FISH_W*2-1)-pos_f2)>>1);
      else
        pixel_addr_f2 <= f2_addr[f2_clk[25:23]%4] +
                    ((pixel_y>>1)-f2_v[31:22])*FISH_W +
                    (FISH_W-1-((pixel_x +(FISH_W*2-1)-pos_f2)>>1));
    end
    else pixel_addr_f2<=f2_addr[0];

    if (f3_region) begin
      if (f3_flip)
        pixel_addr_f3 <= f3_addr[f3_clk[25:23]%4] +
                    ((pixel_y>>1)-f3_v[31:22])*FISH_W +
                    ((pixel_x +(FISH_W*2-1)-pos_f3)>>1);
      else
        pixel_addr_f3 <= f3_addr[f3_clk[25:23]%4] +
                    ((pixel_y>>1)-f3_v[31:22])*FISH_W +
                    (FISH_W-1-((pixel_x +(FISH_W*2-1)-pos_f3)>>1));
    end
    else pixel_addr_f3<=f3_addr[0];

    pixel_addr_bkg <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
  end
end
// End of the AGU code.
// ------------------------------------------------------------------------



reg [31:0] f1_v,f2_v,f3_v;
reg f1_vdir, f2_vdir, f3_vdir;  //0向下 1向上

always @(posedge clk) begin
    if (~reset_n) begin
        f1_v <= {F1_VPOS, 22'b0}; 
        f1_vdir <= 0;           
    end
    else begin
        if (f1_vdir == 0) begin
            if (f1_v[31:22] >= VBUF_H-FISH_H) begin
                f1_vdir <= 1;
            end
            else begin
                f1_v <= f1_v + 1;
            end
        end
        else begin
            if (f1_v[31:22] <= 0) begin
                f1_vdir <= 0; 
            end
            else begin
                f1_v <= f1_v - 1; 
            end
        end
    end
end

always @(posedge clk) begin
    if (~reset_n) begin
        f2_v <= {F2_VPOS, 22'b0};
        f2_vdir <= 0;
    end
    else begin
        if (f2_vdir == 0) begin
            if (f2_v[31:22] >= VBUF_H-FISH_H2) begin
                f2_vdir <= 1;
            end
            else begin
                f2_v <= f2_v + 1;
            end
        end
        else begin
            if (f2_v[31:22] <= 0) begin
                f2_vdir <= 0;
            end
            else begin
                f2_v <= f2_v - 1;
            end
        end
    end
end

always @(posedge clk) begin
    if (~reset_n) begin
        f3_v <= {F3_VPOS, 22'b0};
        f3_vdir <= 0;
    end
    else begin
        if (f3_vdir == 0) begin
            if (f3_v[31:22] >= VBUF_H-FISH_H3) begin
                f3_vdir <= 1;
            end
            else begin
                f3_v <= f3_v + 1;
            end
        end
        else begin
            if (f3_v[31:22] <= 0) begin
                f3_vdir <= 0;
            end
            else begin
                f3_v <= f3_v - 1;
            end
        end
    end
end

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else if(data_out_f1!=12'h0f0)begin
    rgb_next = data_out_f1; // RGB value at (pixel_x, pixel_y)
  end
  else if(data_out_f2!=12'h0f0)begin
    rgb_next = data_out_f2; // RGB value at (pixel_x, pixel_y)
  end
    else if(data_out_f3!=12'h0f0)begin
    rgb_next = data_out_f3; // RGB value at (pixel_x, pixel_y)
  end
  else rgb_next=data_out_bkg;
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
