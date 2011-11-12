{Object_Title_and_Purpose}


CON
        _clkmode = xtal1 + pll16x                                               'Standard clock mode * crystal frequency = 80 MHz
        _xinfreq = 5_000_000

  vga_params = 21
  cols = 32
  rows = 16
  screensize = cols * rows

VAR           

  long  vga_status      'status: off/visible/invisible  read-only       (21 contiguous longs)
  long  vga_enable      'enable: off/on                 write-only
  long  vga_pins        'pins: byte(2),topbit(3)        write-only
  long  vga_mode        'mode: interlace,hpol,vpol      write-only
  long  vga_videobase   'video base @word               write-only
  long  vga_colorbase   'color base @long               write-only              
  long  vga_hc          'horizontal cells               write-only
  long  vga_vc          'vertical cells                 write-only
  long  vga_hx          'horizontal cell expansion      write-only
  long  vga_vx          'vertical cell expansion        write-only
  long  vga_ho          'horizontal offset              write-only
  long  vga_vo          'vertical offset                write-only
  long  vga_hd          'horizontal display pixels      write-only
  long  vga_hf          'horizontal front-porch pixels  write-only
  long  vga_hs          'horizontal sync pixels         write-only
  long  vga_hb          'horizontal back-porch pixels   write-only
  long  vga_vd          'vertical display lines         write-only
  long  vga_vf          'vertical front-porch lines     write-only
  long  vga_vs          'vertical sync lines            write-only
  long  vga_vb          'vertical back-porch lines      write-only
  long  vga_rate        'pixel rate (Hz)                write-only

  word  screen[screensize]

  long  col, row, color
  long  boxcolor,ptr
  long  stack[100] 
   
OBJ
  fft    : "fft"
  vga    : "vga"
  pst    : "Parallax Serial Terminal"                   ' Serial communication object
 ' sampler : "sampler"              

PUB go | value , i                                 

  pst.Start(115200)                                                             ' Start the Parallax Serial Terminal cog
  pst.Str(String("vga cog:"))
  pst.Hex(cognew(start, @stack) , 1) 
  pst.Chars(pst#NL, 2)


  pst.Str(String("fft cog:"))
  pst.Hex(@screen , 16)
  'pst.Hex(fft.start(@screen) , 2) 
  pst.Chars(pst#NL, 2)
    
  repeat i from 0 to $0F
   print(i)    
   
''---------------- Replace the code below with your test code ----------------
  
  pst.Str(String("Convert Decimal to Hexadecimal..."))                          ' Heading
  repeat                                                                        ' Main loop
    pst.Chars(pst#NL, 2)                                                        ' Carriage returns
    pst.Str(String("Enter decimal value: "))                                    ' Prompt user to enter value
    value := pst.DecIn                                                          ' Get value
    pst.Str(String(pst#NL,"Your value in hexadecimal is: $"))                   ' Announce output
    pst.Hex(value, 8)                                                           ' Display hexadecimal value



'' Start terminal - starts a cog
'' returns false if no cog available

PUB start | i
  print($100)
  longmove(@vga_status, @vgaparams, vga_params)
  vga_pins := %010111
  vga_videobase := @screen      ''$4000
  vga_colorbase := @vgacolors
  result := vga.start(@vga_status)
  print($112)
  repeat i from 0 to $FF
   print(i)
 

'' Stop terminal - frees a cog

PUB stop

  vga.stop
  pst.stop


PUB print(c) | i, k

  case c
    $00..$FF:           'character?
      k := color << 1 + c & 1
      i := k << 10 + $200 + c & $FE
      screen[row * cols + col] := i
      screen[(row + 1) * cols + col] := i | 1
      if ++col == cols
        newline

    $100:               'clear screen?
      wordfill(@screen, $200, screensize)
      col := row := 0

    $108:               'backspace?
      if col
        col--

    $10D:               'return?
      newline

    $110..$11F:         'select color?
      color := c & $F


' New line

PRI newline : i

  col := 0
  if (row += 2) == rows
    row -= 2
    'scroll lines
    repeat i from 0 to rows-3
'      wordmove(@screen[i*cols], @screen[(i+2)*cols], cols)
    'clear new line
'    wordfill(@screen[(rows-2)*cols], $200, cols<<1)



' Data

DAT

vgaparams               long    0               'status
                        long    1               'enable
                        long    %010_111        'pins
                        long    %011            'mode
                        long    0               'videobase
                        long    0               'colorbase
                        long    cols            'hc
                        long    rows            'vc
                        long    1               'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    512             'hd
                        long    16              'hf
                        long    96              'hs
                        long    48              'hb
                        long    380             'vd
                        long    11              'vf
                        long    2               'vs
                        long    31              'vb
                        long    20_000_000      'rate

vgacolors               long
                        long    $C000C000       'red
                        long    $C0C00000
                        long    $08A808A8       'green
                        long    $0808A8A8
                        long    $50005000       'blue
                        long    $50500000
                        long    $FC00FC00       'white
                        long    $FCFC0000
                        long    $FF80FF80       'red/white
                        long    $FFFF8080
                        long    $FF20FF20       'green/white
                        long    $FFFF2020
                        long    $FF28FF28       'cyan/white
                        long    $FFFF2828
                        long    $00A800A8       'grey/black
                        long    $0000A8A8
                        long    $C0408080       'redbox
spcl                    long    $30100020       'greenbox
                        long    $3C142828       'cyanbox
                        long    $FC54A8A8       'greybox
                        long    $3C14FF28       'cyanbox+underscore
                        long    0