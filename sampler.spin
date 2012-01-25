{Sampler - This object takes samples from the microphone and stores them in Main RAM}


CON
  _clkmode = xtal1 + pll16x                                               'Standard clock mode * crystal frequency = 80 MHz
  _xinfreq = 5_000_000
  CLK_FREQ = ((_clkmode-xtal1)>>6)*_xinfreq
  MS_001 = CLK_FREQ / 1_000

  averaging = 10                '2-power-n samples to compute average with
  attenuation = 4               'try 0-4

  sample_rate = CLK_FREQ / (1024 * KHz)  'Hz

  KHz = 6                       'max 13 with 2 FFTs
  filtering = 1                 'turn off for different sample rates than provided

OBJ
'  fir : "fir_filter_4k"
'  fir : "fir_filter_5k"
  fir : "fir_filter_6k"
'  fir : "fir_filter_7k"

VAR
  long  cog                                             'Cog flag/id
  long  fir_busy,fir_data

PUB start (flagptr): okay

  if(filtering == 1)
    asm_fir_busy := @fir_busy
    asm_fir_data := @fir_data
    fir.start(@fir_busy)
  stop
  okay := cog := cognew(@asm_entry, flagptr) + 1 'launch assembly program into a COG

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
              mov       frqa,#1                         'microphone now setup

'              cogid     cog_id

              mov       in_ptr,PAR                      'get the address of the first hub ram pointer
              movd      :patch,#asm_flag_ptr            'patch the rdlong instruction with the address of cog ram
              rdlong    asm_flag_ptr,in_ptr             'setup loop counter
              rdlong    t1,asm_flag_ptr                 'number of parameters stored in flag pointer

              mov       t2,t1                           'copy number of params
              sub       t2,#3                           'remove required params
              shr       t2,#1                           'how many ffts
              mov       number_of_ffts,t2
              mov       t3,#4                           'work out how many cog longs to jump
              sub       t3,t2                           '4-num_of_ffts=number of cells to jump
              add       t2,#1                           'trigger at the correct iteration below

              wrlong    t3,asm_flag_ptr
              shl       t3,#9                           'set for destination field of :patch instruction

:rdloop
:patch        rdlong    0-0,in_ptr
              add       :patch,d0  'increment destination operand by 1 / point at next cog long

              cmp       t1,t2   wz
        if_z  add       :patch,t3  'skip unused pointer locations

              add       in_ptr,#4  'set to read next long from hub ram, giving time for fetch/execute of updated :patch long
              djnz      t1,#:rdloop

              mov       buffer_number,#0
              mov       fft_ptr,asm_fft1_ptr             'use fft_ptr as relevent flag pointer
              mov       in_ptr,asm_buffer1_ptr           'use in_ptr as input for the array

              sub       asm_array_size,#1               'more convenient for checking for end of array

              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

loop          waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get difference
              sub       asm_sample,asm_old
              add       asm_old,asm_sample

''Filtering
              cmp       filterswitch,#0         wz
if_z          jmp       #:avejump

              wrlong    asm_sample,asm_fir_data
              mov       t1,#1
              wrlong    t1,asm_fir_busy

:fir_loop     rdlong    t1,asm_fir_busy
              tjnz      t1,#:fir_loop
              rdword    asm_sample,asm_fir_data

''Averaging
:avejump      add       average,asm_sample              'compute average periodically so that
              djnz      average_cnt,#:avgsame           'we can 0-justify samples
              mov       average_cnt,average_load
              shr       average,#averaging
              mov       asm_justify,average
              mov       average,#0                      'reset average for next averaging
:avgsame

              max       peak_min,asm_sample             'track min and max peaks for triggering
              min       peak_max,asm_sample
              djnz      peak_cnt,#:pksame
              mov       peak_cnt,peak_load
              mov       x,peak_max                      'compute min+12.5% and max-12.5%
              sub       x,peak_min
              shr       x,#3
              mov       trig_min,peak_min
              add       trig_min,x
              mov       trig_max,peak_max
              sub       trig_max,x
              mov       peak_min,bignum                 'reset peak detectors
              mov       peak_max,#0
