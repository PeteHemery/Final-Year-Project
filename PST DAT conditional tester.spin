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

CON

  _clkmode = xtal1 + pll16x                             ' Crystal and PLL settings.
  _xinfreq = 5_000_000                                  ' 5 MHz crystal (5 MHz x 16 = 80 MHz).

OBJ

  pst    : "Parallax Serial Terminal"                   ' Serial communication object

VAR     long          tester

PUB go | value, okay, flag, i

  pst.Start(115200)                                                             ' Start the Parallax Serial Terminal cog
  tester := $70
  pst.Str(String(pst#NL,"1st tester value: ",pst#NL))
  pst.Hex(tester,8)
  okay := cognew(@init, @tester) + 1


  repeat                                                                        ' Main loop
    pst.Str(String(pst#NL,"tester address: "))
    pst.Hex(@tester,8)
    pst.Str(String(pst#NL,"tester value: "))
    pst.Hex(tester,8)
    pst.Str(String(pst#NL))

    repeat i from 0 to 16
      waitcnt(5_000_000 + cnt) 'Wait for 1s



DAT
                        org   0
init                    mov     in_ptr,PAR
                        rdlong  flag_value,in_ptr           'address of status flag
looper                  add     flag_value,#1
                        test    reset_limit,flag_value  wz
              if_nz     mov     flag_value,#1

                        wrlong  flag_value,in_ptr

'                        test    flag_value,#3   wz
'              if_z      wrlong  flag_value,in_ptr
'              if_z      mov     flag_value,#1
                        jmp     looper


in_ptr        long 0
flag_value    long 0
reset_limit   long $40000

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
