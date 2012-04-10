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
'-----------------------
''Modified by Pete Hemery for Undergraduate Project 2011-2012
''Displays detected frequency, note, octave and cent offset from microphone input.

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode-xtal1)>>6)*_xinfreq
  MS_001 = CLK_FREQ / 1_000

 ' sample_rate = CLK_FREQ / (1024 * KHz)  'Hz
  sample_rate = MS_001 / KHz
'  time_taken =(((sample_rate / 8) * 512) / 10)   '80MHz/8 then /10 because of rounding errors.
                                                 'time for 512 samples * refresh_num -> in microseconds
  time_taken = (sample_rate * 512) / 1_000



  averaging = 10                '2-power-n samples to compute average with
  attenuation = 4               'try 0-4
  threshold = $2F                'for detecting peak amplitude

  KHz = 6


OBJ

'  fir : "fir_filter_4k"
'  fir : "fir_filter_5k"
  fir : "fir_filter_6k"
'  fir : "fir_filter_7k"

  pst : "Parallax Serial Terminal"
  f32 : "Float32"
  gui : "GUI_Demo"

VAR
  long fir_busy, fir_data
  long flag
  long cycles_count
  long completed_count
  long sampler_clock


PUB start | f, i, p, startTime, endTime, freq, time, running_total, freq_average

  'start vga
  gui.start
  F32.start
  fir.start(@fir_busy)

  pst.start(115200)