:pksame

''Save data and pick next buffer, if need be
              wrword    asm_sample,in_ptr               'write sample to fft array
              add       in_ptr,#2
              add       array_offset,#1                 'keep count of how far into the array we are

              cmp       array_offset,asm_array_size     wz
        if_nz jmp       #loop                           'wait for next sample period

              mov       array_offset,#0                 'reset array offset
              wrlong    zero,fft_ptr                    'trigger fft to go

              mov       t1,cnt
              wrlong    t1,asm_time_ptr                 'tell caller how long I took

              cmp       number_of_ffts,#1       wz      'if there's only one, jump round the loop again
        if_nz jmp       #find_free_buf

              add       one,#1
              wrlong    one,asm_flag_ptr                'let outside object know buffer in use via the flag
              mov       in_ptr,asm_buffer1_ptr          'cog cell holding 1st buffer

waiting       rdlong    t1,fft_ptr                      'wait until flag is not 0 before looping again
              cmp       t1,#0                   wz
    if_z      jmp       #waiting
              jmp       #end_time

'''''''''''''''''
' Check which buffer has non 0 flag value and write to it next

find_free_buf add       buffer_number,#1                'set the next buffer number
              cmp       buffer_number,number_of_ffts    wz
        if_z  mov       buffer_number,#0

              mov       in_ptr,#asm_fft1_ptr            'cog cell holding 1st flag address
              add       in_ptr,buffer_number            'move to relevent cell
              movs      read_flag,in_ptr                'patch the move instruction below
              nop                                       'wait for above instruction to propagate
read_flag     mov       fft_ptr,0-0
              rdlong    t1,fft_ptr              wz      'read the cog cell that has the current fft flag address
        if_z  jmp       #find_free_buf                  'go for the next buffer if this one has 0 in the flag

              mov       in_ptr,#asm_buffer1_ptr         'cog cell holding 1st buffer address
              mov       t1,buffer_number
              add       in_ptr,t1                       'point at cog cell holding fft buffer address

              movs      get_buf_ptr,in_ptr              'patch the move instruction below

              add       one,#1
              wrlong    one,asm_flag_ptr                'let outside object know how many samples we've taken
'              wrlong    buffer_number,asm_flag_ptr      'let outside object know buffer in use via the flag

get_buf_ptr   mov       in_ptr,0-0                      'reset input to the relevent array

end_time      mov       asm_cnt,cnt
              wrlong    asm_cnt,asm_time_ptr            'tell caller how long I took
              add       asm_cnt,asm_cycles
              jmp       #loop

'
' Data
'
array_offset            long    0
array_end               long    0
cog_id                  long    0

in_ptr                  long    0
t1                      long    0
t2                      long    0
t3                      long    0
buffer_number           long    0                       'Numbering 0-3
zero                    long    0
one                     long    1

d0                      long    1 << 9

'asm_cycles    long      |< bits - 1                     'sample time
asm_cycles    long      sample_rate - 1                 'sample time
asm_dira      long      $00000200                       'output mask
average_cnt   long      1
peak_cnt      long      1
peak_load     long      512
average_load  long      |< averaging
bignum        long      $FFFFFFFF

number_of_ffts          long    0
fft_ptr                 long    0               'relevent flag pointer

asm_flag_ptr            long    0
asm_time_ptr            long    0
asm_array_size          long    0

asm_fft1_ptr            long    0
asm_fft2_ptr            long    0
asm_fft3_ptr            long    0
asm_fft4_ptr            long    0
asm_buffer1_ptr         long    0
asm_buffer2_ptr         long    0
asm_buffer3_ptr         long    0
asm_buffer4_ptr         long    0

asm_fir_busy            long    0
asm_fir_data            long    0
filterswitch            long    filtering

asm_cnt                 res     1
asm_old                 res     1
asm_sample              res     1
trig_min                res     1
trig_max                res     1
average                 res     1
asm_justify             res     1
peak_min                res     1
peak_max                res     1
x                       res     1
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
