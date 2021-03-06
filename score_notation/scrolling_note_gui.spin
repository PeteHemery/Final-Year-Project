'----------------------------------------------------------------------------------------------------------------------
'
' Scrolling Notation GUI
'
' Pete Hemery
'                  
' 2012-06-18    v1.0  First Release.
'----------------------------------------------------------------------------------------------------------------------
{
List of VGA graphics commands


Sine(Ang)                                 ' Input = 13-bit angle ranging from 0 to 8191
                                          ' Output = 16-bit Sine value ranging from $FFFF0001 ('-1') to $0000FFFF ('1')

Cosine(Ang)                               ' Input = 13-bit angle ranging from 0 to 8191
                                          ' Output = 16-bit Cosine value ranging from $FFFF0001 ('-1') to $0000FFFF ('1')

ArcSine(Ang)                              ' Input = signed 16-bit value ranging from $FFFF0001 ('-1') to $0000FFFF ('1')
                                          ' Output = signed 11-bit angle ranging from -2047 (-pi/2) to 2047 (pi/2)

ArcCosine(Ang)                            ' Input = signed 16-bit value ranging from $FFFF0001 ('-1') to $0000FFFF ('1')
                                          ' Output = signed 11-bit angle ranging from -2047 (-pi/2) to 2047 (pi/2)

plot(x,y)                                 ' Sets pixel value at location x,y
point(x,y)                                ' Reads pixel value at location x,y
character(offX,offY,chr)                  ' Place a text character from the ROM table at offset location offsetX,offsetY
line (px_,py_,dx_,dy_)                    ' Draws line from px,py to dx,dy
box(x1_,y1_,x2_,y2_)                      ' Draws a box from opposite corners x1,y1 and x2,y2
boxfill(x1_,y1_,x2_,y2_)                  ' Draws a filled box from opposite corners x1,y1 and x2,y2
pointcolor(pc)                            ' Sets pixel color "1" or "0"
clear                                     ' Clear entire screen contents
color(tile,cval)                          ' Set Color tiles on VGA screen
Text(offX,offY,Address)                   ' Place a text string from the ROM table at offset location offsetX,offsetY
deg(angle)                                ' translate deg(0-360) ---> to ---> 13-bit angle(0-8192)
bit13(angle)                              ' translate 13-bit angle(0-8192) ---> to ---> deg(0-360)
shape(x,y,sizeX,sizeY,sides,rotation)     ' Draws a shape with center located at x,y
SimpleNum(x,y,DecimalNumber,DecimalPoint) ' Basic Decimal number printing at location x,y
}

'#define COLOURFUL              'Uncomment the section below for scrolling background colours

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  '512x384
  tiles = gr#tiles

  scroll_speed = 4_000_000
                  
  kalimba_range = 1

OBJ
  gr    : "vga graphics ASM"

VAR

  long  colors_ptr

  long  stack[21]
  long  notes, sharps


PUB start

  gr.start
  notes := sharps := 0
  cognew(GUI_Loop,@stack)


PUB GUI_loop | i,x
    gr.pointcolor(1)

    colors_ptr := gr.get_colors_address

    repeat x from 0 to 14
      repeat i from 0 to 9
      
'#ifdef COLOURFUL

        case i
          'colourful foreground
          0     : gr.color(x*10+i,$FF00)
          1..3  : gr.color(x*10+i,$00 + (i << 2) << 8)
          4     : gr.color(x*10+i,$00 + ($1 << 4 + $2 << 2) << 8)
          5     : gr.color(x*10+i,$00 + ($1 << 6 + $2 << 4 + $1 << 2) << 8)
          6     : gr.color(x*10+i,$00 + ($1 << 6 + $3 << 4 + $1 << 2) << 8)
          7     : gr.color(x*10+i,$00 + ($3 << 6 + $2 << 4 + $0 << 2) << 8)
          8     : gr.color(x*10+i,$00 + ($3 << 6 + $1 << 4 + $0 << 2) << 8)
          9     : gr.color(x*10+i,$00 + ($3 << 6 + $0 << 4 + $0 << 2) << 8)

