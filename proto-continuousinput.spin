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

VAR

  long  sync,pixels[tiles32]
  word  colors[tiles]

  word  real_buffer1[fft#NN]
  word  imag_buffer1[fft#NN]
  word  real_buffer2[fft#NN]
  word  imag_buffer2[fft#NN]
  word  real_buffer3[fft#NN]
  word  imag_buffer3[fft#NN]
  word  real_buffer4[fft#NN]
  word  imag_buffer4[fft#NN]

  long  fft1_flag
  long  fft1_top[peaks]
  long  fft2_flag
  long  fft2_top[peaks]  
  long  fft3_flag
  long  fft3_top[peaks]  
  long  fft4_flag
  long  fft4_top[peaks]
  long  aud_flag

  long  stack[100]
                   

OBJ

  vga   : "vga_320x240_bitmap"
  fft   : "fft"
  pst   : "Parallax Serial Terminal"                   ' Serial communication object
  aud   : "sampler"

pub launch | i, fft1_val, fft1_prev, fft2_val, fft2_prev, fft3_val, fft3_prev, fft4_val, fft4_prev, audio_cog, audio_flag_value, audio_flag_prev

   'start vga
  vga.start(16, @colors, @pixels, @sync)

   'init colors to cyan on blue  '$2805
  repeat i from 0 to tiles - 1
    colors[i] := %%3300_0020    'gold on blue 


  pst.Start(115200)             ' Start the Parallax Serial Terminal cog
  pst.Str(String(pst#NL,"Start"))

  long[@aud_flag] := 0 
  long[@fft1_flag] := 1
  long[@fft2_flag] := 1
  long[@fft3_flag] := 1
  long[@fft4_flag] := 1

  fft1_val := fft.start(@fft1_flag,@real_buffer1,@imag_buffer1,@pixels)
  waitcnt(5148 + cnt)           'seems like a magic number!
  fft2_val := fft.start(@fft2_flag,@real_buffer2,@imag_buffer2,@pixels)
  waitcnt(5148 + cnt)
  fft3_val := fft.start(@fft3_flag,@real_buffer3,@imag_buffer3,@pixels)
  waitcnt(5148 + cnt)
  fft4_val := fft.start(@fft4_flag,@real_buffer4,@imag_buffer4,@pixels)
  waitcnt(5148 + cnt)
                             
  pst.Str(String(pst#NL,"fft1_cog: "))
  pst.Dec(fft1_val)
  pst.Str(String(pst#NL,"fft2_cog: "))
  pst.Dec(fft2_val)
  pst.Str(String(pst#NL,"fft3_cog: "))
  pst.Dec(fft3_val)
  pst.Str(String(pst#NL,"fft4_cog: "))
  pst.Dec(fft4_val)
    
  fft1_prev := fft1_val := long[fft1_flag]                           'use local variables to store time values
  fft2_prev := fft2_val := long[fft2_flag]
  fft3_prev := fft3_val := long[fft3_flag]
  fft4_prev := fft4_val := long[fft4_flag]


  audio_cog := aud.start(@aud_flag,fft#NN,2,@real_buffer1,@real_buffer2,@real_buffer3,@real_buffer4,@fft1_flag,@fft2_flag,@fft3_flag,@fft4_flag)
  
  pst.Str(String(pst#NL,"audio_cog: "))
  pst.Dec(audio_cog)

  waitcnt(10000+cnt)
                                                                                    
  audio_flag_prev := audio_flag_value := long[@aud_flag] 
  pst.Str(String(pst#NL,"Audio Flag value before loop: "))
  pst.Dec(audio_flag_value)
  repeat
    if long[@aud_flag] <> audio_flag_value
      audio_flag_value := long[@aud_flag] 
      pst.Str(String(pst#NL,"Audio Cog took: "))
      pst.Dec(audio_flag_value - audio_flag_prev)
'      pst.Str(String(pst#NL,"Prev Audio Flag value: "))
'      pst.Dec(audio_flag_prev)
      pst.Str(String(pst#NL,"Audio Flag value: "))
      pst.Dec(audio_flag_value)

      audio_flag_prev := audio_flag_value

    if long[@fft1_flag] <> fft1_val
      fft1_val := long[@fft1_flag] 
      pst.Str(String(pst#NL,"FFT 1 took: "))
      pst.Dec(fft1_val - fft1_prev)
      fft1_prev := fft1_val
      pst.Str(String(pst#NL,"FFT 1 value: "))
      pst.Dec(fft1_val)           
      pst.Str(String(pst#NL,"FFT 4 & 1 difference: "))
      pst.Dec(fft1_val - fft4_val)
           
    if long[@fft2_flag] <> fft2_val
      fft2_val := long[@fft2_flag] 
      pst.Str(String(pst#NL,"FFT 2 took: "))
      pst.Dec(fft2_val - fft2_prev)
      fft2_prev := fft2_val
      pst.Str(String(pst#NL,"FFT 2 value: "))
      pst.Dec(fft2_val)
      pst.Str(String(pst#NL,"FFT 1 & 2 difference: "))
      pst.Dec(fft2_val - fft1_val)
           
    if long[@fft3_flag] <> fft3_val
      fft3_val := long[@fft3_flag] 
      pst.Str(String(pst#NL,"FFT 3 took: "))
      pst.Dec(fft3_val - fft3_prev)
      fft3_prev := fft3_val
      pst.Str(String(pst#NL,"FFT 3 value: "))
      pst.Dec(fft3_val)
      pst.Str(String(pst#NL,"FFT 2 & 3 difference: "))
      pst.Dec(fft3_val - fft2_val)
           
    if long[@fft4_flag] <> fft4_val
      fft4_val := long[@fft4_flag] 
      pst.Str(String(pst#NL,"FFT 4 took: "))
      pst.Dec(fft4_val - fft4_prev)
      fft4_prev := fft4_val
      pst.Str(String(pst#NL,"FFT 4 value: "))
      pst.Dec(fft4_val)
      pst.Str(String(pst#NL,"FFT 3 & 4 difference: "))
      pst.Dec(fft4_val - fft3_val)




PUB populate | i, j
  wordfill(@real_buffer1, 0, fft#NN)
  wordfill(@imag_buffer1, 0, fft#NN)
  wordfill(@real_buffer2, 0, fft#NN)
  wordfill(@imag_buffer2, 0, fft#NN)
  wordfill(@real_buffer3, 0, fft#NN)
  wordfill(@imag_buffer3, 0, fft#NN)
  wordfill(@real_buffer4, 0, fft#NN)
  wordfill(@imag_buffer4, 0, fft#NN)

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
