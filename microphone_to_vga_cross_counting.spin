''***************************************
''*  Microphone-to-VGA v1.0             *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2006 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************

'' This program uses the Propeller Demo Board, Rev C
''
'' The microphone is digitized and the samples are displayed on a VGA monitor, just like
'' an oscilloscope with triggering.
''
''-----------------------
''Modified by PH for Final Year Project 2011-2012

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  tiles    = vga#xtiles * vga#ytiles
  tiles32  = tiles * 32

  CLK_FREQ = ((_clkmode-xtal1)>>6)*_xinfreq
  MS_001 = CLK_FREQ / 1_000

  sample_rate = CLK_FREQ / (1000 * KHz)  'Hz

  averaging = 10                '2-power-n samples to compute average with
  attenuation = 1               'try 0-4
  threshold = $2f               'for detecting peak amplitude

  KHz = 50


OBJ


  vga : "vga_512x384_bitmap"
  pst : "Parallax Serial Terminal"
  f32 : "Float32"

VAR

  long flag
  long sample_count[10] '10 sets of how many samples counted per zero-crossing

  long  sync, pixels[tiles32]
  word  colors[tiles], ypos[512]



PUB start | f, i, freq, time, samples

  'start vga
  vga.start(16, @colors, @pixels, @sync)

  'init colors to cyan on black
  repeat i from 0 to tiles - 1
    colors[i] := $3C00

  'fill top line so that it gets erased by COG
  longfill(@pixels, $FFFFFFFF, vga#xtiles)


  pst.start(115200)
'  waitcnt(clkfreq + cnt)
  pst.Clear
  long[@flag] := 0
  f := 0
  F32.start

  'implant pointers and launch assembly program into COG
  asm_pixels := @pixels
  asm_ypos := @ypos

  cognew(@asm_entry, @flag)

  pst.str(string("Sample Rate: "))
  pst.dec(sample_rate)
  pst.newline


  time := F32.FDiv(F32.FFloat(1),F32.FDiv(F32.FFloat(CLK_FREQ),F32.FFloat(sample_rate)))
  time := F32.FMul(time,F32.FFloat(1000))               'to ms
  pst.str(string("Time Taken: "))
  pst.dec(F32.FRound(time))
  pst.str(string("."))
  pst.dec(F32.FRound(F32.FMul(time,F32.FFloat(10)))//10)
  pst.dec(F32.FRound(F32.FMul(time,F32.FFloat(100)))//10)
  pst.dec(F32.FRound(F32.FMul(time,F32.FFloat(1000)))//10)
  pst.str(string(" ms",pst#NL))
  time := F32.FDiv(time,F32.FFloat(1000))               'to secs for Hz conversion

  repeat
    repeat while long[@flag] == f
    f := long[@flag]

    samples := sample_count[0]
{
    time := 0
    repeat i from 0 to 9        'average last 10 values of sample_count
      time += sample_count[i]
      pst.str(string("sample count:"))
      pst.dec(sample_count[i])
      pst.newline
    time /= 10

    pst.str(string("Averaged number of samples: "))
}
    pst.str(string("Number of samples: "))
    pst.dec(samples)
    pst.newline

    freq := F32.FDiv( F32.FFloat(1), F32.FMul( F32.FFloat(samples) , time ) )

    pst.str(string("Frequency: "))
    pst.dec(F32.FRound(freq))
    pst.str(string("."))
    pst.dec(F32.FRound(F32.FMul(freq,F32.FFloat(10)))//10)
    pst.dec(F32.FRound(F32.FMul(freq,F32.FFloat(100)))//10)
    pst.dec(F32.FRound(F32.FMul(freq,F32.FFloat(1000)))//10)
    pst.str(string(" Hz",pst#NL))

'    note_worthy(freq)


PRI note_worthy(freq) | i, j, lnote, oct, cents, offset, alpha, note

  lnote := F32.FAdd(F32.FDiv(F32.Log(F32.FDiv(freq,F32.FFloat(440))),F32.Log(2)),F32.FFloat(4))
  oct := F32.FFloat(F32.FTrunc(lnote))
  cents := F32.FRound(F32.FMul(F32.FSub(lnote,oct),F32.FFloat(1200)))


  pst.str(string("Freq: "))
  pst.dec(F32.FTrunc(freq))
  pst.char(".")
  pst.dec(F32.FRound(F32.FMul(freq,F32.FFloat(100)))//100)
  pst.str(string("Hz",pst#NL))

  pst.str(string("Octave: "))
  pst.dec(F32.FTrunc(oct))
  pst.char(" ")
  pst.newline

  pst.str(string("Cents: "))
  pst.dec(cents)
  pst.char(" ")
  pst.newline

  pst.str(string("Note: "))
  note := cents / 100
  cents //= 100
  if (cents > 50)
    note += 1
    cents := -100 + cents
  pst.dec(note)
  pst.char(" ")

  pst.char(note_table[note*2])
  pst.char(note_table[(note*2)+1])

  pst.newline

  pst.str(string("Cents: "))
  pst.dec(cents)
  pst.char(" ")
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
              
              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

              
:loop         waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get differenc
              sub       asm_sample,asm_old
              add       asm_old,asm_sample

              add       average,asm_sample              'compute average periodically so that
              djnz      average_cnt,#:avgsame           'we can 0-justify samples
              mov       average_cnt,average_load
              shr       average,#averaging
              mov       asm_justify,average
              mov       average,#0                      'reset average for next averaging
:avgsame

              max       peak_min,asm_sample             'track min and max peaks for triggering
              min       peak_max,asm_sample

'if samples are above the defined threshold, keep counting

              mov       x,peak_max                      'check if trigger points are greater than threshold
              sub       x,peak_min
              cmp       x,#threshold            wc      'carry is written if dest is less than source
              cmp       counting,#0             wz
if_nz         add       samples_cnt,#1                  'keep track of number of samples taken

if_z_and_nc   mov       counting,#1                     'above threshold, setup counting

if_nz_and_c   jmpret    resetretaddr,#reset_counting    'if counting = 1 and samples are below threshold, reset



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



'Check for zero crossing
              cmp       mode,#0                 wz      'wait for negative trigger threshold
if_z          cmp       asm_sample,trig_min     wc      'carry is set if dest is less than src
if_z_and_c    mov       mode,#1
if_z          cmp       counting,#1             wz
if_z_and_c    jmpret    countretaddr,#counting_crossings
if_z          jmp       #:loop

              cmp       mode,#1                 wz      'wait for positive trigger threshold
if_z          cmp       asm_sample,trig_max     wc
if_z_and_nc   mov       mode,#2
if_z          cmp       counting,#1             wz
if_z_and_nc   jmpret    countretaddr,#counting_crossings
if_z          jmp       #:loop

:justify
              sub       asm_sample,asm_justify          'justify sample to bitmap center y
              sar       asm_sample,#attenuation         'this # controls attenuation (0=none)

              add       asm_sample,#384 / 2
              mins      asm_sample,#0
              maxs      asm_sample,#384 - 1

              mov       x,xpos                          'xor old pixel off
              shl       x,#1                            'word aligned offset into array
              add       x,asm_ypos                      'add array address
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
counting_crossings
              mov       samples_total,samples_cnt
              mov       samples_cnt,#0

              wrlong    samples_total, sample_count_addr

{
if_z_and_nc   mov       counting,#1                     'above threshold, setup counting
if_c          mov       counting,#0                     'under threshold, clear the flags
if_c          mov       completed,#0

'this bit is where the adding and shift should go
'if_nz_and_nc  add       cycles_cnt,#1                  'if we're counting already, keep counting
}
              rdlong    temp,flag_addr
              cmp       temp,#2                 wz
if_z          mov       temp,#1
if_nz         mov       temp,#2
              wrlong    temp,flag_addr

              mov       temp,#0                 wz      'make sure zero flag is set upon return
counting_ret  jmp       countretaddr

reset_counting
              mov       counting,#0                     'under threshold, clear flag
              mov       last_ten_index,#0
              mov       last_hun_index,#0
              mov       last_thou_index,#0
              mov       samples_cnt,#0
              mov       samples_total,#0

reset_ret     jmp       resetretaddr
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
completed     long      0
counting      long      0


'Added to export
flag_addr     res       1
sample_count_addr   res       1

samples_cnt   res       1
samples_total res       1



'Totals of samples counted
last_ten      res       10
last_hundred  res       10
last_thousand res       10
'Indices
last_ten_index res      1
last_hun_index res      1
last_thou_index res      1

'Useful others
temp          res       1
countretaddr  res       1
resetretaddr  res       1

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
