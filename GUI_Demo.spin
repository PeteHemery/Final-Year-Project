''***************************************
''*  VGA Text Demo v1.0                 *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2006 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************
''Modified by Pete Hemery
'' 15/01/2012
''Provides the front end functionality for the Frequency Counter Tuner Demo

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  basepin  = 16

  CLEAR_SCR     = $00
  HOME          = $01
  BACKSPACE     = $08
  TAB           = $09
  X_SELECT      = $0A
  Y_SELECT      = $0B
  COLOUR_SELECT = $0C
  CRLF          = $0D

  white      = 0
  dark_red   = 1
  red        = 2
  orange     = 3
  yellow     = 4
  green      = 5
  light_blue = 6
  dark_blue  = 7

OBJ

  vga_text : "vga_text"
  gr    : "vga graphics ASM"

VAR
  long arrow_pos

PUB start | i, cents, x, y

{
  gr.start
  gr.pointcolor(1)
  repeat x from 0 to 14
    repeat y from 0 to 9
      case y

        'colourful foreground
        0     : gr.color(x*10+y,$FF00)
        1..3  : gr.color(x*10+y,$00 + (y << 2) << 8)
        4     : gr.color(x*10+y,$00 + ($1 << 4 + $2 << 2) << 8)
        5     : gr.color(x*10+y,$00 + ($1 << 6 + $2 << 4 + $1 << 2) << 8)
        6     : gr.color(x*10+y,$00 + ($1 << 6 + $3 << 4 + $1 << 2) << 8)
        7     : gr.color(x*10+y,$00 + ($3 << 6 + $2 << 4 + $0 << 2) << 8)
        8     : gr.color(x*10+y,$00 + ($3 << 6 + $1 << 4 + $0 << 2) << 8)
        9     : gr.color(x*10+y,$00 + ($3 << 6 + $0 << 4 + $0 << 2) << 8)

  repeat i from 0 to 4
    gr.line(0,70+(i*20),320,70+(i*20))
}
  vga_text.start(basepin)

  arrow_pos := 5

  show_headings
  show_scale

'Demonstration of changing values on the display
{  repeat
    repeat cents from -50 to 50
      update(5,"A"," ",cents,44000)
      waitcnt(clkfreq / 10 + cnt)
}
PUB update(oct,note1,note2,cent,freq)

'  gr.pointcolor(1)
'  gr.line(arrow_pos,0,arrow_pos,240)
{  arrow_pos++
  if arrow_pos > 300
    arrow_pos := 5
}
  show_cents(cent)
  show_percent(cent)
  show_octave(oct)
  show_note(note1,note2)

  show_frequency(freq)

  show_headings
  show_scale

PUB reset_display

  show_headings
  show_scale

  vga_text.out(X_SELECT)
  vga_text.out(0)
  vga_text.out(Y_SELECT)
  vga_text.out(6)
  vga_text.str(string("                               "))

  vga_text.out(X_SELECT)
  vga_text.out(0)
  vga_text.out(Y_SELECT)
  vga_text.out(12)
  vga_text.str(string("                               "))



PRI show_headings

  'gr.text(100,100,string("hi"))

  vga_text.out(COLOUR_SELECT)
  vga_text.out(white)
  vga_text.out(Y_SELECT)
  vga_text.out(1)
  vga_text.out(X_SELECT)
  vga_text.out(2)

  vga_text.str(string("Music Tuner"))

  vga_text.out(Y_SELECT)
  vga_text.out(2)
  vga_text.out(X_SELECT)
  vga_text.out(14)
  vga_text.str(string("Frequency Counter"))

  vga_text.out(Y_SELECT)
  vga_text.out(5)

  vga_text.out(X_SELECT)
  vga_text.out(0)
  vga_text.str(string("Octave"))

  vga_text.out(X_SELECT)
  vga_text.out(8)
  vga_text.str(string("Note"))

  vga_text.out(X_SELECT)
  vga_text.out(14)
  vga_text.str(string("Percent"))


  vga_text.out(X_SELECT)
  vga_text.out(22)
  vga_text.str(string("Frequency"))


