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

  bits = 14                     'try different values from table here
  attenuation = 2               'try 0-4

  averaging = 13                '2-power-n samples to compute average with

  param_count = 10

VAR
  long  cog                                             'Cog flag/id

PUB start (flagptr): okay

'  longmove(@asm_flag_ptr,flagptr,10)
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
              mov       frqa,#1

              cogid     cog_id

              mov       in_ptr,PAR
              mov       out_ptr,#asm_flag_ptr

              movd      :patch,out_ptr
              mov       t2,#param_count

:rdloop       rdlong    t1,in_ptr
:patch        mov       0,t1
              add       out_ptr,#1
              add       in_ptr,#4
              movd      :patch,out_ptr
'              add       :patch,d0
              djnz      t2,#:rdloop

'              wrlong    out_ptr,asm_flag_ptr     'let outside object know

{{
              mov       t2,#param_count
              movd      :patch,#asm_flag_ptr
              mov       in_ptr,PAR              'load parameters
:rdloop
:patch        rdlong    0,in_ptr
              add       :patch,d0
              add       in_ptr,#4
              djnz      t2,#:rdloop
}}
{{
              mov       in_ptr,PAR
              rdlong    asm_flag_ptr,in_ptr

              add       in_ptr,#4
              rdlong    asm_array_size,in_ptr


''              rdlong    asm_buffer1_ptr,in_ptr          'fft input buffers

              movd      :rdpatch,#asm_buffer1_ptr
'              add       :rdpatch,d4
:load         add       in_ptr,#4
:rdpatch      rdlong    0,in_ptr


              add       in_ptr,#4
              rdlong    asm_buffer2_ptr,in_ptr

              add       in_ptr,#4
              rdlong    asm_buffer3_ptr,in_ptr

              add       in_ptr,#4
              rdlong    asm_buffer4_ptr,in_ptr

              add       in_ptr,#4
              rdlong    asm_fft1_ptr,in_ptr             'fft flags

              add       in_ptr,#4
              rdlong    asm_fft2_ptr,in_ptr

              add       in_ptr,#4
              rdlong    asm_fft3_ptr,in_ptr

              add       in_ptr,#4
              rdlong    asm_fft4_ptr,in_ptr
}}
{{
              movd      :rdpatch0,#asm_flag_ptr
              mov       in_ptr,PAR
:rdpatch0     rdlong    0,in_ptr

              movd      :rdpatch1,#asm_array_size
              add       in_ptr,#4
:rdpatch1     rdlong    0,in_ptr

              movd      :rdpatch2,#asm_buffer1_ptr
              add       in_ptr,#4
:rdpatch2     rdlong    0,in_ptr

              movd      :rdpatch3,#asm_buffer2_ptr
              add       in_ptr,#4
:rdpatch3     rdlong    0,in_ptr

              movd      :rdpatch4,#asm_buffer3_ptr
              add       in_ptr,#4
:rdpatch4     rdlong    0,in_ptr

              movd      :rdpatch5,#asm_buffer4_ptr
              add       in_ptr,#4
:rdpatch5     rdlong    0,in_ptr

              movd      :rdpatch6,#asm_fft1_ptr
              add       in_ptr,#4
:rdpatch6     rdlong    0,in_ptr

              movd      :rdpatch7,#asm_fft2_ptr
              add       in_ptr,#4
:rdpatch7     rdlong    0,in_ptr

              movd      :rdpatch8,#asm_fft3_ptr
              add       in_ptr,#4
:rdpatch8     rdlong    0,in_ptr

              movd      :rdpatch9,#asm_fft4_ptr
              add       in_ptr,#4
:rdpatch9     rdlong    0,in_ptr
}}

              mov       buffer_number,#0
              mov       in_ptr,asm_buffer1_ptr          'use in_ptr as input to the array

              sub       asm_array_size,#1               'more convenient for checking for end of array

              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

loop          waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get difference
              sub       asm_sample,asm_old
              add       asm_old,asm_sample

              wrword    asm_sample,in_ptr               'put sample in array
              add       in_ptr,#2
              add       array_offset,#1                 'keep count of how far into array we are

              test      array_offset,asm_array_size     wz
        if_nz jmp       #loop                           'wait for next sample period

              mov       array_offset,#0

              add       buffer_number,#1                'change fft buffer

              testn     buffer_number,#1        wz
        if_z  mov       in_ptr,asm_buffer2_ptr
        if_z  wrlong    zero,asm_fft1_ptr

              testn     buffer_number,#2        wz
        if_z  mov       in_ptr,asm_buffer3_ptr
        if_z  wrlong    zero,asm_fft2_ptr

              testn     buffer_number,#3        wz
        if_z  mov       in_ptr,asm_buffer4_ptr
        if_z  wrlong    zero,asm_fft3_ptr

              testn     buffer_number,#4        wz      'counting 0-3
        if_z  mov       buffer_number,#0
        if_z  mov       in_ptr,asm_buffer1_ptr          'reset input to the relevant array
        if_z  wrlong    zero,asm_fft4_ptr               'trigger fft cog


              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles
'              wrlong    asm_cnt,asm_flag_ptr            'tell caller how long I took
              wrlong    buffer_number,asm_flag_ptr     'let outside object know buffer in use via the flag

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
asm_buffer1_ptr         long    0
asm_buffer2_ptr         long    0
asm_buffer3_ptr         long    0
asm_buffer4_ptr         long    0
asm_fft1_ptr            long    0
asm_fft2_ptr            long    0
asm_fft3_ptr            long    0
asm_fft4_ptr            long    0
stopper                 res     1

array_offset            long    0
array_end               long    0
cog_id                  long    0
in_ptr                  long    0
out_ptr                 long    0
t1                      long    0
t2                      long    0
buffer_number           long    0               'Numbering 0-3
zero                    long    0
d0                      long    1 << 9
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
