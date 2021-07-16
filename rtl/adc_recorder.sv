// only one byte of ADC data will be written each eoc_out

module adc_recorder
#( parameter ADDR_BITS = 16 )
( input  logic                 clk,
  input  logic                 rst_n,
  input  logic                 cfg_adc_record_en, // this is already a self-clearing trigger
  input  logic                 btn_adc_record_en,
  input  logic                 cfg_adc_enable,
  input  logic                 adc_eoc_out,
  output logic                 adc_trigger,
  output logic [ADDR_BITS-1:0] adc_addr,
  output logic                 adc_write_enable
 );
  
  logic cfg_adc_enable_hold;
  logic enable_redge;
  logic btn_adc_record_en_hold;
  logic btn_enable_redge;
  logic adc_eoc_out_delay;
  logic first_trigger;
  
  always_ff @(posedge clk, negedge rst_n)
    if (~rst_n) adc_eoc_out_delay <= 1'b0;
    else        adc_eoc_out_delay <= adc_eoc_out;
  
  assign adc_write_enable = adc_eoc_out && (!adc_eoc_out_delay);
  
  always_ff @(posedge clk, negedge rst_n)
    if (~rst_n) cfg_adc_enable_hold <= 1'b0;
    else        cfg_adc_enable_hold <= cfg_adc_enable;
      
  assign enable_redge = cfg_adc_enable && (!cfg_adc_enable_hold);
  
  always_ff @(posedge clk, negedge rst_n)
    if (~rst_n) btn_adc_record_en_hold <= 1'b0;
    else        btn_adc_record_en_hold <= btn_adc_record_en;
  
  assign btn_enable_redge = btn_adc_record_en && (!btn_adc_record_en_hold);
  
  //flag to capture the first trigger until the delayed EOC goes high, as the trigger bits self clear
  always_ff @(posedge clk, negedge rst_n)
    if (~rst_n)                                                     first_trigger <= 1'b0;
    else if (enable_redge || cfg_adc_record_en || btn_enable_redge) first_trigger <= 1'b1;
    else if (first_trigger && adc_eoc_out_delay)                    first_trigger <= 1'b0;
  
  // need address term to keep triggering until bram is full
  assign adc_trigger = ((cfg_adc_enable || first_trigger || (adc_addr > 0)) && adc_eoc_out_delay) || enable_redge || cfg_adc_record_en || btn_enable_redge;
  
  // adc_addr only counts with a trigger source, not with the cfg_adc_enable level
  always_ff @(posedge clk, negedge rst_n)
    if (~rst_n)                                    adc_addr <= '0;
    else if (first_trigger   && adc_eoc_out_delay) adc_addr <= 1;
    else if ((adc_addr > 0 ) && adc_eoc_out_delay) adc_addr <= adc_addr + 1; // overflow expected

endmodule
