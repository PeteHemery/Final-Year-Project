''***************************************
''*  Microphone-to-VGA v1.0             *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2006 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************

' This program uses the Propeller Demo Board, Rev C
'
' The microphone is digitized and the samples are displayed on a VGA monitor, just like
' an oscilloscope with triggering.
'
' This program is sloppy and not ready for prime time. I just wanted to share it now.

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  tiles    = vga#xtiles * vga#ytiles
  tiles32  = tiles * 32

  CLK_FREQ = ((_clkmode-xtal1)>>6)*_xinfreq
  MS_001 = CLK_FREQ / 1_000

  sample_rate = CLK_FREQ / (1024 * KHz)  'Hz
  time_taken =(((sample_rate / 8) * 512) / 10)   '80MHz/8 then /10 because of rounding errors.
                                                 'time for 512 samples * refresh_num -> in microseconds
  averaging = 13                '2-power-n samples to compute average with
  attenuation = 4               'try 0-4
  threshold = 20                'for detecting peak amplitude

  KHz = 7

OBJ

'  fir : "fir_filter_4k"
'  fir : "fir_filter_5k"
'  fir : "fir_filter_6k"
  fir : "fir_filter_7k"

  vga : "vga_512x384_bitmap"
  pst : "Parallax Serial Terminal"
'  fft:"fft"
'  hfft : "heater_fft_hamming"

VAR

  long fir_busy, fir_data
  long flag
  long samples_ptr
  long cycles_count
  long completed_count

  word samples[1024]'filter[512]

  long  sync, pixels[tiles32]
  word  colors[tiles], ypos[512]


