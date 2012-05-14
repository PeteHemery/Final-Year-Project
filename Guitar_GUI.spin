CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  _free = ($3000 + $3000) >> 2          'accomodate bitmap buffers
  _stack = $100                         'insure sufficient stack

  x_tiles = 16
  y_tiles = 12

  paramcount = 14
  bitmap_base = $2000
  display_base = $5000

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

OBJ

  tv    : "tv"
  gr    : "graphics"
  pst : "Parallax Serial Terminal"

PUB start | x, y, i, c, k, octave


  pst.start(115200)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)


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

  'init colors
  repeat i from $00 to $0F
    colors[i] := $4D02072E

  colors[0] := $2C2E0702       'background
'   colors[1] := $2C2E0207       'piano

  repeat i from $10 to $1F
    colors[i] := $10100000 * (i & $F) + $0E0A0507
{

  'init colors
  repeat i from $00 to $0F
    case i
      5..10 : c := $01000000 * (i - 5) + $02020507
      other  : c := $07020504
    colors[i] := c
  repeat i from $10 to $1F
    colors[i] := $10100000 * (i & $F) + $0B0A0507
  repeat i from $20 to $2F
    colors[i] := $10100000 * (i & $F) + $0D0C0507
  repeat i from $30 to $3F
    colors[i] := $10100000 * (i & $F) + $080E0507

  colors[0] := $2C2E0702       'background
}












  'init tile screen
  repeat x from 0 to tv_hc - 1
    repeat y from 0 to tv_vc - 1
'      screen[x + y * tv_hc] := $0 << 10 + display_base >> 6 + x * tv_vc + y

      case y
        0..3 : i := $01
        other:  i := $00
'      i := x
      screen[x + y * tv_hc] := i << 10 + display_base >> 6 + x * tv_vc + y


  'start and setup graphics
  gr.start
  gr.setup(16, 12, 0, 0, bitmap_base)

  repeat

    'clear bitmap
    gr.clear

    'draw color samples
    gr.width(20)
    'draw saturated samples
{    gr.color(3)
    repeat x from 0 to 15
      gr.plot(x << 4 + 7, 183)
}
'' Set pixel width
'' actual width is w[3..0] + 1
''
''   w              - 0..15 for round pixels, 16..31 for square pixels
{    gr.width(16)
    gr.pix($80, 150, 0, @pixdef)
}


    repeat i from 0 to 7
      gr.colorwidth(i//4,20)
      gr.plot(40+i<<2,$80)
      gr.line(40+i<<2,$80-30)

    repeat i from 0 to 6
      case i
        0, 2, 3, 5, 6 :  draw_black_note(4+i<<2+2,$80,18,17)

    draw_scale
    'copy bitmap to display
    gr.copy(display_base)


PUB draw_scale | i'(octave, notes)
'  gr.quad(10,100,10,150,50,150,50,100)

  repeat i from 0 to 7
    draw_white_note(4+i<<2,$B0,18,30)

  repeat i from 0 to 6
    case i
      0, 2, 3, 5, 6 :  draw_black_note(4+i<<2+2,$B0,18,17)

PUB draw_white_note(x,y,width,length)
{    gr.colorwidth(1,18)
    gr.plot(50,150)
    gr.line(50,180)
}
    gr.colorwidth(1,width)
    gr.plot(x,y)
    gr.line(x,y-length)

PUB draw_black_note(x,y,width,length)
    gr.colorwidth(2,width)
    gr.plot(x,y)
    gr.line(x,y-length)


DAT

tvparams                long    0               'status
                        long    1               'enable
                        long    %001_0101       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    60_000_000      'broadcast
                        long    0               'auralcog

' pixdef:       word
'               byte    xwords, ywords, xorigin, yorigin
'               word    %%xxxxxxxx,%%xxxxxxxx
'               word    %%xxxxxxxx,%%xxxxxxxx
'               word    %%xxxxxxxx,%%xxxxxxxx
'               ...
pixdef                  word                    'arrow pointer
                        byte    1,5,0,4
                        word    %%11110230
                        word    %%11100023
                        word    %%11110230
                        word    %%10111000
                        word    %%00011000

pixdef2                 word                            'crosshair
                        byte    2,7,3,3
                        word    %%00333000,%%00000000
                        word    %%03020300,%%00000000
                        word    %%30020030,%%00000000
                        word    %%32222230,%%00000000
                        word    %%30020030,%%02000000
                        word    %%03020300,%%22200000
                        word    %%00333000,%%02000000

colorstring             byte    "COLOR "
hexstring               byte    "00",0