'  waitcnt(clkfreq + cnt)
  pst.Clear
  long[@flag] := 0


  'launch assembly program into COG
  f := cognew(@asm_entry, @flag)

  pst.str(string("Time Taken: "))
  pst.dec(time_taken)
  pst.newline
  pst.str(string("Cog: "))
  pst.dec(f)
  pst.newline


  repeat
    repeat while long[@flag] == f
    f := long[@flag]
    if(time := long[@completed_count])

      pst.str(string("time: "))
      pst.dec(time)
      pst.newline

      time := (time * time_taken) / 1_000
      pst.str(string("time: "))
      pst.dec(time)
      pst.newline

      freq := long[@cycles_count] / long[@completed_count]
      pst.str(string("freq: "))
      pst.dec(freq)
      pst.newline


      freq := freq / time

      freq_average += freq

      pst.str(string("freq: "))
      pst.dec(freq)
      pst.newline


      if running_total > 1_000_000
        running_total := freq
        p := 2

      if (p <> 0)
        freq_average /= 2
      else
        running_total := 0

    if (p => 2)
      time := (p * time_taken) / 100
      pst.str(string("completed_count: "))
      pst.dec(p)
      pst.newline
      pst.str(string("Freq: "))
      pst.dec(freq_average/100)
      pst.char(".")
      pst.dec(freq_average//100)
      pst.str(string("Hz",pst#NL))

      if freq_average < 0
        freq_average := 0

      if ((p // KHz) == 0) AND freq > 0
        note_worthy(freq_average)

    p := long[@completed_count]

    
PRI note_worthy(freq) | i, j, lnote, oct, cents, note, char1, char2
{{
           n / 12
  f = (2 ^        ) x 440 Hz

  note = (log2(f / 440)) x 12

  This uses A4 as the centre octave of 0. So offset by 4.
  
  octaves automatically yield factors of two times the original frequency,
   since n is therefore a multiple of 12
   (12k, where k is the number of octaves up or down), and so the formula reduces to:

           12k / 12                    k          
  f = (2 ^          ) x 440   =   (2 ^   ) x 440

  code:  
  lnote = log2(f / 440)
  lnote = log(f / 440) / log(2)
                                 
  octave = lnote + 4

  note = ( octave - truncated (octave) ) * 12 
  
  cents = (note - truncated (note) ) * 100


}}

  pst.str(string("freq: "))
  pst.dec(freq)
  pst.char(" ")
  pst.newline

{  Input parameter freq is scaled up by 100 when passed into this function.}

    'lnote = log(f / 440) / log(2)
  lnote := F32.FDiv(F32.Log(F32.FDiv(F32.FFloat(freq),F32.FFloat(44000))),F32.Log(F32.FFloat(2)))
                        
    'octave = lnote + 4      
  oct := F32.FAdd(lnote,F32.FFloat(4))

  pst.str(string("Octave: "))
  pst.dec(F32.FTrunc(oct))
  pst.char(" ")
  pst.newline

    'note = ( octave - trunc(octave) ) * 12
  note := F32.FMul(F32.FSub(oct,F32.FFloat(F32.FTrunc(oct))),F32.FFloat(12)) 

  pst.str(string("Note: "))
  pst.dec(F32.FRound(note))
  pst.char(" ")
  pst.newline
              
    'cents = ( note - trunc(note) ) * 100
  cents := F32.FRound(F32.FMul(F32.FSub(note,F32.FFloat(F32.FTrunc(note))),F32.FFloat(100)))
               
  pst.str(string("Cents: "))
  pst.dec(cents)
  pst.char(" ")
  pst.newline
                       
  oct := F32.FTrunc(oct)                     
  note := F32.FRound(note)

  if (cents > 50)
    note := note + 1
    cents := cents - 100
   
  if (note > 2)               'Octaves increment on the letter C
    oct := oct + 1                             
      
  if (note > 11)              'catch a roll over
    note := 0                                         
    
  pst.dec(note)
  pst.char(" ")

  char1 := note_table[note*2]
  char2 := note_table[(note*2)+1]
  pst.char(char1)
  pst.char(char2)

  pst.newline            

  pst.str(string("Final: Octave: "))
  pst.dec(oct)
  pst.char(" ")
  pst.newline

  pst.str(string("Note: "))
  pst.dec(note)
  pst.char(" ")
  pst.newline
  pst.str(string("Cents: "))
  pst.dec(cents)
  pst.char(" ")
  pst.newline
  pst.newline          


  

  gui.update(oct,char1,char2,cents,freq)

  
DAT
note_table    byte      "A"," "
              byte      "A","#"
              byte      "B"," "
              byte      "C"," "
              byte      "C","#"
              byte      "D"," "
              byte      "D","#"
              byte      "E"," "
              byte      "F"," "
              byte      "F","#"
              byte      "G"," "
              byte      "G","#"

DAT

'
' Assembly program  - Microphone sampler with optional FIR filtering.
'
              org       0

asm_entry     mov       flag_addr,PAR
              mov       cycles_addr,flag_addr
              add       cycles_addr,#4
              mov       complete_addr,cycles_addr
              add       complete_addr,#4
              mov       clock_addr,complete_addr
              add       clock_addr,#4

              mov       asm_fir_busy,flag_addr
              sub       asm_fir_busy,#8
              mov       asm_fir_data,flag_addr
              sub       asm_fir_data,#4

              mov       dira,asm_dira                   'make pin 8 (ADC) output

              movs      ctra,#8
              movd      ctra,#9
              movi      ctra,#%01001_000                'POS W/FEEDBACK mode for CTRA
              mov       frqa,#1


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


:triggers
              cmp       mode,#0                 wz      'wait for negative trigger threshold
if_z          cmp       asm_sample,trig_min     wc
if_z_and_c    mov       mode,#1
if_z          jmp       #:loop

              cmp       mode,#1                 wz      'wait for positive trigger threshold
if_z          cmp       asm_sample,trig_max     wc
if_z_and_nc   mov       mode,#2
if_z          jmp       #:loop

'' Check number of 0 crossings
{              cmps      average,asm_sample      wc  'carry is written if source is larger
if_nc         jmp       #:less
              mov       prev_cross,#1           ' Sample is more than 0
              jmp       #:justify               ' Don't count it
' Sample is less than 0
:less         cmps      prev_cross,#0           wc
if_c          jmp       #:justify               'Last crossing was also below 0
              mov       prev_cross,minus_one

'              mov       temp,peak_max
'              sub       temp,peak_min
}
              mov       temp,trig_max
              sub       temp,trig_min
              cmp       temp,asm_threshold         wc'carry is written if source is larger

if_c          mov       counting,#0             'under threshold, let the end know
if_c          mov       completed,#0
if_c          mov       cycles_cnt,#0

if_c          jmp       #:triggers

              cmp       counting,#0             wz

if_nz_and_nc  add       cycles_cnt,#1           'if we're counting already, keep counting

if_z          mov       start_time,cnt          'above threshold, setup counting
if_z          mov       counting,#1


:justify
              sub       asm_sample,asm_justify          'justify sample to bitmap center y
              sar       asm_sample,#attenuation         'this # controls attenuation (0=none)

              add       xpos,#1                         'increment x position and mask
              and       xpos,#$1FF              wz
if_nz         jmp       #:loop                          'wait for next sample period
              mov       mode,#0                         'if rollover, reset mode for trigger
              rdlong    temp,flag_addr
              cmp       temp,#2                 wz
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
'              wrlong    cycles_cnt,cycles_addr
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
asm_threshold long      threshold

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
flag_addr     res       1
cycles_addr   res       1
complete_addr res       1
clock_addr    res       1

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
