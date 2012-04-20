{
********************************************
           VGA graphics Engine         V1.1
********************************************
coded by Beau Schwabe (Parallax)
********************************************


Version 1.0 - initial test release
  
Version 1.1 - Optimized Nested Assembly routines and reduced variable overhead
            - fixed offset problem with 'boxfill' command

}

CON
  tiles    = vga#xtiles * vga#ytiles
  tiles32  = tiles * 16 'orig 32

  #1, _Sine,_Cosine,_ArcSine,_Plot,_Point,_Character,_Line,_Box,_BoxFill,_PixelColor,_PixelAddress

VAR
    long  cog, command
    long  sync, pixels[tiles32]
    word  colors[tiles]
    byte  textdata[33]
    
OBJ
'  vga : "vga_512x384_bitmap"
  vga   : "vga_320x240_bitmap"

CON'#############################################################################################################
'                               Entry/Exit Routines                                                        
'################################################################################################################
PUB start : okay | pa
'' returns false if no cog available
    stop
    vga.start(16, @colors, @pixels, @sync)              'start VGA driver
    okay := cog := cognew(@loop, @command) + 1          'start VGA graphics & text driver
    pa := @pixels
    setcommand(_PixelAddress, @pa)                      'Set Pixel Address
PUB stop
'' Stop Assembly Function Engine - frees a cog
    if cog
       cogstop(cog~ - 1)                                'stop VGA graphics & text driver 
       vga.stop                                         'stop VGA driver                               
    command~
CON'#############################################################################################################
'                               Spin Assembly Calls
'################################################################################################################
PUB Sine(Ang)|Arg1_             ' Input = 13-bit angle ranging from 0 to 8191
                                'Output = 16-bit Sine value ranging from $FFFF0001 ('-1') to $0000FFFF ('1')
    setcommand(_Sine, @Ang)
    Result := Arg1_
PUB Cosine(Ang)|Arg1_           ' Input = 13-bit angle ranging from 0 to 8191
                                'Output = 16-bit Cosine value ranging from $FFFF0001 ('-1') to $0000FFFF ('1')
    setcommand(_Cosine, @Ang)
    Result := Arg1_
PUB ArcSine(Ang)|Arg1_          ' Input = signed 16-bit value ranging from $FFFF0001 ('-1') to $0000FFFF ('1')
                                'Output = signed 11-bit angle ranging from -2047 (-pi/2) to 2047 (pi/2)  
    setcommand(_ArcSine, @Ang)
    Result := Arg1_
PUB ArcCosine(Ang)|Arg1_,sign   ' Input = signed 16-bit value ranging from $FFFF0001 ('-1') to $0000FFFF ('1')
    sign := Ang                 'Output = signed 11-bit angle ranging from -2047 (-pi/2) to 2047 (pi/2)
    Ang := || Ang
    setcommand(_ArcSine, @Ang)
    if sign <> Ang
       sign := -1
    else
       sign := 1   
    Result := (Sin_90 - Arg1_)* sign
PUB plot(x,y)                   'Sets pixel value at location x,y
    setcommand(_Plot, @x)
PUB point(x,y)|Arg2_            'Reads pixel value at location x,y
    setcommand(_Point, @x)
    Result := Arg2_
PUB character(offX,offY,chr)    'Place a text character from the ROM table at offset location offsetX,offsetY
    setcommand(_Character, @offX)
PUB line (px_,py_,dx_,dy_)      'Draws line from px,py to dx,dy
    setcommand(_Line, @px_)
PUB box(x1_,y1_,x2_,y2_)        'Draws a box from opposite corners x1,y1 and x2,y2
    setcommand(_Box, @x1_)
PUB boxfill(x1_,y1_,x2_,y2_)    'Draws a filled box from opposite corners x1,y1 and x2,y2
    setcommand(_BoxFill, @x1_)
PUB pointcolor(pc)              'Sets pixel color "1" or "0"
    setcommand(_PixelColor, @pc)
CON'#############################################################################################################
'                               Spin Routines
'################################################################################################################
PUB color(tile,cval)            'Set Color tiles on VGA screen
    colors[tile] := cval
PUB get_colors_address
    return @colors
PUB Text(offX,offY,Address)|chr,i                       'Place a text string from the ROM table at offset location offsetX,offsetY
    i := 0
    repeat 
      chr := byte[Address + i] 
      i++       
      if chr <> 0
         character(offX,offY,chr)
         offX := offX + 16
      else
         quit
