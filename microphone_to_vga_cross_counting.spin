''***************************************
''*  Microphone-to-VGA v1.1             *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2006 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************
''*  Modified by Pete Hemery for Final Year Project 
''*  Released 2012-06-19                *
''***************************************                
''
'' This program uses the Propeller Demo Board, Rev C
''
'' The microphone input is digitized and the samples are displayed on
''  a VGA monitor. The 'threshold' constant controls a Schmitt trigger, 
''  which is placed above and below zero.
'' It's used to accurately count the number of times the 
''  wave crosses zero by measuring it as a square wave.
'' The number of CPU cycles between crossings is stored and then averaged.
'' When 100 crossings (50 waves) have been detected,
''  the frequency and note offset is output on the serial console. 
''-----------------------

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  tiles    = vga#xtiles * vga#ytiles
  tiles32  = tiles * 32

  CLK_FREQ = ((_clkmode-xtal1)>>6)*_xinfreq

  sample_rate = CLK_FREQ / (1000 * KHz)  'Hz

  averaging = 15                '2-power-n samples to compute average with
  attenuation = 2               'try 0-4
  threshold = $18               'for detecting peak amplitude

  KHz = 20


OBJ


  vga : "vga_512x384_bitmap"
  pst : "Parallax Serial Terminal"
  f32 : "Float32"            

VAR

  long  pst_on                   

  long  flag
  long  sample_cnt

  long  sample_ones[10]
  long  sample_tens[10] '10 sets of how many samples counted per zero-crossing  

  long  prev_freq

  long  sync, pixels[tiles32]
  word  colors[tiles], ypos[512]



