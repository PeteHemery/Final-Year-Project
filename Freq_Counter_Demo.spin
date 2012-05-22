''*****************************************
''*  Frequency Counter Tuner v1.0         *
''*  Author: Pete Hemery                  *
''*  See end of file for terms of use.    *
''*  Modified from Microphone-to-VGA v1.0 *
''*  By Chip Gracey                       *
''*****************************************

'' This program uses the Propeller Demo Board, Rev C
''
'' The microphone is digitized and the number of samples between zero crossings is counted.
'' This is then sent to the spin cog for averaging and if a note is detected, information
'' is displayed on the VGA or serial console.
''
''-----------------------
''Modified Mic-VGA demo for Undergraduate Project 2011-2012
''VGA Displays detected frequency, note, octave and cent offset from microphone input.

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode-xtal1)>>6)*_xinfreq

  sample_rate = CLK_FREQ / (1000 * KHz)  'Hz

  averaging = 10                '2-power-n samples to compute average with
  attenuation = 1               'try 0-4
  threshold = $18               'for detecting peak amplitude and zero crossing
                                '$16 is the lowest without detecting any background noise
    KHz = 7

  timeout = 30_000


OBJ

  fir : "fir_filter_7k"         '1.5 KHz cut off low-pass filter
  pst : "Parallax Serial Terminal"
  f32 : "Float32"
  gui : "GUI_Demo"

VAR
  long  fir_busy, fir_data
  long  flag
  long  sample_cnt

  long  sample_ones[10]
  long  sample_tens[10] '10 sets of 'how many samples counted per zero-crossing'
  long  sample_huns[10]

  long  prev_freq

  long  pst_on