'#else
'        gr.color(x*10+i,$FF00) 'white on black
        gr.color(x*10+i,$00FF) 'black on white
'#endif
  
    gr.pointcolor(1)

    if kalimba_range            'draw the stave
      repeat i from 0 to 4
        gr.line(0,70+(i*20),320,70+(i*20))
    else
      repeat i from 0 to 4
        gr.line(0,118+(i*14),320,118+(i*14))

    x := 11 'colours change on 32 bit boundary or when x = 10, since notes are drawn up to 10 px behind the scrolling line
    sharps := 0 '$FFFF_FFFF     'uncomment these for debugging purposes, seeing all the lines at once.
    notes := 0  '$FFFF_FFFF
    repeat                      'Main loop

      'clear the pixels 32 spaces in front of the drawing line
      gr.pointcolor(0)
      if x < 288                '(320 - 32)
        gr.line(x+32,0,x+32,240)
        gr.pointcolor(1)
        if kalimba_range        'draw the intermediate stave  (between clearing line and drawing line)
          repeat i from 0 to 4  
            gr.plot(x+32,70+(i*20))
        else
          repeat i from 0 to 4
            gr.plot(x+32,118+(i*14))
                                'if the x position of the line is greater than 288, 
      else                      'begin to clear the beginning too, otherwise artifacts are left when x is reset to 10
        gr.line(x-288,0,x-288,240)
        gr.line(x-256,0,x-256,240)
        gr.pointcolor(1)             

        if kalimba_range        'draw the intermediate stave  (between clearing line and drawing line)
          repeat i from 0 to 4        
            gr.plot(x-288,70+(i*20))
            gr.plot(x-256,70+(i*20))
        else
          repeat i from 0 to 4
            gr.plot(x-288,118+(i*14))
            gr.plot(x-256,118+(i*14))


      'if the line reaches the edge of the screen, reset its position to 10
      'notes and sharps are drawn up to 10 pixels to the left of the line
      if x > 319
        x := 10

      'draw the scrolling line
      gr.pointcolor(1)
      gr.line(x,0,x,240)
      waitcnt(cnt + scroll_speed)     
      gr.pointcolor(0)
      gr.line(x,0,x, 240)


      'scroll the colours in the background every time the line hits a new tile
      if x // 32 == 0 OR x == 10
        wordmove(colors_ptr+2,colors_ptr,tiles - 1)
        word[colors_ptr] := word[colors_ptr][10]

               
      gr.pointcolor(1)
            
      'notes  
      if kalimba_range  
        repeat i from 5 to 21
          if notes & (1 << i) <> 0
            gr.line(x-5,232-(i*10),x-5,228-(i*10))
            if i // 2 == 0
              gr.line(x-2,230-(i*10),x-8,230-(i*10))
      else
        repeat i from 0 to 30
          if notes & (1 << i) <> 0          
            gr.line(x-5,231-(i*7),x-5,228-(i*7))
            if i // 2 == 0
              gr.line(x-2,230-(i*7),x-8,230-(i*7))
            
 
      'sharps      
      if kalimba_range     
        repeat i from 4 to 14
          if sharps & (1 << i) <> 0
            gr.pointcolor(1)
            gr.plot(x-5,225-((i/5)*70)-kalimba_sharp_offsets[i//5])
      else
        repeat i from 0 to 21
          if sharps & (1 << i) <> 0                                              
            gr.pointcolor(1)
            gr.plot(x-5,226-((i/5)*49)-sharp_offsets[i//5]) 
       
      gr.pointcolor(1)          'draw the stave after the line
      if kalimba_range
        repeat i from 0 to 4
          gr.plot(x,70+(i*20))
      else
        repeat i from 0 to 4
          gr.plot(x,118+(i*14))
       
      x++

PUB copy_notes(notes_in, sharps_in)
  notes := notes_in
  sharps := sharps_in


DAT                                        
kalimba_sharp_offsets   byte      0, 20, 30, 40, 60
sharp_offsets           byte      0, 14, 21, 28, 42


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
