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
                                
  bits = 11               'try different values from table here
  attenuation = 2               'try 0-4

  averaging = 13                '2-power-n samples to compute average with
  
  
VAR
  long  cog                                             'Cog flag/id
  long  flag_ptr
  long  array_size
  long  no_of_bytes
  long  buffer_ptr


PUB start (flagptr,arraysize,bytesize,bufferptr): okay
  flag_ptr := flagptr
  array_size := arraysize
  no_of_bytes := bytesize
  buffer_ptr := bufferptr
  stop
  okay := cog := cognew(@asm_entry, @flag_ptr)   'launch assembly program into a COG

PUB stop
'' stop sampler and release the cog

  if cog
    cogstop(cog~ - 1)

DAT

              org       0

asm_entry     mov       dira,asm_dira                   'make pin 8 (ADC) output

              movs      ctra,#8                         'POS W/FEEDBACK mode for CTRA
              movd      ctra,#9
              movi      ctra,#%01001_000
              mov       frqa,#1

              cogid     cog_id
              mov       in_ptr,PAR
              rdlong    asm_flag_ptr,in_ptr

              add       in_ptr,#4
              rdlong    asm_array_size,in_ptr

              add       in_ptr,#4
              rdlong    asm_byte_size,in_ptr

              add       in_ptr,#4
              rdlong    asm_buffer_ptr,in_ptr

              mov       in_ptr,asm_buffer_ptr           'use in_ptr as input to the array

{{              mov       array_end,asm_buffer_ptr        'copy array start address
              mov       array_offset,asm_array_size
              sub       array_offset,#1                 'most likely 0-1023
              test      asm_byte_size,#2         wz
        if_z  shl       array_offset,#1                 'array is word sized
        if_nz shl       array_offset,#2                 'array is long sized
              add       array_end,array_offset          'work out last array entry
}}
              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

              sub       asm_array_size,#1               'more convenient for checking for end of array

loop         waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get difference
              sub       asm_sample,asm_old
              add       asm_old,asm_sample

              wrword    asm_sample,in_ptr               'put sample in array
              add       in_ptr,#2
              add       array_offset,#1                 'keep count of how far into array we are

              test      array_offset,asm_array_size     wz
        if_nz jmp       #loop                          'wait for next sample period
              mov       temp,#1
              wrlong    temp,asm_flag_ptr               'set flag to 1
              mov       in_ptr,asm_buffer_ptr           'reset input to the array
              mov       array_offset,#0

flag_wait     rdlong    temp,asm_flag_ptr
              tjnz      temp,#flag_wait

              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles
              jmp       #loop

'
'
' Data
'
asm_cycles              long    |< bits - 1           'sample time
asm_dira                long    $00000200             'output mask

asm_cnt                 res     1
asm_old                 res     1
asm_sample              res     1
asm_data                res     1

asm_flag_ptr            long    0
asm_array_size          long    0
asm_byte_size           long    0
asm_buffer_ptr          long    0

array_offset            long    0
array_end               long    0
cog_id                  long    0
in_ptr                  long    0
temp                    long    0
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
