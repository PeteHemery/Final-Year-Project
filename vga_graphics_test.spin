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
OBJ
  gr    : "vga graphics ASM"
  pst   : "Parallax Serial Terminal"                   ' Serial communication object

VAR
  long  pst_on
  long fft_real[1024]
  long  colors_ptr

PUB MainLoop|i,j,deg,x,y,mask,ii,char
    if ina[31] == 1                            'Check if we're connected via USB
      pst_on := 1
      pst.Start(115200)             'Start the Parallax Serial Terminal cog
      pst.NewLine
    else
      pst_on := 0

    gr.start
    gr.pointcolor(1)

    colors_ptr := gr.get_colors_address

    repeat x from 0 to 14
      repeat y from 0 to 9
        case y
        {
          'colourful foreground
          0..3  : gr.color(x*10+y,$00 + (y << 2) << 8)
          4     : gr.color(x*10+y,$00 + ($1 << 4 + $2 << 2) << 8)
          5     : gr.color(x*10+y,$00 + ($1 << 6 + $3 << 4 + $1 << 2) << 8)
          6     : gr.color(x*10+y,$00 + ($1 << 6 + $2 << 4 + $1 << 2) << 8)
          7     : gr.color(x*10+y,$00 + ($3 << 6 + $2 << 4 + $0 << 2) << 8)
          8     : gr.color(x*10+y,$00 + ($3 << 6 + $1 << 4 + $0 << 2) << 8)
          9     : gr.color(x*10+y,$FF00)
          }
          'colourful background
          0..3  : gr.color(x*10+y,$FF00 + y << 2)
          4     : gr.color(x*10+y,$FF00 + $1 << 4 + $2 << 2)
          5     : gr.color(x*10+y,$FF00 + $1 << 6 + $3 << 4 + $1 << 2)
          6     : gr.color(x*10+y,$FF00 + $1 << 6 + $3 << 4 + $1 << 2)
          7     : gr.color(x*10+y,$FF00 + $3 << 6 + $2 << 4 + $0 << 2)
          8     : gr.color(x*10+y,$FF00 + $3 << 6 + $1 << 4 + $0 << 2)
          9     : gr.color(x*10+y,$FF00)

    x := 319
    repeat


      if x <> 319
        gr.pointcolor(1)
        gr.line(x,0,x,380)
        waitcnt(cnt + 1_000_000)
        gr.pointcolor(0)
        gr.line(x,0,x,380)

        if x < (319 - 32)
          gr.line(x+32,0,x+32,380)
        else
          gr.line(x-(319-32),0,x-(319-32),380)

      else
        x := 00

      'scroll the colours in the background every time the line hits a new tile
      if x // 32 == 0
        wordmove(colors_ptr+2,colors_ptr,tiles - 1)
        word[colors_ptr] := word[colors_ptr][10]

      if x // 10 == 0
        gr.pointcolor(1)
        gr.shape(160,120,90,90,3,gr.deg(x))

        gr.shape(200,75,71,71,4,gr.deg(0))                  'draw a box
        gr.plot(x,100)
        if x <> 0
          gr.shape(x-5,150,4,4,6,gr.deg(0))

      x++

