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

  peaks    = 4

  magic = 5148    'time between fft cog launches. seems like a magic number!

VAR

  long  sync,pixels[tiles32]
  word  colors[tiles]

  'hann window multiplier
  word  window'[700]

  'buffers for FFT cogs
  word  real_buffer1[fft#NN]
  word  imag_buffer1[fft#NN]

  'flags used to measure run time and tops used to show detected frequency spikes
  long  fft1_flag
  long  fft1_top[peaks]

  long  aud_flag

  'keeping record of times taken for debug
  long fft1_val
  long fft1_prev
  long audio_val
  long audio_prev

  'pointers for audio sampler cog
  long  audio_flag_ptr
  long  array_size
  long  buffer1_ptr
  long  fft1_flag_ptr

OBJ

  vga   : "vga_320x240_bitmap"
  fft   : "fft"
  pst   : "Parallax Serial Terminal"                   ' Serial communication object
  aud   : "sampler"
'  aud   : "sampler_newest"

pub launch | i, vga_cog, pst_cog, audio_cog

   'start vga
  vga_cog := vga.start(16, @colors, @pixels, @sync)

   'init colors to cyan on blue  '$2805
  repeat i from 0 to tiles - 1
    colors[i] := %%3300_0020    'gold on blue 

  'setup list of pointers for sampler object
  long[@audio_flag_ptr] := @aud_flag
  long[@array_size] := fft#NN
  long[@buffer1_ptr] := @real_buffer1
  long[@fft1_flag_ptr] := @fft1_flag

  pst_cog := pst.Start(115200)             ' Start the Parallax Serial Terminal cog
  pst.Str(String(pst#NL,"Start"))
  pst.Str(String(pst#NL,"vga_cog: "))
  pst.Dec(vga_cog)
  pst.Str(String(pst#NL,"pst_cog: "))
  pst.Dec(pst_cog)

  long[@aud_flag] := 0
  long[@fft1_flag] := 1

  fft1_val := fft.start(@fft1_flag,@real_buffer1,@imag_buffer1,@pixels)
  waitcnt(magic + cnt)

  pst.Str(String(pst#NL,"fft1_cog: "))
  pst.Dec(fft1_val)

  fft1_prev := fft1_val := long[@fft1_flag]             'use local variables to store time values
  pst.Str(String(pst#NL,"FFT 1 flag before loop: "))
  pst.Dec(fft1_flag)


  audio_cog := aud.start(@audio_flag_ptr)
  
  pst.Str(String(pst#NL,"audio_cog: "))
  pst.Dec(audio_cog)
  pst.NewLine

  waitcnt(10000+cnt)
                                                                                    
  audio_prev := audio_val := long[@aud_flag]
  pst.Str(String(pst#NL,"Audio Flag value before loop: "))
  pst.Dec(audio_val)

{{  repeat i from 0 to 20
    pst.Dec(audio_val)
    pst.Char(" ")
'    waitcnt(1_000+cnt)
}}
  repeat
  {{ while true
    waitcnt(1000 + cnt)
    }}
    fft1_val := long[@fft1_flag]
    if fft1_val <> fft1_prev
      pst.Str(String(pst#NL,"FFT 1 took: "))
      pst.Dec(fft1_val - fft1_prev)
      fft1_prev := fft1_val
      pst.Str(String(pst#NL,"FFT 1 value: "))
      pst.Dec(fft1_val)

    audio_val := long[@aud_flag]
    if audio_val <> audio_prev
      pst.Str(String(pst#NL,"Audio Cog took: "))
      pst.Dec(audio_val - audio_prev)
      audio_prev := audio_val
      pst.Str(String(pst#NL,"Audio Flag value: "))
      pst.Dec(audio_val)



'    pst.Str(String(pst#NL,"FFT 1 value: "))
'    pst.Dec(fft1_val)


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