PRI show_octave(octave)

  vga_text.out(Y_SELECT)
  vga_text.out(6)
  vga_text.out(X_SELECT)
  vga_text.out(4)
  vga_text.dec(octave)
  vga_text.out(" ")

PRI show_note(note1,note2)

  vga_text.out(Y_SELECT)
  vga_text.out(6)
  vga_text.out(X_SELECT)
  vga_text.out(10)

  vga_text.out(note1)
  vga_text.out(note2)

{  if note == 0
    vga_text.str(string("C "))
  elseif note == 1
    vga_text.str(string("C#"))
  elseif note == 2
    vga_text.str(string("D "))
  elseif note == 3
    vga_text.str(string("Eb"))
  elseif note == 4
    vga_text.str(string("E "))
  elseif note == 5
    vga_text.str(string("F "))
  elseif note == 6
    vga_text.str(string("F#"))
  elseif note == 7
    vga_text.str(string("G "))
  elseif note == 8
    vga_text.str(string("G#"))
  elseif note == 9
    vga_text.str(string("A "))
  elseif note == 10
    vga_text.str(string("Bb"))
  elseif note == 11
    vga_text.str(string("B "))
}
PRI show_percent(percent)

  vga_text.out(Y_SELECT)
  vga_text.out(6)
  vga_text.out(X_SELECT)
  vga_text.out(16)
  vga_text.dec(percent)
  vga_text.out(" ")
  vga_text.out(" ")

PRI show_frequency(frequency)

  vga_text.out(Y_SELECT)
  vga_text.out(6)
  vga_text.out(X_SELECT)
  vga_text.out(21)
  if (frequency/100) > 0
    vga_text.dec(frequency/100)
    vga_text.out(".")
  if (frequency//100) < 10 AND (frequency//100) > 0
    vga_text.out("0")
  if (frequency//100) > 0
    vga_text.dec(frequency//100)
    vga_text.out(" ")
  else
    vga_text.str(string("   "))

  vga_text.out(X_SELECT)
  vga_text.out(29)

  vga_text.str(string("Hz"))

PRI show_scale

  vga_text.out(Y_SELECT)
  vga_text.out(9)

  vga_text.out(X_SELECT)
  vga_text.out(4)
  vga_text.str(string("-50"))
  vga_text.out(X_SELECT)
  vga_text.out(15)
  vga_text.str(string("0"))
  vga_text.out(X_SELECT)
  vga_text.out(24)
  vga_text.str(string("50"))

  vga_text.out(CRLF)
  vga_text.out(X_SELECT)
  vga_text.out(5)            
  vga_text.str(string("┌"))
  repeat 19
    vga_text.str(string("┬"))
  vga_text.str(string("┐"))
  vga_text.out(CRLF)
  vga_text.out(X_SELECT)
  vga_text.out(5)
  repeat 11
    vga_text.str(string("│ "))

PRI refresh_scale(cent)

  vga_text.out(COLOUR_SELECT)
  vga_text.out(white)

  vga_text.out(Y_SELECT)
  vga_text.out(7)
  vga_text.out(X_SELECT)
  vga_text.out(5)
  vga_text.str(string("┌"))
  repeat 19
    vga_text.str(string("┬"))
  vga_text.str(string("┐"))

  vga_text.out(X_SELECT)
  vga_text.out(arrow_pos)
  vga_text.out(" ")

PRI show_cents(cents) | variable_colour

  vga_text.out(Y_SELECT)
  vga_text.out(12)

  if cents =< -35
    variable_colour := 1
  elseif cents =< -20
    variable_colour := 2
  elseif cents =< -5
    variable_colour := 3
  elseif cents =< 10
    variable_colour := 4
  elseif cents =< 25
    variable_colour := 5
  elseif cents =< 40
    variable_colour := 6
  elseif cents =< 50
    variable_colour := 7
  vga_text.out(COLOUR_SELECT)
  vga_text.out(variable_colour)

  vga_text.out(X_SELECT)
  vga_text.out(arrow_pos)
  vga_text.out(" ")

  arrow_pos := 5 + ((cents + 50) / 5)
  vga_text.out(X_SELECT)
  vga_text.out(arrow_pos)
  vga_text.out("")

                  
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