PUB start | f, i, p, startTime, endTime, freq, time, running_total

  'start vga
  vga.start(16, @colors, @pixels, @sync)

  'init colors to cyan on black
  repeat i from 0 to tiles - 1
    colors[i] := $3C00

  'fill top line so that it gets erased by COG
  longfill(@pixels, $FFFFFFFF, vga#xtiles)

  fir.start(@fir_busy)

  pst.start(115200)
'  waitcnt(clkfreq + cnt)
  pst.Clear
  long[@flag] := 0
  long[@samples_ptr] := @samples

  'implant pointers and launch assembly program into COG
  asm_pixels := @pixels
  asm_ypos := @ypos
  cognew(@asm_entry, @flag)

  pst.str(string("Time Taken: "))
  pst.dec(time_taken)
  pst.newline


  repeat
{      pst.str(string("Flag: "))
      pst.dec(long[@flag])              ' print whole part
      pst.newline
      pst.str(string("cycle_count: "))
      pst.dec(long[@cycles_count])
      pst.newline
      pst.str(string("completed_count: "))
      pst.dec(long[@completed_count])
      pst.newline
}

    repeat while long[@flag] == f
    f := long[@flag]
{    if (long[@completed_count] => 2)
      pst.newline
      time := (long[@completed_count] * time_taken) / 100
      pst.dec(time)
      pst.newline
      freq := ((long[@cycles_count] * 1_000_000) / time)
      running_total += freq
      pst.newline
      pst.str(string("Freq: "))
      pst.dec(freq)              ' print whole part
      pst.newline
      pst.dec(freq/100)              ' print whole part
      pst.char(".")
      pst.dec(freq//100)             ' print fractional part
      pst.str(string("Hz",pst#NL))

      pst.str(string("cycle_count: "))
      pst.dec(long[@cycles_count])
      pst.newline
      pst.str(string("completed_count: "))
      pst.dec(long[@completed_count])
      pst.newline}
    if(long[@completed_count])
      time := (long[@completed_count] * time_taken) / 100
      freq := ((long[@cycles_count] * 1_000_000) / time)
      running_total += freq
    if (long[@completed_count] == 0 and p <> 0)
      time := (p * time_taken) / 100
      pst.str(string("completed_count: "))
      pst.dec(p)
      pst.newline
      pst.str(string("time: "))
      pst.dec(time)
      pst.newline
      pst.str(string("Freq: "))
      freq := (running_total / p)
      pst.dec(freq/100)
      pst.char(".")
      pst.dec(freq//100)
      pst.str(string("Hz",pst#NL))

      running_total := 0
    p := long[@completed_count]

'    waitcnt((500 * MS_001) +cnt)
{
    repeat while flag == 1
    endTime := cnt
    startTime := cnt
    pst.str(string("Sample 1  Buffer "))    
    pst.dec((endTime - startTime) / (clkfreq / 1_000_000))
    pst.str(string("us",pst#NL))
    pst.dec((startTime))
    pst.newline
    pst.dec((endTime))

    f := long[@frequency] / sample_rate
    pst.dec(f/100)              ' print whole part
    pst.char(".")
    pst.dec(f//100)             ' print fractional part
    pst.str(string("Hz",pst#NL))

    repeat while flag == 2
    endTime := cnt
    startTime := cnt
    pst.str(string("Sample 2  Buffer "))
    pst.dec((endTime - startTime) / (clkfreq / 1_000_000))
    pst.str(string("us",pst#NL))
    startTime := cnt
}


{    repeat while flag <> @samples
    flag := 1
    endTime := cnt
    pst.str(string("Sampler run time = "))
    pst.dec((endTime - startTime) / (clkfreq / 1000))
    pst.str(string("ms"))
    pst.newline
    startTime := cnt
    repeat i from 0 to 1023
        pst.dec(i)
        pst.str(string(" "))
        pst.dec(word[@samples][i])
        pst.newline
    endTime := cnt
    pst.str(string("Printing 1024 samples taken - run time = "))
    pst.dec((endTime - startTime) / (clkfreq / 1000))
    pst.str(string("ms"))
    pst.newline
    startTime := cnt
}



DAT

'
'
' Assembly program
'
              org       0

asm_entry     mov       flag_addr,PAR
              mov       temp,flag_addr
              add       temp,#4
              rdlong    buffer_addr,temp
              mov       output_pos,buffer_addr

              mov       cycles_addr,flag_addr
              add       cycles_addr,#8
              mov       complete_addr,cycles_addr
              add       complete_addr,#4

              mov       asm_fir_busy,flag_addr
              sub       asm_fir_busy,#8
              mov       asm_fir_data,flag_addr
              sub       asm_fir_data,#4

              mov       dira,asm_dira                   'make pin 8 (ADC) output

              movs      ctra,#8
              movd      ctra,#9
              movi      ctra,#%01001_000                'POS W/FEEDBACK mode for CTRA
              mov       frqa,#1

              mov       xpos,#0
              
              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

              
:loop         waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get difference
              sub       asm_sample,asm_old
              add       asm_old,asm_sample

''Filtering
              wrlong    asm_sample,asm_fir_data
              mov       temp,#1
              wrlong    temp,asm_fir_busy

:fir_loop     rdlong    temp,asm_fir_busy
              tjnz      temp,#:fir_loop
              rdword    asm_sample,asm_fir_data
''
              add       average,asm_sample              'compute average periodically so that
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

              cmp       mode,#0                 wz      'wait for negative trigger threshold
if_z          cmp       asm_sample,trig_min     wc
if_z_and_c    mov       mode,#1
if_z          jmp       #:loop

              cmp       mode,#1                 wz      'wait for positive trigger threshold
if_z          cmp       asm_sample,trig_max     wc
if_z_and_nc   mov       mode,#2
if_z          jmp       #:loop

'' Check number of 0 crossings
              cmps      asm_justify,asm_sample  wc'carry is written if source is larger
if_nc         jmp       #:less
              mov       prev_cross,#1           ' Sample is more than 0
              jmp       #:justify               ' Don't count it
' Sample is less than 0
:less         cmps      prev_cross,#0           wc
if_c          jmp       #:justify               'Last crossing was also below 0
              mov       prev_cross,minus_one

'              mov       temp,peak_max
'              sub       temp,peak_min
              mov       temp,trig_max
              sub       temp,trig_min
              cmp       temp,#threshold         wc'carry is written if source is larger
              cmp       counting,#0             wz
if_z_and_nc   mov       start_time,cnt          'above threshold, setup counting
if_z_and_nc   mov       counting,#1
if_nz_and_nc  add       cycles_cnt,#1           'if we're counting already, keep counting
if_c          mov       counting,#0             'under threshold, let the end know
if_c          mov       completed,#0
'' End

:justify
'' Added to export sample
'              wrword    asm_sample,output_pos
              add       output_pos,#2

'              wrlong    asm_sample,flag_addr
'              wrlong    asm_justify,cycles_addr
'' End
              sub       asm_sample,asm_justify          'justify sample to bitmap center y
              sar       asm_sample,#attenuation         'this # controls attenuation (0=none)

              add       asm_sample,#384 / 2
              mins      asm_sample,#0
              maxs      asm_sample,#384 - 1

              mov       x,xpos                          'xor old pixel off
              shl       x,#1
              add       x,asm_ypos
              rdword    y,x                             'get old pixel-y
              wrword    asm_sample,x                    'save new pixel-y
              mov       x,xpos
              call      #plot

              mov       x,xpos                          'xor new pixel on
              mov       y,asm_sample
              call      #plot

              add       xpos,#1                         'increment x position and mask
              and       xpos,#$1FF              wz
if_nz         jmp       #:loop                          'wait for next sample period
              mov       mode,#0                         'if rollover, reset mode for trigger

              mov       output_pos,buffer_addr
              cmp       which_half,#0           wz
if_z          mov       which_half,top_half
if_nz         mov       which_half,#0
              add       output_pos,which_half

if_z          mov       temp,#1
if_nz         mov       temp,#2
              wrlong    temp,flag_addr


              cmp       counting,#0             wz
if_z          mov       cycles_total,#0
if_z          mov       completed,#0
if_z          jmp       #:write_totals
              cmp       completed,#0            wz
if_nz         jmp       #:save_totals
              cmp       start_time,begin_time   wz
if_nz         mov       cycles_total,#0
if_nz         mov       completed,#0
if_nz         jmp       #:write_totals

:save_totals
              add       cycles_total,cycles_cnt
              add       completed,#1
:write_totals
              wrlong    cycles_total,cycles_addr
              wrlong    completed,complete_addr
              mov       cycles_cnt,#0

              mov       begin_time,cnt
              mov       start_time,begin_time
              jmp       #:loop                          'wait for next sample period
'
'
' Plot
'
plot          mov       asm_mask,#1                     'compute pixel mask
              shl       asm_mask,x
              shl       y,#6                            'compute pixel address
              add       y,asm_pixels
              shr       x,#5
              shl       x,#2
              add       y,x
              rdlong    asm_data,y                      'xor pixel
              xor       asm_data,asm_mask
              wrlong    asm_data,y

plot_ret      ret                            
'
'
' Data
'
'asm_cycles    long      |< bits - 1                     'sample time
asm_cycles    long      sample_rate - 1                 'sample time
asm_dira      long      $00000200                       'output mask
asm_pixels    long      0                               'pixel base (set at runtime)
asm_ypos      long      0                               'y positions (set at runtime)
average_cnt   long      1
peak_cnt      long      1
peak_load     long      512
mode          long      0
bignum        long      $FFFFFFFF
average_load  long      |< averaging

minus_one     long      -1
prev_cross    long      0

cycles_cnt    long      0
cycles_total  long      0
completed     long      0
counting      long      0
start_time    long      0
begin_time    long      0


'Added to export
temp          long      0
which_half    long      0
top_half      long      1024        '2 bytes per word, half way through the 1024 word array
output_pos    long      0
buffer_addr   res       1
flag_addr     res       1
cycles_addr   res       1
complete_addr res       1

'Filter
asm_fir_busy  res       1
asm_fir_data  res       1

asm_justify   res       1
trig_min      res       1
trig_max      res       1
average       res       1
asm_cnt       res       1
asm_old       res       1
asm_sample    res       1
asm_mask      res       1
asm_data      res       1
xpos          res       1
x             res       1
y             res       1
peak_min      res       1
peak_max      res       1


dat {{
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