PUB start | f, i, iten, freq, time, samples, screen_timeout, x, y

  long[@flag] := 0

  'start vga
  gui.start

  'start floating point engine
  F32.start
  'start filter impulse response engine
  fir.start(@fir_busy)
  if ina[31] == 1                            'Check if we're connected via USB
    pst_on := 1
    'start serial com
    pst.start(115200)
    pst.Clear
  else
    pst_on := 0


  'launch assembly program into COG
  f := cognew(@asm_entry, @flag)

  if pst_on                                             'only use serial if connected
    pst.str(string("Sampler Cog: "))
    pst.dec(f)
    pst.newline

    pst.str(string("Sample Rate: "))
    pst.dec(sample_rate)
    pst.newline


  time := F32.FDiv(F32.FFloat(1),F32.FDiv(F32.FFloat(CLK_FREQ),F32.FFloat(sample_rate)))
  if pst_on

    time := F32.FMul(time,F32.FFloat(1000))               'to ms for display
    pst.str(string("Time Taken per Sample: "))
    pst.dec(F32.FTrunc(time))
    pst.str(string("."))
    pst.dec(F32.FTrunc(F32.FMul(time,F32.FFloat(10)))//10)
    pst.dec(F32.FTrunc(F32.FMul(time,F32.FFloat(100)))//10)
    pst.dec(F32.FTrunc(F32.FMul(time,F32.FFloat(1000)))//10)
    pst.str(string(" ms",pst#NL))
    time := F32.FDiv(time,F32.FFloat(1000))               'to secs for Hz conversion

  f := i := iten := 0

  screen_timeout := timeout
  repeat
    repeat while long[@flag] == f
    'while waiting for a new value, countdown to reset display variables
      if screen_timeout <> 0
        screen_timeout -= 1
      if screen_timeout == 1
        gui.reset_display

    f := long[@flag]            'f is the local copy of the flag register
    if f == 0                   '0 indicates wave is below threshold level. 1 or 2 is square wave value
      i := iten := 0
{      if pst_on
        pst.str(string("STOPPED COUNTING",pst#NL))
}
      next

    samples := long[@sample_cnt]
{
    if pst_on
      pst.str(string("Sample Count: "))
      pst.dec(samples)
      pst.newline
}
    sample_ones[i] := samples

    i += 1
    'i used to keep track of incoming samples 1-10 (well, 0-9)
    'once 10 is reached, i is used as for loop variable, then reset to 0
    if i == 10
      samples := 0
      repeat i from 0 to 9        'sum last 10 values of sample_count for averaging
        samples += sample_ones[i]
      sample_tens[iten] := samples
      iten += 1
      if iten == 10
        samples := 0
        iten := 0
        repeat i from 0 to 9                            'sum last 100 sample_count values
         samples += sample_tens[i]

        'since there are 2 zero crossings per wave, divide by 50 instead of 100
        ''frequency = 1 / (number of waves * time taken)
        freq := F32.FDiv( F32.FFloat(1), F32.FMul( F32.FDiv(F32.FFloat(samples) , F32.FFloat(50)) , time ) )

        'frequency can vary wildly before settling down, so check against previous value
        if prev_freq  > F32.FRound(freq) - 5 AND prev_freq  < F32.FRound(freq) + 5
          screen_timeout := timeout
          note_worthy(freq)
        else
          'if new value isn't the same as previous, countdown to reset display variables
          if screen_timeout <> 0
            screen_timeout -= 1
          if screen_timeout == 1
            gui.reset_display

        prev_freq := F32.FRound(freq) 'save the current freq for comparison next iteration

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
  if note < 0
    note := 11

  if pst_on                     'only print debug if serial is connected
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

  freq := F32.FRound(F32.FMul(freq,F32.FFloat(100)))    'update routine takes int freq value scaled up by 100
  gui.update(oct,char1,char2,cents,freq)                'display the updated values

  
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
' Assembly program  - Microphone sampler with FIR filtering.
'
              org       0

asm_entry     mov       flag_addr,PAR
              mov       sample_count_addr,flag_addr
              add       sample_count_addr,#4

              mov       asm_fir_busy,flag_addr
              sub       asm_fir_busy,#8
              mov       asm_fir_data,flag_addr
              sub       asm_fir_data,#4

              mov       dira,asm_dira                   'make pin 8 (ADC) output

              movs      ctra,#8
              movd      ctra,#9
              movi      ctra,#%01001_000                'POS W/FEEDBACK mode for CTRA
              mov       frqa,#1

              mov       counting,#0

              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

              
:loop         waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get difference
              sub       asm_sample,asm_old
              add       asm_old,asm_sample

'Filtering
              wrlong    asm_sample,asm_fir_data
              mov       temp,#1
              wrlong    temp,asm_fir_busy

:fir_loop     rdlong    temp,asm_fir_busy
              tjnz      temp,#:fir_loop
              rdword    asm_sample,asm_fir_data
'

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
              mov       temp,peak_max                   'compute min+12.5% and max-12.5%
              sub       temp,peak_min
              shr       temp,#3
              mov       trig_min,peak_min
              add       trig_min,temp
              mov       trig_max,peak_max
              sub       trig_max,temp
              mov       peak_min,bignum                 'reset peak detectors
              mov       peak_max,#0
:pksame


'if sample amplitudes are above the defined threshold,
' start counting number of samples between 0 crossings
:threshold_test
              tjnz      thresh_on,#:loop
              mov       temp,trig_max                   'check if trigger values are greater than threshold
              sub       temp,trig_min
              cmp       temp,#threshold         wc      'carry is written if dest is less than source
              cmp       counting,#0             wz

if_c          mov       counting,#0                     'under threshold, clear flag/stop counting
if_nc         mov       counting,#1                     'above threshold, start counting

if_nz_and_c   mov       samples_cnt,#0                  'if counting was 1 and samples are below threshold, reset the counter

if_nz_and_c   mov       temp,#0
if_nz_and_c   wrlong    temp,flag_addr



'Look for zero crossings
:zero_check
              cmp       counting,#0             wz
if_z          mov       samples_cnt,#0
if_z          jmp       #:loop

              add       samples_cnt,#1                  'keep track of number of samples taken

'square_wave is used as the flag variable to alert the spin cog of a change. 0 is 'not counting'
              cmp       square_wave,#1          wz      'wait for negative trigger threshold
if_z          cmp       asm_sample,thresh_min   wc      'carry is set if dest is less than src
if_z_and_c    mov       square_wave,#2
if_z_and_c    jmp       #:count_crossings

              cmp       square_wave,#2          wz      'wait for positive trigger threshold
if_z          cmp       asm_sample,thresh_max   wc
if_z_and_nc   mov       square_wave,#1
if_z_and_nc   jmp       #:count_crossings
              jmp       #:loop
'
'
' Count number of zero crossings
'
:count_crossings
              cmp       samples_cnt,#0          wz
if_z          jmp       #:loop

              wrlong    samples_cnt, sample_count_addr
              mov       samples_cnt,#0
              wrlong    square_wave,flag_addr

              mov       temp,#0                 wz      'make sure zero flag is set upon return
              jmp       #:loop
'count_crossings_ret jmp countretaddr

              fit       $1F0
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


'Counting Specific Data
'Flags
counting      long      0
square_wave   long      1
'Sample Counter
samples_cnt   long      0

'Threshold for counting
half_thresh   long      threshold / 2
thresh_on     long      4
thresh_min    res       1                       'res instructions MUST come last in a dat block
thresh_max    res       1                       'it reserves memory but doesn't allocate it, shifting the address pointer
                                                'contains whatever happens to be in cog ram at the time
'Filter
asm_fir_busy  res       1
asm_fir_data  res       1

'External Communication
flag_addr     res       1
sample_count_addr res   1

'Useful others
temp          res       1


'demo originals
asm_justify   res       1
trig_min      res       1
trig_max      res       1
average       res       1
asm_cnt       res       1
asm_old       res       1
asm_sample    res       1
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
