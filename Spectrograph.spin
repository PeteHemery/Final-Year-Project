''*******************************************************
''*  Continuous Sampled FFT Input Prototype v1.0        *
''*  Author: Pete Hemery                                *
''*  01/12/2011                                         *
''*  See end of file for terms of use.                  *
''*******************************************************
''
'' This demonstrates the capabilities of the Propeller to handle multiple
'' parallel tasks simultaneously. It uses an audio sampler to take microphone samples
'' to populate input buffers for FFT operations.
'' The FFT objects output the resulting frequency
'' anaylsis by plotting pixels to a 320x240 pixel VGA display.
'' Between 1 and 4 FFT's can be used concurrently to handle increased sampling rate.
'' This can be changed using the constant below. The source code has been built to dynamically
'' allocated the required buffer sizes based on this constant.
''
'' Sampling rate is set in the constants section of the sampler object.
'' Low-Pass filtering has been provided for sample rates of 4, 5, 6 and 7 KHz.
''

CON

  _clkmode = xtal1+pll16x
  _xinfreq = 5_000_000

  tiles    = vga#xtiles * vga#ytiles
  tiles32  = tiles * 16

'  peaks    = 1
  num_of_ffts = 1               ''Only enough cogs for 3 FFTs and filtering
                                ''Disable filtering in sampler for a max of 4 FFTs
  TIMEOUT = 60000

VAR
  'serial com on flag
  long  pst_on

  long  sync,pixels[tiles32]
  word  colors[tiles]

  'keeping record of times taken for debug
  long  aud_flag, aud_time
  long  audio_flag_val, audio_flag_prev
  long  audio_time_val, audio_time_prev

  long  one_fft_flag
  long  fft_flag[num_of_ffts], fft_time[num_of_ffts]
  long  fft_flag_val[num_of_ffts], fft_flag_prev[num_of_ffts]
  long  fft_time_val[num_of_ffts], fft_time_prev[num_of_ffts]
