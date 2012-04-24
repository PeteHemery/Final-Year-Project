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

  averaging =11                '2-power-n samples to compute average with
  attenuation = 0               'try 0-4

  KHz = 6                       'max 13 with 2 FFTs (for which filtering must be off)
                                'max of 28 with 3
  filtering = 0                 'turn off for different sample rates than provided

OBJ
'' Uncomment relevant object for Finite Impulse Response Low-Pass filtering with 1.5 KHz cut off

'  fir : "fir_filter_4k"
'  fir : "fir_filter_5k"
'  fir : "fir_filter_6k"
'  fir : "fir_filter_7k"

VAR
  long  cog                                             'Cog flag/id
  long  fir_busy,fir_data

PUB start (flagptr): okay
{{
  Start - This function copies the address of the first parameter passed from the calling object
          into the PASM object and launches the cog. Parameters should be consecutive in Hub RAM.
          Depending on the value of the filtering constant, FIR low pass filter may be applied.
}}

{  if(filtering == 1)
    asm_fir_busy := @fir_busy
    asm_fir_data := @fir_data
    fir.start(@fir_busy)
}  stop
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

'if using a single cog, write to audio buffer instead of directly to fft buffer
'              cmp       number_of_ffts,#1       wz
'if_z          add       asm_buffer1_ptr,#asm_array_size * 4
'if_z          sub       asm_fft1_ptr,#4


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
{
'Filtering
              cmp       filterswitch,#0         wz
if_z          jmp       #:avejump

              wrlong    asm_sample,asm_fir_data
              mov       t1,#1
              wrlong    t1,asm_fir_busy

:fir_loop     rdlong    t1,asm_fir_busy
              tjnz      t1,#:fir_loop
              rdword    asm_sample,asm_fir_data
}
'Averaging
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

              'Let caller know every 512 samples
              cmp       asm_flag,#0             wz
if_nz         mov       asm_flag,#0
if_z          add       asm_flag,#1

:pksame


:justify
              sub       asm_sample,asm_justify          'justify sample to bitmap center y
              sar       asm_sample,#attenuation         'this # controls attenuation (0=none)

:hamming
              mov       m1, asm_sample
              test      asm_flag,#1             wz      'zero flag set when value1 AND value2 = 0
if_z          mov       t1, peak_load
if_z          sub       t1, peak_cnt
if_z          mov       m2, #hamming_window + t1

if_nz         mov       t1, peak_cnt
if_nz         sub       t1,#1
if_nz         mov       m2, #hamming_window + t1

              call      #mul
              shr       m1,#10


'Save data and pick next buffer, if need be
              wrword    m1,in_ptr                       'write sample to fft array
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

'----------------------------------------------------------------------------------------------------------------------
'       Borrowed from heaters fft
'----------------------------------------------------------------------------------------------------------------------
mul           'Account for sign
              abs       m1, m1 wc
              negc      m2, m2
              abs       m2, m2 wc
              'Make t2 the smaller of the 2 unsigned parameters
              mov       m3, m1
              max       m3, m2
              min       m2, m1
              'Correct the sign of the adder
              negc      m2, m2

              'My accumulator
              mov       m1, #0
              'Do the work
:mul_loop     shr       m3, #1 wc,wz                       'Get the low bit of t2
        if_c  add       m1, m2                             'If it was a 1, add adder to accumulator
              shl       m2, #1                             'Shift the adder left by 1 bit
        if_nz jmp       #:mul_loop                         'Continue as long as there are no more 1's
mul_ret       ret

m1            long      0
m2            long      0
m3            long      0


hamming_window
        word  82, 82, 82, 82, 82, 82, 82, 82, 82, 83, 83, 83, 83, 83, 84, 84
        word  84, 84, 85, 85, 85, 86, 86, 87, 87, 87, 88, 88, 89, 89, 90, 90
        word  91, 92, 92, 93, 93, 94, 95, 95, 96, 97, 98, 98, 99, 100, 101, 101
        word  102, 103, 104, 105, 106, 107, 108, 109, 110, 110, 111, 113, 114, 115, 116, 117
        word  118, 119, 120, 121, 122, 124, 125, 126, 127, 128, 130, 131, 132, 134, 135, 136
        word  138, 139, 140, 142, 143, 145, 146, 148, 149, 151, 152, 154, 155, 157, 158, 160
        word  161, 163, 165, 166, 168, 170, 171, 173, 175, 177, 178, 180, 182, 184, 185, 187
        word  189, 191, 193, 195, 196, 198, 200, 202, 204, 206, 208, 210, 212, 214, 216, 218
        word  220, 222, 224, 226, 228, 231, 233, 235, 237, 239, 241, 243, 246, 248, 250, 252
        word  254, 257, 259, 261, 263, 266, 268, 270, 273, 275, 277, 280, 282, 284, 287, 289
        word  292, 294, 296, 299, 301, 304, 306, 309, 311, 314, 316, 319, 321, 324, 326, 329
        word  331, 334, 336, 339, 342, 344, 347, 349, 352, 355, 357, 360, 363, 365, 368, 371
        word  373, 376, 379, 381, 384, 387, 389, 392, 395, 398, 400, 403, 406, 409, 411, 414
        word  417, 420, 422, 425, 428, 431, 433, 436, 439, 442, 445, 448, 450, 453, 456, 459
        word  462, 465, 467, 470, 473, 476, 479, 482, 484, 487, 490, 493, 496, 499, 502, 505
        word  507, 510, 513, 516, 519, 522, 525, 528, 531, 533, 536, 539, 542, 545, 548, 551
        word  554, 557, 559, 562, 565, 568, 571, 574, 577, 580, 583, 585, 588, 591, 594, 597
        word  600, 603, 606, 609, 611, 614, 617, 620, 623, 626, 629, 631, 634, 637, 640, 643
        word  646, 648, 651, 654, 657, 660, 663, 665, 668, 671, 674, 677, 679, 682, 685, 688
        word  691, 693, 696, 699, 702, 704, 707, 710, 712, 715, 718, 721, 723, 726, 729, 731
        word  734, 737, 739, 742, 745, 747, 750, 753, 755, 758, 760, 763, 766, 768, 771, 773
        word  776, 778, 781, 783, 786, 788, 791, 793, 796, 798, 801, 803, 806, 808, 811, 813
        word  815, 818, 820, 823, 825, 827, 830, 832, 834, 837, 839, 841, 844, 846, 848, 850
        word  853, 855, 857, 859, 861, 864, 866, 868, 870, 872, 874, 876, 879, 881, 883, 885
        word  887, 889, 891, 893, 895, 897, 899, 901, 903, 905, 907, 908, 910, 912, 914, 916
        word  918, 920, 921, 923, 925, 927, 929, 930, 932, 934, 935, 937, 939, 940, 942, 944
        word  945, 947, 948, 950, 952, 953, 955, 956, 958, 959, 961, 962, 963, 965, 966, 968
        word  969, 970, 972, 973, 974, 976, 977, 978, 979, 981, 982, 983, 984, 985, 986, 988
        word  989, 990, 991, 992, 993, 994, 995, 996, 997, 998, 999, 1000, 1001, 1002, 1002, 1003
        word  1004, 1005, 1006, 1007, 1007, 1008, 1009, 1010, 1010, 1011, 1012, 1012, 1013, 1013, 1014, 1015
        word  1015, 1016, 1016, 1017, 1017, 1018, 1018, 1019, 1019, 1020, 1020, 1020, 1021, 1021, 1021, 1022
        word  1022, 1022, 1022, 1023, 1023, 1023, 1023, 1023, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024
        fit   $1A0



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

asm_flag                long    1

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
