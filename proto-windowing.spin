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

  peaks    = 1
  num_of_ffts = 2

  magic    = 5148    'time between fft cog launches. seems like a magic number!

VAR

  long  sync,pixels[tiles32]
  word  colors[tiles]

  'buffers for FFT cogs
  word  real_buffer1[fft#NN]
  word  imag_buffer1[fft#NN]
  word  real_buffer2[fft#NN]
  word  imag_buffer2[fft#NN]
'  word  real_buffer3[fft#NN]
'  word  imag_buffer3[fft#NN]
'  word  real_buffer4[fft#NN]
'  word  imag_buffer4[fft#NN]

  long  aud_flag
  long  aud_time

  long  fft1_flag               'flag used to pass messages
  long  fft1_top[peaks]         'tops used to show detected frequency spikes
  long  fft1_time               'measure run time
  long  fft2_flag
  long  fft2_top[peaks]
  long  fft2_time
  long  fft3_flag
  long  fft3_top[peaks]
  long  fft3_time
  long  fft4_flag
  long  fft4_top[peaks]
  long  fft4_time

  'keeping record of times taken for debug
  long audio_flag_val
  long audio_flag_prev
  long audio_time_val
  long audio_time_prev

  long fft1_time_val
  long fft1_time_prev
  long fft1_flag_val
  long fft1_flag_prev

  long fft2_time_val
  long fft2_time_prev
  long fft2_flag_val
  long fft2_flag_prev

  long fft3_time_val
  long fft3_time_prev
  long fft3_flag_val
  long fft3_flag_prev

  long fft4_time_val
  long fft4_time_prev
  long fft4_flag_val
  long fft4_flag_prev

  'pointers for audio sampler cog
  long  audio_flag_ptr
  long  audio_time_ptr
  long  fft_num
  long  array_size

  long  fft1_flag_ptr
  long  buffer1_ptr
  long  fft2_flag_ptr
  long  buffer2_ptr
  long  fft3_flag_ptr
  long  buffer3_ptr
  long  fft4_flag_ptr
  long  buffer4_ptr

OBJ

  vga   : "vga_320x240_bitmap"
  fft   : "fft"
  pst   : "Parallax Serial Terminal"                   ' Serial communication object
  aud   : "sampler"

pub launch | i, vga_cog, pst_cog, audio_cog

   'start vga
  vga_cog := vga.start(16, @colors, @pixels, @sync)

   'init colors to cyan on blue  '$2805
  repeat i from 0 to tiles - 1
    colors[i] := %%3300_0020    'gold on blue 

  'setup list of pointers for sampler object
  long[@aud_flag] := 4+(num_of_ffts * 2)   'number of parameters being passed

  long[@audio_flag_ptr] := @aud_flag
  long[@audio_time_ptr] := @aud_time
  long[@fft_num] := num_of_ffts
  long[@array_size] := fft#NN

  long[@fft1_flag_ptr] := @fft1_flag
  long[@buffer1_ptr] := @real_buffer1
  long[@fft2_flag_ptr] := @fft2_flag
  long[@buffer2_ptr] := @real_buffer2
'  long[@fft3_flag_ptr] := @fft3_flag
'  long[@buffer3_ptr] := @real_buffer3
'  long[@fft4_flag_ptr] := @fft4_flag
'  long[@buffer4_ptr] := @real_buffer4

  pst_cog := pst.Start(115200)             ' Start the Parallax Serial Terminal cog
  pst.Str(String(pst#NL,"Start"))
  pst.Str(String(pst#NL,"vga_cog: "))
  pst.Dec(vga_cog)
  pst.Str(String(pst#NL,"pst_cog: "))
  pst.Dec(pst_cog)

  long[@fft1_flag] := 1         'not ready to go
  long[@fft2_flag] := 1         'not ready to go
  long[@fft3_flag] := 1         'not ready to go
  long[@fft4_flag] := 1         'not ready to go

  fft1_flag_val := fft.start(@fft1_flag,@fft1_time,@real_buffer1,@imag_buffer1,@pixels)
  waitcnt(magic + cnt)
  if num_of_ffts > 1
    fft2_flag_val := fft.start(@fft2_flag,@fft2_time,@real_buffer2,@imag_buffer2,@pixels)
    waitcnt(magic + cnt)
  if num_of_ffts > 2
'    fft3_flag_val := fft.start(@fft3_flag,@fft3_time,@real_buffer3,@imag_buffer3,@pixels)
    waitcnt(magic + cnt)
  if num_of_ffts > 3
'    fft4_flag_val := fft.start(@fft4_flag,@fft4_time,@real_buffer4,@imag_buffer4,@pixels)
    waitcnt(magic + cnt)

  pst.Str(String(pst#NL,"fft1_cog: "))
  pst.Dec(fft1_flag_val)

  fft1_flag_prev := fft1_flag_val := long[@fft1_flag]             'use local variables to store time values
  pst.Str(String(pst#NL,"FFT 1 flag before loop: "))
  pst.Dec(fft1_flag_val)

  if num_of_ffts > 1
    pst.Str(String(pst#NL,"fft2_cog: "))
    pst.Dec(fft2_flag_val)
  if num_of_ffts > 2
    pst.Str(String(pst#NL,"fft3_cog: "))
    pst.Dec(fft3_flag_val)
  if num_of_ffts > 3
    pst.Str(String(pst#NL,"fft4_cog: "))
    pst.Dec(fft4_flag_val)

  pst.Str(String(pst#NL,"audio_flag on launch: "))
  pst.Dec(long[@aud_flag])

  audio_cog := aud.start(@audio_flag_ptr)
  
  pst.Str(String(pst#NL,"audio_cog: "))
  pst.Dec(audio_cog)
  pst.NewLine

  waitcnt(10000+cnt)
                                                                                    
  audio_flag_prev := audio_flag_val := long[@aud_flag]
  pst.Str(String(pst#NL,"Audio Flag value before loop: "))
  pst.Dec(long[@aud_flag])

  pst.Str(String(pst#NL,"Number of FFTs: "))
  pst.Dec(long[@fft_num])

  repeat
   {{ while true
    waitcnt(100000 + cnt)
    pst.Str(String(pst#NL,"Here "))
    }}

    fft1_flag_val := long[@fft1_flag]
    if fft1_flag_val <> fft1_flag_prev
      pst.Str(String(pst#NL,"FFT 1 flag: "))
      pst.Dec(fft1_flag_val)
      fft1_flag_prev := fft1_flag_val

    fft1_time_val := long[@fft1_time]
    if fft1_time_val <> fft1_time_prev
      pst.Str(String(pst#NL,"FFT 1 took: "))
      pst.Dec(fft1_time_val - fft1_time_prev)
      pst.Str(String(pst#NL,"FFT 1 time val: "))
      pst.Dec(fft1_time_val)
      fft1_time_prev := fft1_time_val

    fft2_flag_val := long[@fft2_flag]
    if fft2_flag_val <> fft2_flag_prev
      pst.Str(String(pst#NL,"FFT 2 flag: "))
      pst.Dec(fft2_flag_val)
      fft2_flag_prev := fft2_flag_val

    fft2_time_val := long[@fft2_time]
    if fft2_time_val <> fft2_time_prev
      pst.Str(String(pst#NL,"FFT 2 took: "))
      pst.Dec(fft2_time_val - fft2_time_prev)
      pst.Str(String(pst#NL,"FFT 2 time val: "))
      pst.Dec(fft2_time_val)
      fft2_time_prev := fft2_time_val

    fft3_flag_val := long[@fft3_flag]
    if fft3_flag_val <> fft3_flag_prev
      pst.Str(String(pst#NL,"FFT 3 flag: "))
      pst.Dec(fft3_flag_val)
      fft3_flag_prev := fft3_flag_val

    fft3_time_val := long[@fft3_time]
    if fft3_time_val <> fft3_time_prev
      pst.Str(String(pst#NL,"FFT 3 took: "))
      pst.Dec(fft3_time_val - fft3_time_prev)
      pst.Str(String(pst#NL,"FFT 3 time val: "))
      pst.Dec(fft3_time_val)
      fft3_time_prev := fft3_time_val

    fft4_flag_val := long[@fft4_flag]
    if fft4_flag_val <> fft4_flag_prev
      pst.Str(String(pst#NL,"FFT 4 flag: "))
      pst.Dec(fft4_flag_val)
      fft4_flag_prev := fft4_flag_val

    fft4_time_val := long[@fft4_time]
    if fft4_time_val <> fft4_time_prev
      pst.Str(String(pst#NL,"FFT 4 took: "))
      pst.Dec(fft4_time_val - fft4_time_prev)
      pst.Str(String(pst#NL,"FFT 4 time val: "))
      pst.Dec(fft4_time_val)
      fft4_time_prev := fft4_time_val

    audio_time_val := long[@aud_time]
    if audio_time_val <> audio_time_prev
      pst.Str(String(pst#NL,"Audio Cog took: "))
      pst.Dec(audio_time_val - audio_time_prev)
      pst.Str(String(pst#NL,"Audio time value: "))
      pst.Dec(audio_time_val)
      audio_time_prev := audio_time_val

    audio_flag_val := long[@aud_flag]
    if audio_flag_val <> audio_flag_prev
      pst.Str(String(pst#NL,"Audio Flag value: "))
'      pst.Hex(audio_flag_val,8)
      pst.Dec(audio_flag_val)
      audio_flag_prev := audio_flag_val

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