PUB shape(x,y,sizeX,sizeY,sides,rotation)|angle,sx1,sy1,sx2,sy2         'Draws a shape with center located at x,y
    if sides => 3                                                               'sizeX and sizeY - control shape aspect ratio
       repeat angle from 8191/sides to 8191 step 8191/sides                     '          sides - select the number shape sides
         sx1 := x +   sine(angle+rotation)*sizeX/131070                         '       rotation - determines shape orientation
         sy1 := y + cosine(angle+rotation)*sizeY/131070
         sx2 := x +   sine(angle+rotation+8191/sides)*sizeX/131070
         sy2 := y + cosine(angle+rotation+8191/sides)*sizeY/131070
         line(sx1,sy1,sx2,sy2)
PUB deg(angle)                                          'translate deg(0-360) ---> to ---> 13-bit angle(0-8192)
    return (angle * 1024)/45                                             
PUB bit13(angle)                                        'translate 13-bit angle(0-8192) ---> to ---> deg(0-360)
    return (angle * 45)/1024
PUB SimpleNum(x,y,DecimalNumber,DecimalPoint)|sign,DecimalIndex,TempNum,spacing,DecimalFlag,Digit
{     x,y           - upper right text coordinate of MSD (Most Significant Digit)
      DecimalNumber - signed Decimal number
      DecimalPoint  - number of places from the Right the decimal point should be
}
    spacing := 16
    DecimalIndex := 0
    TempNum := DecimalNumber                            'Preserve sign of DecimalNumber
    DecimalNumber := ||DecimalNumber
    if DecimalNumber <> TempNum 
       sign := 1
    else
       sign := 0
    if DecimalPoint == 0
       character(x,y,$30)                               'Insert Zero
       x := x - spacing
    repeat                                              'Print digits
      if DecimalIndex == DecimalPoint
         character(x,y,$2E)                             'Insert decimal point at proper location
         x := x - spacing
      TempNum := DecimalNumber                          'Extract the least significant digit
      TempNum := DecimalNumber - ((TempNum / 10) * 10)
      Digit := $30 + TempNum                            'Display the least significant digit
      character(x,y,Digit)
      x := x - spacing
      DecimalIndex := DecimalIndex + 1
      DecimalNumber := DecimalNumber / 10               'Divide DecimalNumber by 10 
      if DecimalNumber == 0                             'Exit logic
         repeat while DecimalIndex < DecimalPoint       '   Do this if DecimalNumber is less than where the decimal point should be
            character(x,y,$30)
            x := x - spacing
            DecimalIndex := DecimalIndex + 1
            DecimalFlag := 1
         if DecimalIndex == DecimalPoint                '   Set flag if DecimalNumber is equal to where the decimal point should be  
            DecimalFlag := 1   
         if DecimalFlag == 1
            character(x,y,$2E)                          '   Insert decimal and leading Zero
            x := x - spacing
            character(x,y,$30)                          
            x := x - spacing                
         if sign == 1                                   '   Restore sign of DecimalNumber
            character(x,y,$2D)
         quit
PRI setcommand(cmd, argptr)
    command := cmd << 16 + argptr                       'write command and pointer
    repeat while command                                'wait for command to be cleared, signifying receipt
CON'#############################################################################################################
'                               Assembly Routines
'################################################################################################################
DAT
                        org
'
' VGA graphics Engine - main loop
'
loop                    rdlong  t1,par          wz      'wait for command
        if_z            jmp     #loop
                        movd    :arg,#arg0              'get 7 arguments
                        mov     t2,t1
                        mov     t3,#7                           
:arg                    rdlong  arg0,t2
                        add     :arg,d0
                        add     t2,#4
                        djnz    t3,#:arg
                        mov     AddressLocation,t1      'preserve address location for passing
                                                        'variables back to spin language.
                        wrlong  zero,par                'zero command to signify command received
                        ror     t1,#16+2                'lookup command address
                        add     t1,#jumps
                        movs    :table,t1
                        rol     t1,#2
                        shl     t1,#3
:table                  mov     t2,0
                        shr     t2,t1
                        and     t2,#$FF
                        jmp     t2                      'jump to command
jumps                   byte    0                       '0
                        byte    Sine_                   '1
                        byte    Cosine_                 '2
                        byte    ArcSine_                '3
                        byte    Pixel_                  '4
                        byte    Point_                  '5
                        byte    Character_              '6
                        byte    Line_                   '7
                        byte    Box_                    '8
                        byte    BoxFill_                '9 
                        byte    PixelColor_             '10 
                        byte    PixelAddress_           '11
                        byte    NotUsed_                '─┐                                                               
                        byte    NotUsed_                '  │                                                               
                        byte    NotUsed_                '  ┣─ Additional functions MUST be in groups of 4-bytes (1 long)  
                        byte    NotUsed_                '─┘   With this setup, there is a limit of 256 possible functions.
