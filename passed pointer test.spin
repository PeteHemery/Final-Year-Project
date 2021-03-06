{{
┌────────────────────────────────────────┐
│ Parallax Serial Terminal Template v1.0 │
│ Author: Jeff Martin, Andy Lindsay      │               
│ Copyright (c) 2009 Parallax Inc.       │               
│ See end of file for terms of use.      │                
└────────────────────────────────────────┘

Template for Parallax Serial Terminal test applications; use this to quickly get started with a Propeller chip
running at 80 MHz and the Parallax Serial Terminal software (included with the Propeller Tool).

How to use:

 o In the Propeller Tool software, press the F7 key to determine the COM port of the connected Propeller chip.
 o Run the Parallax Serial Terminal (included with the Propeller Tool) and set it to the same COM Port with a
   baud rate of 115200.
 o Press the F10 (or F11) key in the Propeller tool to load the code.
 o Immediately click the Parallax Serial Terminal's Enable button.  Do not wait until the program is finished
   downloading.

Revision History:
Version 1.0 - Changed name from "...Terminal QuickStart" to "...Terminal Template" to avoid confusion with the
              QuickStart development board.   
}}

{{
  11.11.2011 PHemery
  Pointer passing test application

  Pointers are set up for addresses of arrays in hub RAM.
  These pointers are passed via a function to a cog running PASM and reading those pointers.
  The PASM cog shall read those pointers correctly, and write to them fixed values.
  Original cog will read those values and output them to serial. 
}}

CON
   
  _clkmode = xtal1 + pll16x                             ' Crystal and PLL settings.
  _xinfreq = 5_000_000                                  ' 5 MHz crystal (5 MHz x 16 = 80 MHz).

OBJ

  pst    : "Parallax Serial Terminal"                   ' Serial communication object

VAR

  word  real_buffer[1024]
  word  imag_buffer[1024]
  word  screen[32*16]

  long  real_ptr
  long  imag_ptr
  long  scrn_ptr
  long  cog_flag


PUB go | value, okay, flag, i, temp                                  

  value := pst.Start(115200)                                                             ' Start the Parallax Serial Terminal cog

  real_ptr := $1234_CDEF
  imag_ptr := $5678_FACE  
  scrn_ptr := $90AB_ACED
  cog_flag := 0 
                   
  pst.Str(String("Started on cog "))
  pst.Dec(value)
  pst.Str(String(pst#NL,pst#NL,"Real Pointer initial value: "))
  pst.Hex(real_ptr,8)
  pst.Str(String(pst#NL,"Imag Pointer initial value: "))
  pst.Hex(imag_ptr,8)
  pst.Str(String(pst#NL,"Scrn Pointer initial value: "))
  pst.Hex(scrn_ptr,8)          

  real_ptr := @real_buffer
  imag_ptr := @imag_buffer
  scrn_ptr := @screen
  
  pst.Str(String(pst#NL,pst#NL,"RAM addresses",pst#NL,"Real Pointer value: "))
  pst.Hex(real_ptr,8)
  pst.Str(String(pst#NL,"Imag Pointer value: "))
  pst.Hex(imag_ptr,8)
  pst.Str(String(pst#NL,"Scrn Pointer value: "))
  pst.Hex(scrn_ptr,8)   

                        
  pst.Str(String(pst#NL,pst#NL,"RAM values",pst#NL,"Real [0] value: "))
  pst.Hex(long[real_ptr],8)
  pst.Str(String(pst#NL,"Imag [0] value: "))
  pst.Hex(long[imag_ptr],8)
  pst.Str(String(pst#NL,"Scrn [0] value: "))
  pst.Hex(long[scrn_ptr],8)          
  pst.Str(String(pst#NL,pst#NL))


  
  pst.Str(String("RAM pointer addresses",pst#NL,"Real Pointer address: "))
  pst.Hex(@real_ptr,8)
  pst.Str(String(pst#NL,"Imag Pointer address: "))
  pst.Hex(@imag_ptr,8)
  pst.Str(String(pst#NL,"Scrn Pointer address: "))
  pst.Hex(@scrn_ptr,8)  
  pst.Str(String(pst#NL,"Flag Pointer address: "))
  pst.Hex(@cog_flag,8)          
 
                              
  pst.Str(String(pst#NL,pst#NL,"Launching PASM on cog  "))
          
  value := start_pasm(@real_ptr)
  pst.Dec(value)

  'repeat while cog_flag == 0
   waitcnt(4_000_000 + cnt)


    
  pst.Str(String(pst#NL,pst#NL,"RAM addresses",pst#NL,"Real Pointer value: "))
  pst.Hex(real_ptr,8)
  pst.Str(String(pst#NL,"Imag Pointer value: "))
  pst.Hex(imag_ptr,8)
  pst.Str(String(pst#NL,"Scrn Pointer value: "))
  pst.Hex(scrn_ptr,8)          
  pst.Str(String(pst#NL))
                                        
  pst.Str(String(pst#NL,pst#NL,"RAM values",pst#NL,"Real value: "))
  pst.Hex(long[real_ptr],8)
  pst.Str(String(pst#NL,"Imag value: "))
  pst.Hex(word[imag_ptr],4)
  pst.Str(String(pst#NL,"Scrn value: "))
  pst.Hex(word[scrn_ptr],4)               
  pst.Str(String(pst#NL,"Flag value: "))
  pst.Dec(cog_flag)          
  pst.Str(String(pst#NL,pst#NL))




{{  repeat i from 0 to 1023
    case ((i + 1) // 4)
      0 : pst.NewLine              
      1 : pst.PositionX(12)
      2 : pst.PositionX(24)
      3 : pst.PositionX(36)
    pst.Str(String("  "))
    pst.Dec(i)
    pst.Str(String(": "))
    pst.Hex(word[@real_buffer][i],4)              
}}  
  

PUB start_pasm(r_ptr) : okay |  i 
  okay := cognew(@init, r_ptr) + 1










DAT
              org       0
init       
                        mov     in_ptr,PAR      'receive the address of the real array pointer

                        rdlong  realptr,in_ptr

                        add     in_ptr,#4
                        rdlong  imagptr,in_ptr
                              
                        add     in_ptr,#4
                        rdlong  scrnptr,in_ptr
                                                            
                        add     in_ptr,#4
                        mov     flagptr,in_ptr
          
                        wrlong  output,realptr
           
                        mov     output,#$101
                        wrlong  output,imagptr
                        
                        mov     output,#$99
                        wrlong  output,scrnptr

                        cogid   cog_id
                        mov     output,#1
                        wrlong  output,flagptr

                        cogstop   cog_id


realptr       long 0
imagptr       long 0
scrnptr       long 0  
flagptr       long 0
cog_id         long 0

in_ptr        long 0
output        long $ACEDFACE

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
