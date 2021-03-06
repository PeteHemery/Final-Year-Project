{{
*****************************************
* Frequency Counter v0.0                *
* Author: Pete Hemery                   *
* Copyright (c) 2012                    *
* See end of file for terms of use.     *
*****************************************
}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode-xtal1)>>6)*_xinfreq
  MS_001 = CLK_FREQ / 1_000

  tiles    = vga#xtiles * vga#ytiles
  tiles32  = tiles * 16
  hp = vga#hp      'horizontal pixels
  vp = vga#vp      'vertical pixels
  halfvp        = vp / 2

  num_of_ffts = 1

VAR

  long  sync, pixels[tiles32]
  word  colors[tiles]', ypos[512]

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
  pst : "Parallax Serial Terminal"
'  vga : "vga_512x384_bitmap"
  vga : "vga_320x240_bitmap"
  aud : "sampler"
  fft :"fft"
'  fir : "fir_filter"

PUB main | t0, t1, h, i, j, k, x, y, acog

  pst.start(115200)
  pause(1)
  pst.Clear

  'setup list of pointers for sampler object
  long[@aud_flag] := 3+(num_of_ffts * 2)   'number of parameters being passed

  long[@audio_flag_ptr] := @aud_flag
  long[@audio_time_ptr] := @aud_time
  long[@array_size] := fft#NN

  repeat i from 0 to num_of_ffts - 1
    long[@fft_flag][i] := 1         'not ready to go
    long[@fft_flag_ptr][i] := @fft_flag[i]
    long[@buffer_ptr][i] := @real_buffer[i*fft#NN]

  repeat i from 0 to num_of_ffts - 1
    j := i*fft#NN
    fft_flag_val[i] := fft.start(@fft_flag[i],@fft_time[i],@real_buffer[j],@imag_buffer[j],@pixels)

  acog := aud.start(@audio_flag_ptr)
  pst.Str(String(pst#NL,"audio cog: "))
  pst.Dec(acog)
  pst.NewLine

   'start vga
  vga.start(16, @colors, @pixels, @sync)

   'init colors to cyan on blue  '$2805
  repeat i from 0 to tiles - 1
    colors[i] := %%3300_0020    'gold on blue

  'fill top line so that it gets erased by COG
  longfill(@pixels, $FFFFFFFF, vga#xtiles)

  audio_flag_prev := audio_flag_val := long[@aud_flag]
  pst.Str(String(pst#NL,"Audio Flag value before loop: "))
  pst.Dec(long[@aud_flag])

  pause(1)

  repeat
    t0 := cnt
    ' code to test goes here

    'draw some lines
'    repeat x from 0 to tiles
'      repeat y from halfvp to vp-1
        'plot(x, x/y)
        pixels[y << 4 + x >> 5] ^= |< x

    pst.Str(String("sample data:"))
    repeat x from 0 to 1023
      pst.Dec(x)
      pst.Char(":")
      pst.Dec(word[@real_buffer][x])
      pst.Char(",")
      pst.Char(pst#TB)
      if (x // 10) == 0
        pst.NewLine
    pst.Dec(long[@aud_flag])
    pst.NewLine
    ' code to test goes here
    t1 := cnt
    't1 := ||(t1 - t0)
    t1 := (||(t1 - t0) - 368) #> 0

'    pst.Clear
    pst.Dec(t1)
    pst.Str(String(" ticks",pst#NL))
    pst.Dec(t1/(clkfreq/1000))
    pst.Str(String("ms",pst#NL))
    pause(1_000)

  'draw some lines
  repeat y from 1 to 8
    repeat x from 0 to 511
      plot(x, x/y)

  'randomize the colors and pixels
  repeat
    colors[||?h // tiles] := ?i
    repeat 100
      pixels[||?j // tiles32] := k?


PUB pause(ms) | t
  't := cnt
  if ms < 2
    t := cnt  - 1408 - 368
  elseif ms < 256
    t := cnt  - 1408 - 368 - 725
  else
    t := cnt  - 1408 - 368 - 725 - 32

  repeat ms
    waitcnt(t += MS_001)


PRI plot(x,y) | i

  if x => 0 and x < 512 and y => 0 and y < 384
    pixels[y << 4 + x >> 5] |= |< x

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