'  long  fft_top[num_of_ffts*peaks]                     'tops used to detect spikes of frequency intensity

  'pointers for audio sampler cog
  long  audio_flag_ptr
  long  audio_time_ptr
  long  array_size

  long  fft_flag_ptr[num_of_ffts]
  long  buffer_ptr[num_of_ffts]

  'buffers for FFT cogs
  word  real_buffer[fft#NN*num_of_ffts]
  word  imag_buffer[fft#NN*num_of_ffts]

  long  hamming_window[fft#NN]
  word  one_fft_audio_buffer[fft#NN*((!(num_of_ffts >> 1)) & 1)]

OBJ

  vga   : "vga_320x240_bitmap"
  fft   : "fft"
  pst   : "Parallax Serial Terminal"                   ' Serial communication object
  aud   : "sampler"
  f32   : "Float32"

pub launch | i, j, vga_cog, pst_cog, audio_cog, countdown, audio_time, audio_max, audio_min, freq, temp
'' launch - This function starts the spectrograph demo.
''    Serial terminal is used for debug output.
''    The audio sampler is started with the first parameter of its consecutive Hub RAM pointers.
''    Multiple FFT objects can be instantiated, between 1 and 4.
''    These can be vary due to speed requirements and Hub RAM constraints.
''    Experimentation is encouraged =)

  f32.start
   'start vga
  vga_cog := vga.start(16, @colors, @pixels, @sync)

   'init colors to cyan on blue  '$2805
  repeat i from 0 to tiles - 1
    colors[i] := %%3100_0010    'gold on blue

  if ina[31] == 1                            'Check if we're connected via USB
    pst_on := 1
    pst_cog := pst.Start(115200)             'Start the Parallax Serial Terminal cog
    pst.NewLine
  else
    pst_on := 0

  waitcnt(clkfreq + cnt)                   'Pause 1 Second while we boot up
  setup_pointers


''Hamming Window
''
'' w(n) = 0.54 - 0.46 cos (2πn / N - 1)
'' w(0) = 0.54 + 0.46 cos (2πn / N - 1)
  pst.Str(String(pst#NL,"Start"))

  repeat i from 0 to (fft#NN / 2) -1
    long[@hamming_window][i] := F32.FSub(F32.FDiv(F32.FFloat(54),F32.FFloat(100)),F32.FMul(F32.FDiv(F32.FFloat(46),F32.FFloat(100)),F32.cos(F32.FDiv(F32.FMul(F32.FMul(F32.FFloat(2),pi),F32.FFloat(i)),F32.FFloat(fft#NN-1)))))

{    if i // 16 == 0
      pst.str(string(pst#NL,"        word  "))
    else
      pst.str(string(", "))
'    pst.dec(i)
'    pst.char(":")
'    pst.char(" ")
    pst.dec(F32.FRound(F32.FMul(long[@hamming_window][i],F32.FFloat(1024))))
    'pst.newline
}
  repeat

  if pst_on
    pst.Str(String(pst#NL,"Start"))
    pst.Str(String(pst#NL,"vga_cog: "))
    pst.Dec(vga_cog)
    pst.Str(String(pst#NL,"pst_cog: "))
    pst.Dec(pst_cog)

    pst.Str(String(pst#NL,"Number of FFTs: "))
    pst.Dec(num_of_ffts)

  repeat i from 0 to num_of_ffts - 1
    j := i*fft#NN
    fft_flag_val[i] := fft.start(@fft_flag[i],@fft_time[i],@real_buffer[j],@imag_buffer[j],@pixels)
    waitcnt(clkfreq/4 + cnt)
    if pst_on
      pst.Str(String(pst#NL,"j:"))
      pst.Dec(j)
      pst.Str(String(pst#NL,"FFT "))
      pst.Dec(i+1)
      pst.Str(String(" flag after launch: "))
      pst.Dec(fft_flag_val[i])
{      pst.Str(String(pst#NL,"flag val address: "))
      pst.Dec(@fft_flag_val[i])

      pst.Str(String(pst#NL,"flag address: "))
      pst.Dec(@fft_flag[i])
      pst.Str(String(pst#NL,"time address: "))
      pst.Dec(@fft_time[i])
      pst.Str(String(pst#NL,"real_buffer address: "))
      pst.Dec(@real_buffer[j])
      pst.Str(String(pst#NL,"imag_buffer address: "))
      pst.Dec(@imag_buffer[j])
}
      pst.Str(String(pst#NL,"flag value: "))
      pst.Dec(long[@fft_flag][i])
      pst.Str(String(pst#NL,"buffer pointer value: "))
      pst.Dec(long[@buffer_ptr][i])


  repeat i from 0 to num_of_ffts - 1
    fft_flag_prev[i] := fft_flag_val[i] := long[@fft_flag][i] 'use local variables to store status

  if pst_on
    pst.Str(String(pst#NL,"audio_flag on launch: "))
    pst.Dec(long[@aud_flag])

  audio_cog := aud.start(@audio_flag_ptr)

  if pst_on
    pst.Str(String(pst#NL,"audio_cog: "))
    pst.Dec(audio_cog)

'  waitcnt(clkfreq + cnt)                   'Pause 1 Second while we boot up
  audio_flag_prev := audio_flag_val := long[@aud_flag]
  if pst_on
    pst.Str(String(pst#NL,"Audio Flag value before loop: "))
    pst.Dec(long[@aud_flag])
    pst.newline
  waitcnt(clkfreq + cnt)                   'Pause 1 Second while we boot up
  audio_max := 0
  audio_min := 2_000_000

  repeat

    if countdown =< 0
      countdown := TIMEOUT
      longfill(@pixels, $0, tiles32)
    countdown--

    if num_of_ffts == 1
      if long[@one_fft_flag] == 0
        wordmove(@real_buffer,@one_fft_audio_buffer,fft#NN)
{        pst.Str(String(pst#NL,"Audio Output"))
        pst.dec(long[@one_fft_flag])
        pst.newline
}        repeat i from 0 to fft#NN -1
          word[@real_buffer][i] := F32.FRound(F32.FMul(F32.FFloat(~~word[@real_buffer][i]),hamming_window[i]))' & $FFFF
{
          pst.dec(i)
          pst.char(":")
          pst.char(" ")
          pst.dec(~~word[@real_buffer][i])
          pst.char(" ")
          pst.dec(F32.FRound(F32.FFloat(~~word[@real_buffer][i])))
          pst.char(" ")
          pst.dec(~~word[@real_buffer][i])
          pst.newline
}'        waitcnt(cnt + 1000)
        long[@one_fft_flag] := 1
        long[@fft_flag] := 0


    audio_flag_val := long[@aud_flag]
{    if audio_flag_val <> audio_flag_prev AND pst_on
'      pst.Position(0,24)
      audio_time_val := long[@aud_time]
      pst.Str(String(pst#NL,"Audio Flag value: "))
      pst.Dec(audio_flag_val)
      audio_flag_prev := audio_flag_val
      pst.Str(String(pst#NL,"Audio Cog took: "))
      audio_time := (||(audio_time_val - audio_time_prev))/(clkfreq/1000)
      pst.Dec(audio_time)
      pst.Str(String("ms"))
'        pst.Str(String(pst#NL,"Audio time value: "))
'        pst.Dec(audio_time_val)
      pst.ClearEnd

      audio_time_prev := audio_time_val

      if(audio_time < 100)
        if (audio_max < audio_time)
          audio_max := audio_time

          pst.Str(String(pst#NL,"Audio Cog max: "))
          pst.Dec(audio_max)
          pst.Str(String("ms"))
          pst.ClearEnd

        if (audio_min > audio_time)
          audio_min := audio_time

          pst.Str(String(pst#NL,pst#NL,"Audio Cog min: "))
          pst.Dec(audio_min)
          pst.Str(String("ms"))
          pst.ClearEnd
          pst.NewLine
}

    repeat i from 0 to num_of_ffts - 1
      fft_flag_val[i] := long[@fft_flag][i]
      fft_time_val[i] := long[@fft_time][i]
      if fft_flag_val[i] <> fft_flag_prev[i]
        if fft_flag_val[i] <> 0
'          pst.Position(0,34+(i*2))
{          pst.Str(String(pst#NL,"FFT "))
          pst.Dec(i+1)
          pst.Str(String(" took: "))
          pst.Dec((||(fft_time_val[i] - fft_time_prev[i]))/(clkfreq/1000))
          pst.Str(String("ms"))

          pst.Str(String("             flag: "))
'          pst.ClearEnd
          pst.Dec(fft_flag_val[i])
          pst.newline
}
        fft_flag_prev[i] := fft_flag_val[i]
        fft_time_prev[i] := fft_time_val[i]

        temp := 0
        if fft_flag_val[i] <> 0
'          pst.Str(String("FFT Output: ",pst#NL))
          repeat i from 24 to 200'(fft#NN /2) -1            '0 and 1 are always high, it looks like
'            if ~~word[@real_buffer][i] > ~~word[@real_buffer][i-1] + 10 OR ~~word[@real_buffer][i] > ~~word[@real_buffer][i+1] + 10
            if ~~word[@real_buffer][i] > 15
              temp := 1
{              pst.dec(i)
              pst.char(":")
              pst.char(" ")
              pst.dec(~~word[@real_buffer][i])
              pst.char(" ")}
              freq := F32.FMul(F32.FFloat(i),F32.FFloat(aud#KHz))
{              pst.dec(F32.FRound(freq))
              pst.char(" ")
              pst.char("H")
              pst.char("z")
              pst.newline}
              note_worthy(freq)

        if temp == 1
          pst.Str(String(pst#NL,"Notes Detected!",pst#NL))

PUB setup_pointers | i
  'setup list of pointers for sampler object
  long[@aud_flag] := 3+(num_of_ffts * 2)   'number of parameters being passed

  long[@audio_flag_ptr] := @aud_flag
  long[@audio_time_ptr] := @aud_time
  long[@array_size] := fft#NN

  if num_of_ffts == 1
    long[@fft_flag] := long[@one_fft_flag] := 1         'not ready to go
    long[@fft_flag_ptr] := @one_fft_flag
    long[@buffer_ptr] := @one_fft_audio_buffer
  else
    repeat i from 0 to num_of_ffts - 1
      long[@fft_flag][i] := 1         'not ready to go
      long[@fft_flag_ptr][i] := @fft_flag[i]
      long[@buffer_ptr][i] := @real_buffer[i*fft#NN]
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
'    pst.str(string("Note: "))

    pst.dec(oct)
  char1 := note_table[note*2]   'fetch relevant character from table below
  char2 := note_table[(note*2)+1]
  if pst_on
    pst.char(char1)
    pst.char(char2)
    pst.char(" ")

  freq := F32.FRound(F32.FMul(freq,F32.FFloat(100)))    'update routine takes int freq value scaled up by 100

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
