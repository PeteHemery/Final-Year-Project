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
          0..2  : gr.color(x*10+y,$FF00 + y << 2)
          3..4  : gr.color(x*10+y,$FF00 + (y - 3) << 4 + $2 << 2)
          5     : gr.color(x*10+y,$FF00 + $1 << 6 + $3 << 4 + $1 << 2)
          6     : gr.color(x*10+y,$FF00 + $1 << 6 + $2 << 4 + $1 << 2)
          7     : gr.color(x*10+y,$FF00 + $3 << 6 + 2 << 4 + $0 << 2)
          8     : gr.color(x*10+y,$FF00 + $3 << 6 + 1 << 4 + $0 << 2)
          9     : gr.color(x*10+y,$FF00)
    {
    repeat i from 0 to tiles - 1                        'init tile colors to white on black
      gr.color(i,%%3100_0010)    'gold on blue
      'gr.color(i,$FF00)
      gr.color(i,$FF<<8+((i<<2) & $FF))                              'init tile colors "Nice view"
'      gr.color(i,($FF00 + (i >> 4 & $3) << 6 + (i >> 2 & $3) << 4 + (i & $3) << 2)) 'every colour
      }{
      pst.dec(i)
      pst.char(":")
      pst.hex($FF00 + ((i >> 4 & $3) << 6 + (i >> 2 & $3) << 4 + (i & $3) << 2),4)
      pst.newline}
'    gr.text(0,0,string("Parallax VGA text and graphics"))
'    gr.SimpleNum(464,32,123,3)

    gr.pointcolor(1)
    gr.line(1,0,0,240)

    gr.box(30,50,80,100)                                'draw a box
    'or
    gr.shape(200,75,71,71,4,gr.deg(0))                  'draw a box


    gr.boxfill(40,60,70,90)                             'draw a filled box


'    repeat i from 3 to 15
'      gr.shape(256,192,300,300,i,gr.deg(90))            'i = 3  triangle
                                                        'i = 4  square
                                                        'i = 5  pentagon
                                                        'i = 6  hexagon
                                                        'i = 7  heptagon
                                                        'i = 8  octagon
                                                        'i = 9  nonagon
                                                        'i = 10 decagon
                                                        'i = 11 hendecagon
                                                        'i = 12 didecqgon
                                                        'i = 13 tridecagon
                                                        'i = 14 tetradecagon
                                                        'i = 15 pentadecagon
    i := 319
    repeat

      if i <> 319
        gr.pointcolor(1)
        gr.line(i,0,i,380)
        waitcnt(cnt + 1_000_000)
        gr.pointcolor(0)
        gr.line(i,0,i,380)
      else
        i := 00

      if i // 32 == 0
        wordmove(colors_ptr+2,colors_ptr,tiles - 1)
        word[colors_ptr] := word[colors_ptr][10]

{
        repeat y from 0 to 14
          repeat x from 0 to 9
            case x
              0..3  : gr.color(y*10+x+((i/32) & 15),$FF00 + x << 2)
              4..5  : gr.color(y*10+x+((i/32) & 15),$FF00 + (x - 3) << 4 + $2 << 2)
              6     : gr.color(y*10+x+((i/32) & 15),$FF00 + $1 << 6 + $3 << 4 + $1 << 2)
              7     : gr.color(y*10+x+((i/32) & 15),$FF00 + $1 << 6 + $2 << 4 + $1 << 2)
              8     : gr.color(y*10+x+((i/32) & 15),$FF00 + $3 << 6 + 2 << 4 + $0 << 2)
              9     : gr.color(y*10+x+((i/32) & 15),$FF00 + $3 << 6 + 1 << 4 + $0 << 2)
}
      if i // 10 == 0
        gr.pointcolor(1)
        gr.shape(160,120,90,90,3,gr.deg(i))

        gr.shape(200,75,71,71,4,gr.deg(0))                  'draw a box
        gr.plot(i,100)
      i++
{      repeat i from 0 to 359
        gr.pointcolor(1)
        gr.shape(256,192,145,145,3,gr.deg(i))
        gr.shape(256,192,70,70,4,gr.deg(359-i*2))
        gr.shape(256,192,30,30,5,gr.deg(i*3))
        repeat 4000
        gr.pointcolor(0)
        gr.shape(256,192,145,145,3,gr.deg(i))
        gr.shape(256,192,70,70,4,gr.deg(359-i*2))
        gr.shape(256,192,30,30,5,gr.deg(i*3))
}
