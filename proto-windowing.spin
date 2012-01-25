''*******************************************************
''*  Continuous Sampled FFT Input Prototype v1.0        *
''*  Author: Pete Hemery                                *
''*  01/12/2011                                         *
''*  See end of file for terms of use.                  *
''*******************************************************

CON

  _clkmode = xtal1+pll16x
  _xinfreq = 5_000_000

  tiles    = vga#xtiles * vga#ytiles
  tiles32  = tiles * 16

'  peaks    = 1
  num_of_ffts = 2               'Only enough cogs for 3 FFTs and filtering
                                'Disable filtering in sampler for a max of 4 FFTs
  TIMEOUT = 60000

VAR

  long  sync,pixels[tiles32]
  word  colors[tiles]

  'keeping record of times taken for debug
  long  aud_flag, aud_time
  long  audio_flag_val, audio_flag_prev
  long  audio_time_val, audio_time_prev

  long  fft_flag[num_of_ffts], fft_time[num_of_ffts]
  long  fft_flag_val[num_of_ffts], fft_flag_prev[num_of_ffts]
  long  fft_time_val[num_of_ffts], fft_time_prev[num_of_ffts]
'  long  fft_top[num_of_ffts*peaks]                      'tops used to show detected frequency spikes

  'pointers for audio sampler cog
  long  audio_flag_ptr
  long  audio_time_ptr
  long  array_size

  long  fft_flag_ptr[num_of_ffts]
  long  buffer_ptr[num_of_ffts]

  'buffers for FFT cogs
  word  real_buffer[fft#NN*num_of_ffts]
  word  imag_buffer[fft#NN*num_of_ffts]


OBJ

  vga   : "vga_320x240_bitmap"
  fft   : "fft"
  pst   : "Parallax Serial Terminal"                   ' Serial communication object
  aud   : "sampler"

pub launch | i, j, vga_cog, pst_cog, audio_cog, countdown, pst_on

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
  waitcnt(clkfreq + cnt)                   'Pause 1 Second while we boot up
  repeat
    if countdown =< 0
      countdown := TIMEOUT
      longfill(@pixels, $0, tiles32)
    countdown--

    audio_flag_val := long[@aud_flag]
    if audio_flag_val <> audio_flag_prev AND pst_on
      audio_time_val := long[@aud_time]
      pst.Str(String(pst#NL,"Audio Flag value: "))
      pst.Dec(audio_flag_val)
      audio_flag_prev := audio_flag_val
      pst.Str(String(pst#NL,"Audio Cog took: "))
      pst.Dec((||(audio_time_val - audio_time_prev))/(clkfreq/1000))
      pst.Str(String("ms"))
'        pst.Str(String(pst#NL,"Audio time value: "))
'        pst.Dec(audio_time_val)
      audio_time_prev := audio_time_val

    repeat i from 0 to num_of_ffts - 1
      fft_flag_val[i] := long[@fft_flag][i]
      fft_time_val[i] := long[@fft_time][i]
      if fft_flag_val[i] <> fft_flag_prev[i]
        if fft_flag_val[i] <> 0
          pst.Str(String(pst#NL,"FFT "))
          pst.Dec(i+1)
          pst.Str(String(" took: "))
          pst.Dec((||(fft_time_val[i] - fft_time_prev[i]))/(clkfreq/1000))
          pst.Str(String("ms"))

          pst.Str(String("             flag: "))
          pst.Dec(fft_flag_val[i])
        fft_flag_prev[i] := fft_flag_val[i]
        fft_time_prev[i] := fft_time_val[i]


PUB setup_pointers | i
  'setup list of pointers for sampler object
  long[@aud_flag] := 3+(num_of_ffts * 2)   'number of parameters being passed

  long[@audio_flag_ptr] := @aud_flag
  long[@audio_time_ptr] := @aud_time
  long[@array_size] := fft#NN

  repeat i from 0 to num_of_ffts - 1
    long[@fft_flag][i] := 1         'not ready to go
    long[@fft_flag_ptr][i] := @fft_flag[i]
    long[@buffer_ptr][i] := @real_buffer[i*fft#NN]

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
s│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
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