NotUsed_
                        jmp     #loop
{################################################################################################################
Sine/cosine

quadrant:            1             2             3             4
angle:         $0000...$07FF $0800...$0FFF $1000...$17FF $1800...$1FFF
table index:   $0000...$07FF $0800...$0001 $0000...$07FF $0800...$0001
mirror:           +offset       -offset       +offset       -offset
flip:             +sample       +sample       -sample       -sample

on entry: sin[12..0] holds angle (0° to just under 360°)
on exit: sin holds signed value ranging from $0000FFFF ('1') to $FFFF0001 ('-1')
}
Cosine_       mov       t1,     Arg0            '<--- cosine entry
              add       t1,     sin_90
              jmp       #CSentry
Sine_         mov       t1,     Arg0            '<--- sine entry

CSentry       test      t1,     Sin_90          wc
              test      t1,     Sin_180         wz
              negc      t1,     t1
              or        t1,    Sin_Table
              shl       t1,     #1
              rdword    t1,     t1
              negnz     t1,     t1
              mov       t2,     AddressLocation 'Write data back to Arg1
              add       t2,     #4
              wrlong    t1,     t2              
                                                '<--- cosine/sine exit
              jmp       #loop                           'Go wait for next command
{################################################################################################################
ArcSine/ArcCosine

on entry: t2 holds signed 16-bit value ranging from $FFFF0001 ('-1') to $0000FFFF ('1')
on    exit: t7 holds signed 11-bit angle ranging from -2047 (-pi/2) to 2047 (pi/2)
}
ArcSine_                                        '<--- ArcSine entry (t2)
              mov       t2,     Arg0            
              mov       t3,     t2                      'Preserve sign (t3) ; if '-' then t3 = 1
              shr       t3,     #31
              abs       t2,     t2                      'Convert to absolute value
              mov       t4,     sin_90                  'Preload RefHigh (t4) to 2048
              mov       t5,     #0                      'Preload RefLow  (t5) to    0
              mov       t6,     #11                     'Iterations (t6) - equals # of bits on output resolution.
Iteration_Loop
              mov       t7,     t4                      'Add RefHigh and RefLow ; divide by 2 to get Pivot point (t7)
              add       t7,     t5
              shr       t7,     #1
              mov       t8,     t7                      'Lookup sine value from Pivot location ; range 0-2048 ; 0 to pi/2
              or        t8,     sin_table
              shl       t8,     #1
              rdword    t8,     t8                      't8 holds sine value ranging from $0000FFFF ('1') to $FFFF0001 ('-1')
              cmps      t2,     t8              wc      'Set 'C' if Input (t2) < 'Sine value'(t8)
        if_c  mov       t4,     t7                      'If Input < 'Sine value' then RefHigh = Pivot
        if_nc mov       t5,     t7                      'If Input >= 'Sine value' then RefLow = Pivot
              djnz      t6,     #Iteration_Loop         'Re-Iterate to Pin-Point Reverse Sine lookup value.
              cmp       t3,     #1              wc      'Restore sign from t3
        if_nc neg       t7,     t7       
              mov       t1,     AddressLocation         'Write data back to Arg1
              add       t1,     #4
              wrlong    t7,     t1
              jmp       #loop                           'Go wait for next command
'################################################################################################################
Line_         mov       px,                     Arg0
              mov       py,                     Arg1
              mov       dx,                     Arg2
              mov       dy,                     Arg3
              call      #LineDraw
              jmp       #loop                           'Go wait for next command
{----------------------------------------------------------------------------------------------------------------
LineDraw

Draws line from px,py to dx,dy
}
LineDraw
Xcondition    sub       px,                     dx                            nr,wc
       if_nc  jmp       #px_dominant
dx_dominant   mov       sx,                     #1
              mov       deltaX,                 dx
              sub       deltaX,                 px
              jmp       #Ycondition        
px_dominant   mov       sx,                     #0
              mov       deltaX,                 px
              sub       deltaX,                 dx
Ycondition    sub       py,                     dy      nr,wc               
       if_nc  jmp       #py_dominant
dy_dominant   mov       sy,                     #1
              mov       deltaY,                 dy 
              sub       deltaY,                 py
              jmp       #DeltaCondition
py_dominant   mov       sy,                     #0          
              mov       deltaY,                 py 
              sub       deltaY,                 dy