PUB start | f, i, iten, freq, time, samples

  'start vga
  vga.start(16, @colors, @pixels, @sync)

  'init colors to cyan on black
  repeat i from 0 to tiles - 1
    colors[i] := $3C00

  'fill top line so that it gets erased by COG
  longfill(@pixels, $FFFFFFFF, vga#xtiles)

  if ina[31] == 1                            'Check if we're connected via USB
    pst_on := 1

    pst.start(115200)
'  waitcnt(clkfreq + cnt)
    pst.Clear
  else
    pst_on := 0

  long[@flag] := 0
  f := 0
  F32.start                       

  'implant pointers and launch assembly program into COG
  asm_pixels := @pixels
  asm_ypos := @ypos

  cognew(@asm_entry, @flag)

  if pst_on == 1
    pst.str(string("Sample Rate: "))
    pst.dec(sample_rate)
    pst.newline


  time := F32.FDiv(F32.FFloat(1),F32.FDiv(F32.FFloat(CLK_FREQ),F32.FFloat(sample_rate)))
  if pst_on == 1
    time := F32.FMul(time,F32.FFloat(1000))               'to ms
    pst.str(string("Time Taken: "))
    pst.dec(F32.FRound(time))
    pst.str(string("."))
    pst.dec(F32.FRound(F32.FMul(time,F32.FFloat(10)))//10)
    pst.dec(F32.FRound(F32.FMul(time,F32.FFloat(100)))//10)
    pst.dec(F32.FRound(F32.FMul(time,F32.FFloat(1000)))//10)
    pst.str(string(" ms",pst#NL))
    time := F32.FDiv(time,F32.FFloat(1000))               'to secs for Hz conversion

  i := iten := 0

  repeat
    repeat while long[@flag] == f
    f := long[@flag]
    if f == 0
{      if pst_on == 1
        pst.str(string("STOPPED COUNTING",pst#NL))
}
      i := iten := 0
      next


    samples := long[@sample_cnt]
{    pst.str(string("Sample Count: "))
    pst.dec(samples)
    pst.newline
}
    sample_ones[i] := samples

    i += 1
    if i == 10
{      pst.str(string("Tens: "))
      pst.dec(iten)
      pst.newline
}
      samples := 0
      repeat i from 0 to 9        'average last 10 values of sample_count
        samples += sample_ones[i]

      sample_tens[iten] := samples
      iten += 1
      if iten == 10
{        pst.str(string("Huns: "))
        pst.dec(ihun)
        pst.newline
}
        samples := 0
        iten := 0
        repeat i from 0 to 9
         samples += sample_tens[i]

         ''For 100 zero crossings, there should be 50 complete waves
        freq := F32.FDiv( F32.FFloat(1), F32.FMul( F32.FDiv(F32.FFloat(samples) , F32.FFloat(50)) , time ) )

        if prev_freq  > F32.FRound(freq) - 5 AND prev_freq  < F32.FRound(freq) + 5
          if pst_on == 1
            pst.str(string("Frequency: "))
            pst.dec(F32.FTrunc(freq))
            pst.str(string("."))
            pst.dec(F32.FTrunc(F32.FMul(freq,F32.FFloat(10)))//10)
            pst.dec(F32.FTrunc(F32.FMul(freq,F32.FFloat(100)))//10)
            pst.dec(F32.FTrunc(F32.FMul(freq,F32.FFloat(1000)))//10)
            pst.str(string(" Hz",pst#NL))

          note_worthy(freq)
        prev_freq := F32.FRound(freq)
        
      i := 0



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
  if pst_on

    pst.str(string("Freq: "))
    pst.dec(F32.FTrunc(freq))
    pst.char(".")
    pst.dec(F32.FTrunc(F32.FMul(freq,F32.FFloat(100)))//100)
    pst.str(string("Hz",pst#NL))

    'lnote = log(f / 440) / log(2)
  lnote := F32.FDiv(F32.Log(F32.FDiv(freq,F32.FFloat(440))),F32.Log(F32.FFloat(2)))

    'octave = lnote + 4
  oct := F32.FAdd(lnote,F32.FFloat(4))
{
  pst.str(string("Octave: "))
  pst.dec(F32.FTrunc(oct))
  pst.char(" ")
}
    'note = ( octave - trunc(octave) ) * 12
  note := F32.FMul(F32.FSub(oct,F32.FFloat(F32.FTrunc(oct))),F32.FFloat(12))

    'cents = ( note - trunc(note) ) * 100
  cents := F32.FRound(F32.FMul(F32.FSub(note,F32.FFloat(F32.FTrunc(note))),F32.FFloat(100)))
{
  pst.str(string("Cents: "))
  pst.dec(cents)
  pst.char(" ")
  pst.newline
}
  oct := F32.FTrunc(oct)
  note := F32.FRound(note)

  if cents == 100
    cents := 0

  if cents > 50
    cents := cents - 100

  if note > 2                   'Octaves increment on the letter C
    oct := oct + 1

  if note > 11                  'catch a roll over
    note := 0

  if pst_on                     'only print if serial is connected
    pst.str(string("Note: "))

    pst.dec(oct)
    pst.char(" ")
  char1 := note_table[note*2]   'fetch relevant character from table below
  char2 := note_table[(note*2)+1]
  if pst_on
    pst.char(char1)
    pst.char(char2)

    pst.newline
    pst.str(string("Cents: "))
    pst.dec(cents)
    pst.char(" ")
    pst.newline
    pst.newline

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
'
' Assembly program
'
              org       0

asm_entry     mov       flag_addr,PAR
              mov       sample_count_addr,flag_addr
              add       sample_count_addr,#4
                                                        

              mov       dira,asm_dira                   'make pin 8 (ADC) output

              movs      ctra,#8
              movd      ctra,#9
              movi      ctra,#%01001_000                'POS W/FEEDBACK mode for CTRA
              mov       frqa,#1

              mov       xpos,#0

              mov       counting,#0
              
              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

              
:loop         waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get differenc
              sub       asm_sample,asm_old
              add       asm_old,asm_sample

:avg
              add       average,asm_sample              'compute average periodically so that
              djnz      average_cnt,#:avgsame           'we can 0-justify samples
              mov       average_cnt,average_load
              shr       average,#averaging
              mov       asm_justify,average
              mov       average,#0                      'reset average for next averaging
'ensure counting trigger threshold is relative to an accurate average
              cmp       thresh_on,#0            wz
if_nz         sub       thresh_on,#1
if_nz         jmp       #:avgsame

              mov       thresh_min,asm_justify
              sub       thresh_min,half_thresh
              mov       thresh_max,asm_justify
              add       thresh_max,half_thresh

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


:threshold_test
              tjnz      thresh_on,#:triggers
'if sample amplitudes are above the defined threshold,
' start counting number of samples between 0 crossings
              mov       x,trig_max                      'check if trigger values are greater than threshold
              sub       x,trig_min
              cmp       x,#threshold            wc      'carry is written if dest is less than source
              cmp       counting,#0             wz

if_c          mov       counting,#0                     'under threshold, clear flag/stop counting
if_nc         mov       counting,#1                     'above threshold, start counting

if_nz_and_c   mov       samples_cnt,#0                  'if counting was 1 and samples are below threshold, reset variables
if_nz_and_c   mov       samples_total,#0

if_nz_and_c   mov       temp,#0
if_nz_and_c   wrlong    temp,flag_addr



'Look for zero crossings
:zero_check
              cmp       counting,#0             wz
if_z          mov       samples_cnt,#0
if_z          jmp       #:triggers

              add       samples_cnt,#1                  'keep track of number of samples taken

              cmp       square_wave,#1          wz      'wait for negative trigger threshold
if_z          cmp       asm_sample,thresh_min   wc      'carry is set if dest is less than src
if_z_and_c    mov       square_wave,#2
if_z_and_c    jmpret    countretaddr,#count_crossings
if_z          jmp       #:triggers

              cmp       square_wave,#2          wz      'wait for positive trigger threshold
if_z          cmp       asm_sample,thresh_max   wc
if_z_and_nc   mov       square_wave,#1
if_z_and_nc   jmpret    countretaddr,#count_crossings

'Set triggers
:triggers
              cmp       mode,#0                 wz      'wait for negative trigger threshold
if_z          cmp       asm_sample,trig_min     wc
if_z_and_c    mov       mode,#1
if_z          jmp       #:loop

              cmp       mode,#1                 wz      'wait for positive trigger threshold
if_z          cmp       asm_sample,trig_max     wc
if_z_and_nc   mov       mode,#2
if_z          jmp       #:loop

:justify
              sub       asm_sample,asm_justify          'justify sample to bitmap center y
              sar       asm_sample,#attenuation         'this # controls attenuation (0=none)
              add       asm_sample,#384 / 2
              mins      asm_sample,#0
              maxs      asm_sample,#384 - 1

:out_with_the_old
              mov       x,xpos                          'xor old pixel off
              shl       x,#1                            'word aligned offset into array
              add       x,asm_ypos                      'add array address
              rdword    y,x                             'get old pixel-y
              wrword    asm_sample,x                    'save new pixel-y
              mov       x,xpos
              call      #plot

:in_with_the_new
              mov       x,xpos                          'xor new pixel on
              mov       y,asm_sample
              call      #plot

              add       xpos,#1                         'increment x position and mask
              and       xpos,#$1FF              wz
if_z          mov       mode,#0                         'if rollover, reset mode for trigger

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
' Count number of zero crossings
'
count_crossings
              cmp       samples_cnt,#0          wz
if_z          jmp       countretaddr

              mov       samples_total,samples_cnt
              mov       samples_cnt,#0

              wrlong    samples_total, sample_count_addr
              wrlong    square_wave,flag_addr

              mov       temp,#0                 wz      'make sure zero flag is set upon return
count_crossings_ret jmp countretaddr

              fit
'
'
' Data
'
'asm_cycles    long      |< bits - 1                    'sample time
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


'Counting Specific Data
'Flags
counting      long      0
square_wave   long      1

samples_cnt   long      0
samples_total long      0

'Threshold for counting
half_thresh   long      threshold / 2
thresh_on     long      4
thresh_min    res       1
thresh_max    res       1                        

'Exported
flag_addr     res       1
sample_count_addr res   1

'Useful others
temp          res       1
countretaddr  res       1


'demo originals
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


dat 
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
