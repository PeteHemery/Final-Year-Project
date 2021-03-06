''***************************************
''*  Graphics Demo                      *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2005 Parallax, Inc.  *               
''*  See end of file for terms of use.  *               
''***************************************


CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  _stack = ($3000 + $3000 + 100) >> 2   'accomodate display memory and stack

  x_tiles = 16
  y_tiles = 12

  paramcount = 14       
  bitmap_base = $2000
  display_base = $5000

  lines = 4
  thickness = 1
  

VAR

  long  mousex, mousey

  long  tv_status     '0/1/2 = off/visible/invisible           read-only
  long  tv_enable     '0/? = off/on                            write-only
  long  tv_pins       '%ppmmm = pins                           write-only
  long  tv_mode       '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long  tv_screen     'pointer to screen (words)               write-only
  long  tv_colors     'pointer to colors (longs)               write-only               
  long  tv_hc         'horizontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horizontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horizontal offset                       write-only
  long  tv_vo         'vertical offset                         write-only
  long  tv_broadcast  'broadcast frequency (Hz)                write-only
  long  tv_auralcog   'aural fm cog                            write-only

  word  screen[x_tiles * y_tiles]
  long  colors[64]

  byte  x[lines]
  byte  y[lines]
  byte  xs[lines]
  byte  ys[lines]
  

OBJ

  tv    : "tv"
  gr    : "graphics"
'  mouse : "mouse"
  pst : "Parallax Serial Terminal"


PUB start | i, j, k, kk, dx, dy, pp, pq, rr, numx, numchr, c

  pst.start(115200)
  pst.Clear

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors
  repeat i from 0 to 63
    colors[i] := $10001010 * (i) & $F + $0B060C02
    pst.dec(i)
    pst.str(string(": "))
    pst.hex(colors[i],8)
    pst.newline



''  _________
''  tv_colors
''
''    pointer to longs which define colorsets
''      number of longs must be 1..64
''      each long has four 8-bit fields which define colors for 2-bit (four color) pixels
''      first long's bottom color is also used as the screen background color
''      8-bit color fields are as follows:
''        bits 7..4: chroma data (0..15 = blue..green..red..)*
''        bit 3: controls chroma modulation (0=off, 1=on)
''        bits 2..0: 3-bit luminance level:
''          values 0..1: reserved for sync - don't use
''          values 2..7: valid luminance range, modulation adds/subtracts 1 (beware of 7)
''          value 0 may be modulated to produce a saturated color toggling between levels 1 and 7
''
''      * because of TV's limitations, it doesn't look good when chroma changes abruptly -
''        rather, use luminance - change chroma only against a black or white background for
''        best appearance
''  _____


  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := display_base >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)



  'init bouncing lines
  i := 1001
  j := 123123
  k := 8776434
  repeat i from 0 to lines - 1
    x[i] := ?j // 220'192'64
    y[i] := k? // 84'144'48
    repeat until xs[i] := k? ~> 29
    repeat until ys[i] := ?j ~> 29

  'start and setup graphics
  gr.start
  gr.setup(16, 12, 128, 96, bitmap_base)

  'start mouse
'  mouse.start(24, 25)

  repeat

    'clear bitmap
    gr.clear

''   c              - color code in bits[1..0]
''   w              - 0..15 for round pixels, 16..31 for square pixels
    'draw spinning triangles
    gr.colorwidth(1,8)
    repeat i from 1 to 4
'' Draw a vector sprite
''
''   x,y            - center of vector sprite
''   vecscale       - scale of vector sprite ($100 = 1x)
''   vecangle       - rotation angle of vector sprite in bits[12..0]
''   vecdef_ptr     - address of vector sprite definition
'      gr.vec(0, 0, (k & $7F) << 3 + i << 5, k << 6 + i << 8, @vecdef)'original
      gr.vec(0, 0, $280 + $20 << i, k << 2 + i << 8, @pianodef)



      gr.pixarc(-80,-40,30,30,i<<10+k<<6,0,@pixdef2)
    'draw expanding mouse crosshairs
    gr.colorwidth(2,k>>2)
'    mousex := mousex + mouse.delta_x #> -128 <# 127
 '   mousey := mousey + mouse.delta_y #> -96 <# 95

'' Draw a pixel sprite
''
''   x,y            - center of vector sprite
''   pixrot         - 0: 0°, 1: 90°, 2: 180°, 3: 270°, +4: mirror
''   pixdef_ptr     - address of pixel sprite definition
''
    gr.pix(mousex, mousey, k>>1 & $3, @pixdef)

    'if left mouse button pressed, throw snowballs
{    if mouse.button(0)
      gr.width(pq & $F)
      gr.color(2)
      pp := (pq & $F)*(pq & $F) + 5
      pq++
      gr.arc(mousex, mousey, pp, pp>>1, -k * 200, $200, 8, 0)

'' Draw an arc
''
''   x,y            - center of arc
''   xr,yr          - radii of arc
''   angle          - initial angle in bits[12..0] (0..$1FFF = 0°..359.956°)
''   anglestep      - angle step in bits[12..0]
''   steps          - number of steps (0 just leaves (x,y) at initial arc position)
''   arcmode        - 0: plot point(s)
''                    1: line to point(s)
''                    2: line between points
''                    3: line from point(s) to center
    else
      pq~
}
    'if right mouse button pressed, pause