DeltaCondition              
              mov       ratio,                  #0
              sub       deltaY,                 deltaX  nr,wc
       if_nc  jmp       #deltaYdominate
deltaXdominate
              mov       deltacount,             deltaX
              add       deltacount,             #1
deltaXplot    call      #LinePlot
              test      sx,                     #1      wc
        if_c  add       px,                     #1
        if_nc sub       px,                     #1
              add       ratio,                  deltaY
              sub       deltaX,                 ratio   nr,wc
        if_c  jmp       #ratioXoverflow
              jmp       #deltaXdominateDone
ratioXoverflow
              sub       ratio,                  deltaX
              test      sy,                     #1      wc
        if_c  add       py,                     #1
        if_nc sub       py,                     #1
deltaXdominateDone
              djnz      deltacount,             #deltaXplot                                       
              jmp       #LineDraw_ret
deltaYdominate
              mov       deltacount,             deltaY
              add       deltacount,             #1
deltaYplot    call      #LinePlot
              test      sy,                     #1      wc
        if_c  add       py,                     #1
        if_nc sub       py,                     #1
              add       ratio,                  deltaX
              sub       deltaY,                 ratio   nr,wc
        if_c  jmp       #ratioYoverflow
              jmp       #deltaYdominateDone
ratioYoverflow                                  
              sub       ratio,                  deltaY
              test      sx,                     #1      wc
        if_c  add       px,                     #1
        if_nc sub       px,                     #1              
deltaYdominateDone
              djnz      deltacount,             #deltaYplot
              jmp       #LineDraw_ret
LinePlot      mov       PixelX,                 px
              mov       PixelY,                 py
              call      #Pixel
LinePlot_ret  ret
LineDraw_ret  ret
{################################################################################################################
Box

Draws a box from opposite corners x1,y1 and x2,y2
}
Box_          mov       px,   Arg0
              mov       py,   Arg1
              mov       dx,   Arg0
              mov       dy,   Arg3
              call      #LineDraw
              mov       px,   Arg0
              mov       py,   Arg1
              mov       dx,   Arg2
              mov       dy,   Arg1
              call      #LineDraw
              mov       px,   Arg2
              mov       py,   Arg3
              mov       dx,   Arg0
              mov       dy,   Arg3
              call      #LineDraw
              mov       px,   Arg2
              mov       py,   Arg3
              mov       dx,   Arg2
              mov       dy,   Arg1
              call      #LineDraw             
              jmp       #loop                           'Go wait for next command
{################################################################################################################
BoxFill

Draws a filled box from opposite corners x1,y1 and x2,y2
}
BoxFill_
              mov       t4,    Arg0
              mov       t6,    Arg1
              mov       t5,    Arg2
              mov       t7,    Arg3
              sub       t4,    t5                           nr,wc
        if_nc mov       Xcount, t4
        if_nc sub       Xcount, t5
        if_c  mov       Xcount, t5
        if_c  sub       Xcount, t4
NextLine      mov       px,     Xcount
              add       px,     t4
              mov       py,     t6
              mov       dx,     Xcount
              add       dx,     t4
              mov       dy,     t7
              call      #LineDraw
              djnz      Xcount,  #NextLine
              jmp       #loop                           'Go wait for next command
{################################################################################################################
Character

Place a text character from the ROM table at offset location offsetX,offsetY
}
Character_    mov       offsetX,                Arg0
              mov       offsetY,                Arg1
              mov       Char,                   Arg2
              mov       Ycount,                 #31                     'Preset Y repeat loop
RepeatY       mov       Xcount,                 #15                     'Preset X repeat loop
'------------------------------------------------------------------------------------------------                                                        
              mov       t4,     Char     
              and       t4,     #1                      'chr & 1
              add       t4,     #30
              mov       t5,     #1                      '|<30    or    |<31
              shl       t5,     t4       'Create bit mask (t5)       = |<(30 + chr & 1)               
'------------------------------------------------------------------------------------------------
              mov       t6,     CharacterTable          'CharacterTable = $8000
              mov       t4,     Ycount                      'y * 4
              shl       t4,     #2
              add       t6,     t4
              mov       t4,     Char                    'chr * 64
              shl       t4,     #6
              add       t6,     t4
              mov       t4,     Char                    '(chr & 1)*64
              and       t4,     #1
              shl       t4,     #6
              sub       t6,     t4
              rdlong    t6,     t6      'Read 32bit character data   = long[$8000 + y*4+chr*64-(chr & 1)*64]
