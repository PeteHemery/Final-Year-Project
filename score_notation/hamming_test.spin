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

OBJ

  pst : "Parallax Serial Terminal"

VAR
  long  cog                                             'Cog flag/id
  long  pst_on

  long  flag
  long  pasm_output

PUB start | okay, i
{{
  Start - This function copies the address of the first parameter passed from the calling object
          into the PASM object and launches the cog. Parameters should be consecutive in Hub RAM.
          Depending on the value of the filtering constant, FIR low pass filter may be applied.
}}

  stop
  flag := 1
  okay := cog := cognew(@asm_entry, @flag) + 1 'launch assembly program into a COG, store the cog id and return it

  if ina[31] == 1                            'Check if we're connected via USB
    pst_on := 1
    'start serial com
    pst.start(115200)
    pst.Clear
  else
    pst_on := 0

  pst.str(string("Begin",pst#NL))
  flag := 0
  repeat i from 1 to 1024
    repeat while (flag == 0)
'    pst.dec(i)
'    pst.char(":")
    pst.dec(pasm_output)
    pst.char(",")
    pst.char(" ")
    if (i // 16) == 0
      pst.newline
    flag := 0
  pst.str(string("Finish",pst#NL))
  repeat
    flag := 0
PUB stop
{{
 Stop - This function stops the sampler and releases the cog
}}
  if cog
    cogstop(cog~ - 1)

DAT

              org       0

asm_entry     mov       in_ptr,PAR                      'get the address of the first hub ram pointer
              mov       asm_flag_ptr,in_ptr
              add       in_ptr,#4

loop          rdlong    asm_flag,asm_flag_ptr
              tjnz      asm_flag,#loop


              djnz      peak_cnt,#:pksame
              mov       peak_cnt,peak_load
              add       asm_cnt,#1
              mov       odd_even,#0

:pksame

:hamming
{
              mov       m1, c                              'k1 := (a * (c + d)) / 4096
              add       m1, d
              mov       m2, a
              call      #mul
              mov       k1, m1
              sar       k1, #15 - 3
}
{              mov       m1, asm_sample
              test      asm_flag,#1             wz      'zero flag set when value1 AND value2 = 0
if_z          mov       t1, peak_load
if_z          sub       t1, peak_cnt
if_z          mov       m2, #hamming_window + t1

if_nz         mov       t1, peak_cnt
if_nz         sub       t1,#1
if_nz         mov       m2, #hamming_window + t1

              call      #mul
              shr       m1,#10
}

'Save data to buffer
'              wrword    asm_sample,in_ptr               'write sample to fft array
{              wrword    m1,in_ptr               'write sample to fft array
              add       in_ptr,#2                       'point to next word location
}



              mov       table_ptr, #hamming_window
{              add       table_ptr, t1

              movs      get_ham, table_ptr

              cmp       odd_even,#1             wc
if_c          mov       odd_even,#1
if_nc         mov       odd_even,#0
if_nc         add       t1,#1

get_ham
              mov       t2, 0-0

if_c          and       t2,table_mask
if_nc         shr       t2,#16
}
'---

              test      asm_cnt,#1              wz      'zero flag set when value1 AND value2 = 0

if_z          mov       t1, peak_load
if_z          sub       t1, peak_cnt

if_nz         mov       t1, peak_cnt
if_nz         sub       t1,#1

              shr       t1,#1

              add       table_ptr, t1
              movs      get_ham, table_ptr

              cmp       odd_even, #1            wc
if_c          mov       odd_even, #1
if_nc         mov       odd_even, #0


get_ham       mov       t2, 0-0


if_z_and_c    and       t2, table_mask
if_z_and_nc   shr       t2, #16
if_nz_and_c   shr       t2, #16
if_nz_and_nc  and       t2, table_mask

              mov       m1,#1
              shl       m1,#10
              mov       m2, t2

{              test      asm_flag,#1             wz      'zero flag set when value1 AND value2 = 0
if_z          mov       t1, peak_load
if_z          sub       t1, peak_cnt
if_z          mov       m2, #hamming_window + t1

if_nz         mov       t1, peak_cnt
if_nz         sub       t1,#1
if_nz         mov       m2, #hamming_window + t1
}
              call      #multi
              shr       m1,#10

              wrlong    m1,in_ptr



'              wrlong    t2,in_ptr
'              wrlong    peak_cnt,in_ptr

              mov       asm_flag,#1
              wrlong    asm_flag,asm_flag_ptr

              jmp       #loop

'----------------------------------------------------------------------------------------------------------------------
'       Borrowed from heaters fft
'----------------------------------------------------------------------------------------------------------------------
multi         'Account for sign
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
multi_ret     ret

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
        fit   $145

'
' Data
'
in_ptr                  long    0
t1                      long    0
t2                      long    0
t3                      long    0
zero                    long    0
one                     long    1

table_ptr               long    0
odd_even                long    0
table_mask              long    $FFFF

loop_cnt                long    0
loop_load               long    1023

peak_cnt                long    1
peak_load               long    512

asm_flag                long    0               'relevent flag pointer
asm_flag_ptr            long    0
asm_cnt                 long    1


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