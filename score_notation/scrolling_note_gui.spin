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

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  '512x384
  tiles = gr#tiles

  scroll_speed = 5_000_000

OBJ
  gr    : "vga graphics ASM"

VAR
  long  plot_flag
  long  colors_ptr

  long  stack[40]

  long  notes, sharps

PUB start

  gr.start
  notes := sharps := plot_flag := 0
  cognew(GUI_Loop,@stack)


PUB GUI_loop | i,j,x,y
    gr.pointcolor(1)

    colors_ptr := gr.get_colors_address

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


    gr.pointcolor(1)
    repeat i from 0 to 4
      gr.line(0,118+(i*14),320,118+(i*14))

    x := 11 'colours change on 32 bit boundary or when x = 10, since notes are drawn up to 10 px behind the scrolling line
    sharps := 0'$FFFF_FFFF
    notes := 0'$FFFF_FFFF
    repeat

      'clear the pixels 10 spaces in front of the drawing line
      gr.pointcolor(0)
      if x < 310
        gr.line(x+10,0,x+10,240)
        gr.pointcolor(1)
        repeat i from 0 to 4
          gr.plot(x+10,118+(i*14))
      else
        gr.line(x-310,0,x-310,240)
        gr.pointcolor(1)
        repeat i from 0 to 4
          gr.plot(x-310,118+(i*14))

      'if the line reaches the edge of the screen reset its position to 10
      'notes and sharps are drawing up to 10 pixels to the left of the line
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


      'notes
      gr.pointcolor(1)
'      if notes <> 0
        repeat i from 0 to 31
          if notes & (1 << i) <> 0
            gr.line(x-5,231-(i*7),x-5,228-(i*7))
            if i // 2 == 0
              gr.line(x-2,230-(i*7),x-8,230-(i*7))

      'sharps
'      if sharps <> 0
        repeat i from 0 to 21
          if sharps & (1 << i) <> 0
            gr.pointcolor(1)
            gr.plot(x-5,226-((i/5)*49)-sharp_offsets[i//5])


      gr.pointcolor(1)
      repeat i from 0 to 4
        gr.plot(x,118+(i*14))

      x++

PUB copy_notes(notes_in, sharps_in)
  notes := notes_in
  sharps := sharps_in


DAT
sharp_offsets byte      0, 14, 21, 28, 42
