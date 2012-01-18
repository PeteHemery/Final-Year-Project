{Sampler - This object takes samples from the microphone and stores them in Main RAM}


CON
        _clkmode = xtal1 + pll16x                                               'Standard clock mode * crystal frequency = 80 MHz
        _xinfreq = 5_000_000

' At 80MHz the ADC/DAC sample resolutions and rates are as follows:
'
' sample   sample
' bits       rate
' ----------------
' 11       39 KHz
' 12     19.5 KHz
' 13     9.77 KHz
' 14     4.88 KHz

  bits = 14                     'try different values from table here

VAR
  long  cog                                             'Cog flag/id

PUB start (flagptr): okay

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

              mov       t2,t1'copy number of params
              sub       t2,#3'remove required params
              shr       t2,#1'how many ffts
              mov       number_of_ffts,t2
              mov       t3,#4'work out how many cog longs to jump
              sub       t3,t2'4-num_of_ffts
              add       t2,#1'trigger at the correct iteration below

              wrlong    t3,asm_flag_ptr
              shl       t3,#9'set for destination field of :patch instruction

:rdloop
:patch        rdlong    0-0,in_ptr
              add       :patch,d0  'increment destination operand by 1 / point at next cog long

              cmp       t1,t2   wz
        if_z  add       :patch,t3  'skip unused pointer locations

              add       in_ptr,#4  'set to read next long from hub ram, giving time for fetch/execute of updated :patch long
              djnz      t1,#:rdloop

              mov       buffer_number,#0
              mov       fft_ptr,asm_fft1_ptr             'use fft_ptr as relevent flag pointer
              mov       in_ptr,asm_buffer1_ptr           'use in_ptr as input to the array

              sub       asm_array_size,#1               'more convenient for checking for end of array

              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

loop          waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get difference
              sub       asm_sample,asm_old
              add       asm_old,asm_sample

              wrword    asm_sample,in_ptr               'write sample to fft array
              add       in_ptr,#2
              add       array_offset,#1                 'keep count of how far into the array we are

              cmp       array_offset,asm_array_size     wz
        if_nz jmp       #loop                           'wait for next sample period

              mov       array_offset,#0                 'reset array offset
              wrlong    zero,fft_ptr                    'trigger fft to go
              cmp       number_of_ffts,#1       wz      'if there's only one, jump round the loop again
        if_nz jmp       #find_free_buf

waiting       rdlong    t1,fft_ptr                      'wait until flag is not 0 before looping again
              cmp       t1,#0                   wz
    if_z      jmp       #waiting

              mov       in_ptr,asm_buffer1_ptr          'cog cell holding 1st buffer
              add       one,#1
              wrlong    one,asm_flag_ptr                'let outside object know buffer in use via the flag

              jmp       #end_time

'''''''''''''''''
' Check which buffer has non 0 flag value and write to it next

find_free_buf add       buffer_number,#1                'set the next buffer number
              cmp       buffer_number,number_of_ffts    wz
        if_z  mov       buffer_number,#0

              mov       in_ptr,#asm_fft1_ptr            'cog cell holding 1st flag address
              mov       t1,buffer_number
              add       in_ptr,t1                       'move to relevent cell
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
              nop
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

asm_cycles              long    |< bits - 1             'sample time
asm_dira                long    $00000200               'output mask

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

asm_cnt                 res     1
asm_old                 res     1
asm_sample              res     1

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