'    repeat while mouse.button(1)

    'draw expanding pixel halo
'    gr.colorwidth(1,k)
'    gr.arc(0,0,80,30,-k<<5,$2000/9,9,0)

    'step bouncing lines
{    repeat i from 0 to lines - 1
      if ||~x[i] > 60
        -xs[i]
      if ||~y[i] > 40
        -ys[i]
      x[i] += xs[i]
      y[i] += ys[i]
}
    'draw bouncing lines
{    gr.colorwidth(1,thickness)
    gr.plot(~x[0], ~y[0])
    repeat i from 1 to lines - 1
      gr.line(~x[i],~y[i])
    gr.line(~x[0], ~y[0])
}
    'draw spinning stars and revolving crosshairs and dogs
{    gr.colorwidth(2,0)
    repeat i from 0 to 7
'' Draw a vector sprite at an arc position
''
''   x,y            - center of arc
''   xr,yr          - radii of arc
''   angle          - angle in bits[12..0] (0..$1FFF = 0°..359.956°)
''   vecscale       - scale of vector sprite ($100 = 1x)
''   vecangle       - rotation angle of vector sprite in bits[12..0]
''   vecdef_ptr     - address of vector sprite definition
      gr.vecarc(80,50,30,30,-(i<<10+k<<6),$40,-(k<<7),@vecdef2)

'' Draw a pixel sprite at an arc position
''
''   x,y            - center of arc
''   xr,yr          - radii of arc
''   angle          - angle in bits[12..0] (0..$1FFF = 0°..359.956°)
''   pixrot         - 0: 0°, 1: 90°, 2: 180°, 3: 270°, +4: mirror
''   pixdef_ptr     - address of pixel sprite definition
      gr.pixarc(-80,-40,30,30,i<<10+k<<6,0,@pixdef2)                           'dogs
      gr.pixarc(-80,-40,20,20,-(i<<10+k<<6),0,@pixdef)
}
    'draw small box with text
{    gr.colorwidth(1,14)
    gr.box(60,-80,60,16)
    gr.textmode(1,1,6,5)
    gr.colorwidth(2,0)
    gr.text(90,-72,@pchip)
}
    'draw incrementing digit
{    if not ++numx & 7
      numchr++
    if numchr < "0" or numchr > "9"
      numchr := "0"
    gr.textmode(8,8,6,5)
    gr.colorwidth(1,8)
    gr.text(-90,50,@numchr)
}
    'copy bitmap to display
    gr.copy(display_base)

    'increment counter that makes everything change
    k++
    

DAT

tvparams                long    0               'status
                        long    1               'enable
                        long    %001_0101       'pins
                        long    %0001           'mode
                        long    0               'screen
                        long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    0               'broadcast
                        long    0               'auralcog

'' Vector sprite definition:
''
''    word    $8000|$4000+angle       'vector mode + 13-bit angle (mode: $4000=plot, $8000=line)
''    word    length                  'vector length
''    ...                             'more vectors
''    ...
''    word    0                       'end of definition
pianodef                word    $4000+$2000/3*0         'piano octave
                        word    50
                        word    $8000+$2000/3*1+1
                        word    50
                        word    $8000+$2000/3*2-1
                        word    50
                        word    $8000+$2000/3*0
                        word    50
                        word    0




vecdef                  word    $4000+$2000/3*0         'triangle
                        word    50
                        word    $8000+$2000/3*1+1
                        word    50
                        word    $8000+$2000/3*2-1
                        word    50
                        word    $8000+$2000/3*0
                        word    50
                        word    0

vecdef2                 word    $4000+$2000/12*0        'star
                        word    50
                        word    $8000+$2000/12*1
                        word    20
                        word    $8000+$2000/12*2
                        word    50
                        word    $8000+$2000/12*3
                        word    20
                        word    $8000+$2000/12*4
                        word    50
                        word    $8000+$2000/12*5
                        word    20
                        word    $8000+$2000/12*6
                        word    50
                        word    $8000+$2000/12*7
                        word    20
                        word    $8000+$2000/12*8
                        word    50
                        word    $8000+$2000/12*9
                        word    20
                        word    $8000+$2000/12*10
                        word    50
                        word    $8000+$2000/12*11
                        word    20
                        word    $8000+$2000/12*0
                        word    50
                        word    0
' pixdef:       word
'               byte    xwords, ywords, xorigin, yorigin
'               word    %%xxxxxxxx,%%xxxxxxxx
'               word    %%xxxxxxxx,%%xxxxxxxx
'               word    %%xxxxxxxx,%%xxxxxxxx
'               ...
pixdef                  word                            'crosshair
                        byte    2,7,3,3
                        word    %%00333000,%%00000000
                        word    %%03020300,%%00000000
                        word    %%30020030,%%00000000
                        word    %%32222230,%%00000000
                        word    %%30020030,%%02000000
                        word    %%03020300,%%22200000
                        word    %%00333000,%%02000000

pixdef2                 word                            'dog
                        byte    1,4,0,3
                        word    %%20000022
                        word    %%02222222
                        word    %%02222200
                        word    %%02000200

pchip                   byte    "Propeller",0           'text

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
