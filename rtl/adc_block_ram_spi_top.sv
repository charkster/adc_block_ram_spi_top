
module adc_block_ram_spi_top
( input  logic        clk,              // osc board clock
  input  logic        button_0,         // button
  input  logic        button_1,         // button
  input  logic        sclk,             // SPI CLK
  input  logic        ss_n,             // SPI CS_N
  input  logic        mosi,             // SPI MOSI
  output logic        miso,             // SPI MISO
  output logic        led_0,            // led, active high
  output logic        led_1,            // led, active high
  output logic        led0_b,           // tricolor blue led, active low
  output logic        led0_r,           // tricolor red led,  active low
  output logic        led0_g,           // tircolor green led, active low
  input               vauxp4,           // pin 15 analog input
  input               vauxn4,           // pin 15 analog ref
  output logic        busy              // adc busy indicator
 );

  logic  [7:0] read_data_in;
  logic  [7:0] read_data_out_adc;
  logic  [7:0] read_data_out_bram;
  logic  [7:0] data_out;
  logic        data_out_valid;
  logic        data_out_finished;
  logic  [6:0] slave_id;
  logic        rnw;
  logic        cfg_adc_enable;
  logic        cfg_adc_record_en;
  logic        clk_250mhz;
  logic        locked_250mhz;
  logic        rst_n_250mhz_sync;
  logic        eoc_out;
  logic [15:0] adc_data;
  logic        adc_ready;
  logic        adc_trigger;
  logic        reset;
  logic        bram_wen;
  logic        bram_ren;
  logic        write_enable;
  logic        adc_write_enable;
  logic [15:0] write_address;
  logic [15:0] bram_addr;
  logic [15:0] adc_addr;
  logic  [7:0] write_data;
  logic  [7:0] bram_read_data;
  logic  [7:0] bram_write_data;
  
  assign reset = button_0;
  
  assign led_0  = 1'b0;            // active high
  assign led_1  = 1'b0;            // active high
  assign led0_b = 1'b1;            // always off, tricolor active low
  assign led0_r = cfg_adc_enable;  // red when adc off, tricolor active low
  assign led0_g = ~cfg_adc_enable; // green when enabled, tricolor active low
   
  clk_wiz_0 u_clk_wiz_0
  ( .clk_out1 (clk_250mhz),
    .reset    (reset),
    .locked   (locked_250mhz),
    .clk_in1  (clk)
   );
   
  scarf u_scarf
  ( .sclk,                                 // input
    .mosi,                                 // input
    .miso,                                 // output
    .ss_n,                                 // input
    .clk              (clk_250mhz),        // input
    .rst_n            (locked_250mhz),     // input
    .read_data_in,                         // input  [7:0]
    .rst_n_sync       (rst_n_250mhz_sync), // output
    .data_out,                             // output [7:0]
    .data_out_valid,                       // output
    .data_out_finished,                    // output
    .slave_id,                             // output [6:0]
    .rnw                                   // output
   );

  scarf_regmap_adc 
  # ( .SLAVE_ID(7'h01) )
  u_scarf_regmap_adc
  ( .clk              (clk_250mhz),        // input
    .rst_n_sync       (rst_n_250mhz_sync), // input
    .data_in          (data_out),          // input [7:0]
    .data_in_valid    (data_out_valid),    // input
    .data_in_finished (data_out_finished), // input
    .slave_id,                             // input [6:0]
    .rnw,                                  // input
    .read_data_out    (read_data_out_adc), // output [7:0]
    .cfg_adc_enable,                       // output
    .cfg_adc_record_en,                    // output
    .adc_data                              // input [15:0]
   );
                
  assign read_data_in = read_data_out_adc | read_data_out_bram;
                
  xadc_wiz_0 u_xadc_wiz_0
  ( .di_in       (16'd0),              // input wire [15 : 0] di_in
    .daddr_in    (7'h14),              // input wire [6 : 0] daddr_in
    .den_in      (adc_trigger),        // input wire den_in
    .dwe_in      (1'b0),               // input wire dwe_in
    .drdy_out    (adc_ready),          // output wire drdy_out
    .do_out      (adc_data),           // output wire [15 : 0] do_out
    .dclk_in     (clk_250mhz),         // input wire dclk_in
    .reset_in    (~rst_n_250mhz_sync), // input wire reset_in
    .convst_in   (adc_trigger),        // input wire convst_in
    .vp_in       (),                   // input wire vp_in
    .vn_in       (),                   // input wire vn_in
    .vauxp4,                           // input wire vauxp4
    .vauxn4,                           // input wire vauxn4
    .channel_out (),                   // output wire [4 : 0] channel_out
    .eoc_out,                          // output wire eoc_out
    .alarm_out   (),                   // output wire alarm_out
    .eos_out     (),                   // output wire eos_out
    .busy_out    (busy)                // output wire busy_out
   );

  scarf_bram
  # ( .SLAVE_ID(7'h02) )
  u_scarf_bram
  ( .clk              (clk_250mhz),         // input
    .rst_n_sync       (rst_n_250mhz_sync),  // input
    .data_in          (data_out),           // input  [7:0]
    .data_in_valid    (data_out_valid),     // input
    .data_in_finished (data_out_finished),  // input
    .slave_id,                              // input  [6:0]
    .rnw,                                   // input
    .read_data_out    (read_data_out_bram), // output [7:0] 
    .bram_read_data,                        // input  [7:0]
    .bram_write_data,                       // output [7:0]
    .bram_addr,                             // output [15:0]
    .bram_wen,                              // output
    .bram_ren                               // output
   );

  assign write_address = (bram_wen) ? bram_addr       : adc_addr;
  assign write_data    = (bram_wen) ? bram_write_data : adc_data[11:4];

  block_ram_dual_port
  #( .RAM_WIDTH(8),
     .RAM_ADDR_BITS(16) )
  u_block_ram_dual_port
  ( .clk          (clk_250mhz),                   // input
    .write_enable (bram_wen || adc_write_enable), // input 
    .write_address,                               // input [15:0]
    .write_data,                                  // input [7:0]
    .read_enable  (bram_ren),                     // input
    .read_address (bram_addr),                    // input [15:0]
    .read_data    (bram_read_data)                // output [7:0]
   );

  adc_recorder
  #( .ADDR_BITS(16) )
  u_adc_recorder
  ( .clk               (clk_250mhz),        // input
    .rst_n             (rst_n_250mhz_sync), // input
    .cfg_adc_record_en,                     // input
    .btn_adc_record_en (button_1),          // input
    .cfg_adc_enable,                        // input
    .adc_eoc_out       (eoc_out),           // input
    .adc_trigger,                           // output
    .adc_addr,                              // output [15:0]
    .adc_write_enable                       // output
   );

endmodule