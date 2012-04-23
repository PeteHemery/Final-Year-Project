''*******************************************************
''*  Microphone Sampler Prototype v1.0                  *
''*  Author: Pete Hemery                                *
''*  01/12/2011                                         *
''*  See end of file for terms of use.                  *
''*******************************************************
''
'' This demonstrates the capabilities of the Propeller to handle multiple
'' parallel tasks simultaneously. This object takes samples from the microphone
'' and stores them in Main RAM. The location is dependant on how many FFT objects
'' have been instantiated in the top level object file.
''
'' Sampling rate is set in the constants section below.
'' Low-Pass filtering has been provided for sample rates of 4, 5, 6 and 7 KHz.


CON
  _clkmode = xtal1 + pll16x                                               'Standard clock mode * crystal frequency = 80 MHz
  _xinfreq = 5_000_000
  CLK_FREQ = ((_clkmode-xtal1)>>6)*_xinfreq
  MS_001 = CLK_FREQ / 1_000
  
  sample_rate = CLK_FREQ / (1024 * KHz)  'Hz - modified using KHz constant below.

'Modify constants below for behaviour changes.

  averaging = 11                '2-power-n samples to compute average with
  attenuation = 0               'try 0-4

  KHz = 6                       'max 13 with 2 FFTs (for which filtering must be off)


VAR
  long  cog                                             'Cog flag/id

PUB start (flagptr): okay
{{
  Start - This function copies the address of the first parameter passed from the calling object
          into the PASM object and launches the cog. Parameters should be consecutive in Hub RAM.
          Depending on the value of the filtering constant, FIR low pass filter may be applied.
}}

  stop
  okay := cog := cognew(@asm_entry, flagptr) + 1 'launch assembly program into a COG, store the cog id and return it

PUB stop
{{
 Stop - This function stops the sampler and releases the cog
}}
  if cog
    cogstop(cog~ - 1)

DAT

              org       0

asm_entry     mov       dira,asm_dira                   'make pin 8 (ADC) output

              movs      ctra,#8                         'POS W/FEEDBACK mode for CTRA
              movd      ctra,#9
              movi      ctra,#%01001_000
              mov       frqa,#1                         'microphone now setup

              mov       in_ptr,PAR                      'get the address of the first hub ram pointer
              mov       asm_flag_ptr,in_ptr             'setup loop counter
              add       in_ptr,#4
              mov       asm_time_ptr,in_ptr
              add       in_ptr,#4
              rdlong    asm_array_size,in_ptr
              add       in_ptr,#4
              mov       asm_buffer_ptr,in_ptr

              rdlong    asm_flag,asm_flag_ptr

              sub       asm_array_size,#1               'more convenient for checking for end of array

              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

loop          waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get difference
              sub       asm_sample,asm_old
              add       asm_old,asm_sample


'Averaging
:avejump      add       average,asm_sample              'compute average periodically so that
              djnz      average_cnt,#:avgsame           'we can 0-justify samples
              mov       average_cnt,average_load
              shr       average,#averaging
              mov       asm_justify,average
              mov       average,#0                      'reset average for next averaging
:avgsame


:justify
              sub       asm_sample,asm_justify          'justify sample to bitmap center y
              sar       asm_sample,#attenuation         'this # controls attenuation (0=none)


'Save data to buffer
              wrword    asm_sample,in_ptr               'write sample to fft array
              add       in_ptr,#2                       'point to next word location

              djnz      peak_cnt,#loop
              mov       peak_cnt,peak_load

              'Let caller know every 512 samples
              cmp       asm_flag,#3             wc

if_nc         mov       asm_flag,#0
if_nc         mov       in_ptr,asm_buffer_ptr           'cog cell holding buffer address.

if_c          add       asm_flag,#1

              mov       t1,cnt

              wrlong    asm_flag,asm_flag_ptr
              wrlong    t1,asm_time_ptr                 'tell caller how long I took

:pksame

              cmp       array_offset,asm_array_size     wz
        if_nz jmp       #loop                           'wait for next sample period


              jmp       #loop

'
' Data
'
array_offset            long    0

in_ptr                  long    0
t1                      long    0
t2                      long    0
t3                      long    0
buffer_number           long    0                       'Numbering 0-3
zero                    long    0
one                     long    1

d0                      long    1 << 9

'asm_cycles    long      |< bits - 1                     'sample time
asm_cycles    long      sample_rate                     'sample time
asm_dira      long      $00000200                       'output mask
average_cnt   long      1
peak_cnt      long      1
peak_load     long      512
average_load  long      |< averaging
bignum        long      $FFFFFFFF

asm_flag                long    0               'relevent flag pointer

asm_flag_ptr            long    0
asm_time_ptr            long    0
asm_array_size          long    0

asm_buffer_ptr          long    0


asm_cnt                 res     1
asm_old                 res     1
asm_sample              res     1
average                 res     1
asm_justify             res     1
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
