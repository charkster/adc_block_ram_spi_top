#!/usr/bin/python3

from __future__  import print_function
import spidev
import time
from scarf_slave import scarf_slave

spi              = spidev.SpiDev(0,0)
spi.max_speed_hz = 12000000
spi.mode         = 0b00

adc  = scarf_slave(slave_id=0x01, spidev=spi, num_addr_bytes=1, debug=False)
bram = scarf_slave(slave_id=0x02, spidev=spi, num_addr_bytes=2, debug=False)

print("Check for SCARF Slaves")
for ss_id in range(1,128):
	adc.slave_id = ss_id
	if (adc.read_id() != 0x00):
		print("Found scarf slave at 0x{:02x}".format(adc.slave_id))
adc.slave_id = 0x01

print("Read first 256 bytes of Block Ram")
read_data = bram.read_list(addr=0x0000,num_bytes=256)
address = 0
for read_byte in read_data:
	print("BRAM Byte #{:d} Read data 0x{:02x}".format(address,read_byte))
	address += 1

#print("Load Block Ram with sequential data")
#list_page_of_bytes = list(range(0, 256))
#for page in range(0, 256):
#	print("Page #{:d}".format(page))
#	bram.write_list(addr=page*256, write_byte_list=list_page_of_bytes)

print("Load Block Ram with ADC data")
# this is trigger the adc_recorder to capture 65536 ADC samples (upper 8bits of the 12bit ADC output)
# ADC SCARF regmap
#    assign registers[0] = {7'd0,cfg_adc_enable};
#    assign registers[1] = {7'd0,cfg_adc_record_en};
#    assign registers[2] = adc_data[15:8];
#    assign registers[3] = adc_data[7:0];
adc.write_list(addr=0x01, write_byte_list=[0x01])
time.sleep(1)

print("Read entire contents of Block Ram")
list_read_data = []
for page in range(0, 256):
	print("Read Page #{:d}".format(page))
	read_data = bram.read_list(addr=page*256,num_bytes=256)
	list_read_data.extend(read_data)

print("Print entire contents of Block Ram")
address = 0
for read_byte in list_read_data:
	print("BRAM Byte #{:d} Read data 0x{:02x}".format(address,read_byte))
	address += 1
