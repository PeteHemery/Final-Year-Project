''***************************************
''*  VGA Terminal 40x15 v1.0            *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2006 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************

CON

  _clkmode = xtal1+pll16x
  _xinfreq = 5_000_000

  tiles    = vga#xtiles * vga#ytiles
  tiles32  = tiles * 16

VAR

  long  sync,pixels[tiles32]
  word  colors[tiles]

  word  real_buffer[fft#NN]
  word  imag_buffer[fft#NN]

  long  fft_flag
  long  aud_flag

  long  stack[100]

OBJ

  vga   : "vga_320x240_bitmap"
  fft   : "fft"
  pst   : "Parallax Serial Terminal"                   ' Serial communication object
  aud   : "sampler"

pub launch | fft_cog, audio_cog, i

   'start vga
  vga.start(16, @colors, @pixels, @sync)


   'init colors to cyan on blue
  repeat i from 0 to tiles - 1
    colors[i] := $2804


  pst.Start(115200)                                        ' Start the Parallax Serial Terminal cog
  pst.Str(String(pst#NL,"Start"))

  aud_flag := fft_flag := 0

  audio_cog := aud.start(@aud_flag,fft#NN,2,@real_buffer)

  pst.Str(String(pst#NL,"audio_cog: "))
  pst.Dec(audio_cog)

  repeat
    repeat while long[@aud_flag] == 0
      waitcnt(1000 + cnt)

{{
    pst.Str(String(pst#NL,"Real Buffer:",pst#NL))
      repeat i from 0 to 100'fft#NN-1
        pst.Dec(i)
        pst.Str(String(": "))
        pst.Dec(word[@real_buffer][i])
        pst.Str(String("  | "))
        if i // 8 == 0
          pst.Str(String(pst#NL))
}}
    long[@fft_flag] := 0

    fft_cog := fft.start(@fft_flag,@real_buffer,@imag_buffer,@pixels)

{{    pst.Str(String(pst#NL,"fft_cog: "))
    pst.Dec(fft_cog)
    pst.NewLine
}}
    repeat while long[@fft_flag] == 0
      waitcnt(5_000_000 + cnt)

{{    pst.Str(String(pst#NL,"FFT Flag: "))
    pst.Dec(fft_flag)


    pst.Str(String(pst#NL,"Real Buffer:",pst#NL))
      repeat i from 0 to 100'fft#NN-1
        pst.Dec(i)
        pst.Str(String(": "))
        pst.Dec(word[@real_buffer][i])
        pst.Str(String("  | "))
        if i // 8 == 0
          pst.Str(String(pst#NL))
}}
    long[@aud_flag] := 0        ''start again
PUB populate | i, j
{
  repeat i from 0 to 1023
    word[@real_buffer][i] := word[$E000][i*2]

  repeat i from 0 to 511
    word[@real_buffer][i*2] := word[$E000][i*4]
}
{  repeat i from 0 to 1023
    word[@real_buffer][i] := word[$E000][i*2]
}
{  wordfill(@real_buffer, 1000, fft#NN)
  repeat i from 0 to 127
    word[@real_buffer][i*8] := 500
    word[@real_buffer][i*4] := 2000
}
  wordfill(@real_buffer, 1000, fft#NN)
  repeat i from 0 to 255
    word[@real_buffer][i*4] := 500


'  wordmove(@real_buffer, $E000, fft#NN)
'  wordfill(@real_buffer, 100, fft#NN)

  wordfill(@imag_buffer, 0, fft#NN)

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
