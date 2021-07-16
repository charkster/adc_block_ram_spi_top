
module scarf_regmap_adc
  ( input  logic        clk,
    input  logic        rst_n_sync,
    input  logic  [7:0] data_in,
    input  logic        data_in_valid,
    input  logic        data_in_finished,
    input  logic  [6:0] slave_id,
    input  logic        rnw,
    output logic  [7:0] read_data_out,
    output logic        cfg_adc_enable,
    output logic        cfg_adc_record_en,
    input  logic [15:0] adc_data
    );
    
    parameter SLAVE_ID    = 7'h01;
    parameter MAX_ADDRESS = 3'd3;
    
    logic [7:0] registers[3:0];
    logic [2:0] address;
    logic       first_byte;
    logic       final_byte;
    logic       valid_slave;
    logic       valid_read;
    logic       valid_write;
    logic       first_byte_slave_id;
     
    assign valid_slave = (slave_id == SLAVE_ID);
    
    always_ff @(posedge clk, negedge rst_n_sync)
      if (~rst_n_sync)                       first_byte <= 1'd1;
      else if (data_in_finished)             first_byte <= 1'd1;
      else if (data_in_valid && valid_slave) first_byte <= 1'd0;
    
    always_ff @(posedge clk, negedge rst_n_sync)
        if (~rst_n_sync)                                                  address <= 'd0;
        else if (data_in_finished)                                        address <= 'd0;
        else if (valid_slave && data_in_valid && first_byte)              address <= data_in[2:0];
        else if (valid_slave && data_in_valid && (address < MAX_ADDRESS)) address <= address + 1;
        
    always_ff @(posedge clk, negedge rst_n_sync)
        if (~rst_n_sync)                                                                    final_byte <= 1'b0;
        else if (data_in_finished)                                                          final_byte <= 1'b0;
        else if (valid_slave && data_in_valid && (!first_byte) && (address == MAX_ADDRESS)) final_byte <= 1'b1;
 
    assign valid_read = valid_slave && rnw && (!first_byte) && (!final_byte);
    
    assign first_byte_slave_id = valid_slave && rnw && first_byte;
    
    assign read_data_out[7:0] =  ({8{valid_read}} & registers[address]) | ({8{first_byte_slave_id}} & {1'b0,SLAVE_ID});
      
    assign valid_write = valid_slave && (!rnw) && data_in_valid && (!first_byte) && (!final_byte);
    
    // each cfg register has its own address, just to keep things simple
    always_ff @(posedge clk, negedge rst_n_sync)
      if (~rst_n_sync) begin                    cfg_adc_enable    <= 1'b0;
                                                cfg_adc_record_en <= 1'b0; end
      else if (valid_write && (address == 'd0)) cfg_adc_enable    <= data_in[0];
      else if (valid_write && (address == 'd1)) cfg_adc_record_en <= data_in[0];
      else                                      cfg_adc_record_en <= 1'b0;   // self-clear
    
    // this is used for read_data_out decode
    assign registers[0] = {7'd0,cfg_adc_enable};
    assign registers[1] = {7'd0,cfg_adc_record_en};
    assign registers[2] = adc_data[15:8];
    assign registers[3] = adc_data[7:0];
    
endmodule