'------------------------------------------------------------------------------------------------
RepeatX       test      t6,     t5             wc
              if_nc jmp         #NoPointPlot
PlotPoint     mov       PixelX, Xcount
              add       PixelX, offsetX 
              mov       PixelY, Ycount
              add       PixelY, offsetY
              call      #Pixel                          'Go PLOT point
NoPointPlot   shr       t5,     #2
              djnz      Xcount, #RepeatX
              djnz      Ycount, #RepeatY
              jmp       #loop                           'Go wait for next command
'################################################################################################################
Pixel_        mov       PixelX,                 Arg0
              mov       PixelY,                 Arg1
              call      #Pixel
              jmp       #loop                           'Go wait for next command
{----------------------------------------------------------------------------------------------------------------
Pixel

Plots a pixel at location x,y ; pixel color must be set with pointcolor 
}                                               
Pixel         call      #Pixel_Core
              test      PixelColor, #1          wc      'Test if pixel is ON "1" or OFF "0"
        if_c  jmp       #P_On
P_Off         andn      t1,     t3                      'Clear pixel using tile contents and bit mask  
              jmp       #Pixel_done                     'Pixel Done
P_On          or        t1,     t3                      'Set pixel using tile contents and bit mask
Pixel_done    wrlong    t1,     t2                      'Write tile contents
Pixel_ret     ret
'------------------------------------------------------------------------------------------------
Pixel_Core    cmps      PixelX, #0              wc      'Set 'C' if x < 0
        if_nc cmps      PixelY, #0              wc      'Set 'C' if y < 0  
        if_nc cmps      Xlimit, PixelX          wc      'Set 'C' if x > Xlimit
        if_nc cmps      Ylimit, PixelY          wc      'Set 'C' if y > Ylimit
        if_c  jmp       Pixel_ret                       'Plot points are out of bounds ; skip function
              mov       t1,     PixelY                  'Calculate Tile position where pixel is located
              mov       temp,   t1
              shl       temp,   #1
              shl       t1,     #3                      'Multiply 'y' by 10 -ph modified from 16 for 320x240 driver
              add       t1,     temp
              mov       t2,     PixelX
              shr       t2,     #5                      'Divide 'x' by 32
              add       t1,     t2                      'Get title position
              shl       t1,     #2                      '...multiply by 4 for 'long' position offset
              mov       t2,     PixelAddress
              add       t2,     t1                      'Add offset to pixel address to get tile address
              rdlong    t1,     t2                      'Read tile contents
              mov       t3,     #1
              shl       t3,     PixelX                  'Create bit mask
Pixel_Core_ret ret
'------------------------------------------------------------------------------------------------
PixelColor_   mov       PixelColor,             Arg0
              jmp       #loop                           'Go wait for next command
'------------------------------------------------------------------------------------------------
PixelAddress_ mov       PixelAddress,           Arg0
              jmp       #loop                           'Go wait for next command              
{################################################################################################################
Point

Reads pixel value at location x,y
}
Point_        mov       PixelX,                 Arg0
              mov       PixelY,                 Arg1
              mov       PixelColor,             #0
              call      #Pixel_Core
              test      t1,     t3              wc
              rcl       PixelColor,             #1
              mov       t2,                     AddressLocation 'Write data back to Arg2
              add       t2,                     #8
              wrlong    PixelColor,             t2
{
########################### Defined data ###########################
}
zero                    long    0                       'constants
d0                      long    $200
{Xlimit                  long    511
Ylimit                  long    383}
Xlimit                  long    319
Ylimit                  long    239
CharacterTable          long    $8000
Sin_90                  long    $0800
Sin_180                 long    $1000
sin_table               long    $E000 >> 1              'sine table base shifted right
{
########################### Undefined data ###########################
}
t1                      res     1                       
t2                      res     1
t3                      res     1
t4                      res     1
t5                      res     1
t6                      res     1
t7                      res     1
t8                      res     1
AddressLocation         res     1
offsetX                 res     1
offsetY                 res     1
deltaX                  res     1
deltaY                  res     1
sx                      res     1
sy                      res     1
ratio                   res     1
deltacount              res     1
PixelX                  res     1
PixelY                  res     1
PixelAddress            res     1
PixelColor              res     1
Char                    res     1
Xcount                  res     1
Ycount                  res     1
px                      res     1
py                      res     1
dx                      res     1
dy                      res     1

arg0                    res     1                       'arguments passed from high-level
arg1                    res     1
arg2                    res     1
arg3                    res     1
arg4                    res     1
arg5                    res     1
arg6                    res     1

temp                    res     1
