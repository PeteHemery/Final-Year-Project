{Sampler - This object takes samples from the microphone and stores them in Main RAM}


CON
        _clkmode = xtal1 + pll16x                                               'Standard clock mode * crystal frequency = 80 MHz
        _xinfreq = 5_000_000

' At 80MHz the ADC/DAC sample resolutions and rates are as follows:
'
' sample   sample               
' bits       rate               
' ----------------              
' 5       2.5 MHz               
' 6      1.25 MHz               
' 7       625 KHz               
' 8       313 KHz               
' 9       156 KHz               
' 10       78 KHz               
' 11       39 KHz               
' 12     19.5 KHz               
' 13     9.77 KHz               
' 14     4.88 KHz               
                                
  bits = 12               'try different values from table here
  
  
VAR
  long  cog                                             'Cog flag/id

  long  bit_ticks

  word  block_size
  byte  number_of_blocks
  byte  flags[number_of_blocks]

  long  main_buffer_1[block_size] 
  long  main_buffer_2[block_size]      
  long  main_buffer_3[block_size]
  long  main_buffer_4[block_size]
  long  main_buffer_5[block_size]
  long  main_buffer_6[block_size]

PUB go

  cognew(@asm_entry, 0)   'launch assembly program into a COG
        
PUB start (samplerate,blocksize,numofblocks,startpointer): okay
  bit_ticks := clkfreq / samplerate
  block_size := blocksize
  number_of_blocks := numofblocks
  main_pt := starterpointer
  
  'cognew(@asm_entry, @bit_ticks)   'launch assembly program into a COG   

DAT

              org
asm_entry     'start here'              

local_buffer            res     256
  
local_head_pt           byte    0
local_tail_pt           byte    0 

main_start_pt           long    0
main_offset_pt          long    0
                 