'':::::::[ FIR Filter ]::::::::::::::::::::::::::::::::::::::::::::::::::::::::

{{{

******************************************
*      FIR Filter Propeller Object       *
*  generated by www.phipi.com/fir2pasm   *
*  from the parameters given in the DAT  *
*          section of this file.         *
* (c) Copyright 2011 Bueno Systems, Inc. *
*    See end of file for terms of use.   *
******************************************

Created: Mon Jan 23 12:35:43 2012 UTC

}}

''=======[ Introduction ]======================================================

{{ This object provides a finite inpulse response (FIR) filter capable of filtering
   a single channel of input at a rate set by the user.
''   
   `Usage:
''     
     1. Call `start with an argument of 0 or the address of a two-long array.
''     
     2. `start stops a prior instance of the same object, if one is running.
''     
     3. Once started, the address provided to `start or the one provided by `start
        upon return will point to a "busy" long and, at the next location, a "data" 
        long.
''        
     From `Spin:
''     
     4. Call `filtera with the input datum as its single argument. It will return
        the next output from the filter.
''        
     From `PASM:
''        
     4. To issue the next datum for filtering, write it to the "data" address, then
        write a non-zero value to the "busy" address. When the "busy" long reverts
        back to zero, the filter output will be available at the "data" address.
}}

''=======[ Constants ]=========================================================   

CON

  SIZE          = 53
  BITS          = 12
  
''=======[ Instance Variables ]================================================

VAR

  long  busy, value
  word  busyaddr
  byte  cogno
  
''=======[ Public Spin Methods ]===============================================

PUB start(busy_addr)

  {{ Start the FIR filter in a new cog.
  ''
  '' `Parameters:
  ''
  ''     `busy_addr: Either 0 or the address of a two-long communication array.
  ''
  '' `Return: The address provided by `busy_addr or the address of the internal
  ''      array if 'busy_addr == 0 if a cog was started; or False (0) if no cog
  ''      was available.
  ''
  '' `Example: fir.start(0)
  ''
  ''     Start the FIR filter object using its internal communication array.
  }}
  
  stop
  if (busy_addr)
    busyaddr := busy_addr
  else
    busyaddr := @busy
  cogno := cognew(@fir_filter, busyaddr)
  return busyaddr & (++cogno <> 0)
  
PUB stop

  {{ Stop the FIR filter cog if one was started.
  ''
  '' `Example: fir.stop
  ''
  ''     Stop the FIR filter cog.
  }}

  if (cogno)
    cogstop(cogno~ - 1)  
  
PUB filtera(yy)

  {{ Return the next FIR-filtered value from sample `yy in the data stream.
  ''
  '' `Parameters:
  ''
  ''     `yy: The next input sample to filter.
  ''
  '' `Return: The next output from the filter.
  }}

  long[busyaddr][1] := yy
  long[busyaddr] := 1
  repeat while long[busyaddr]
  return long[busyaddr][1]

''=======[ PASM Code ]============================================================

{{ This is the code that does the actual filtering work, based upon the parameters
   and coefficients shown below in the source comments.
}}

DAT

'==========================================================================
'Parameters Given
'
'  53 coefficients:
'
'    -2.86475545e-02
'    -6.05600433e-02
'    -3.91616509e-02
'    +1.28170429e-02
'    +2.16538668e-02
'    -1.40134487e-02
'    -1.25202841e-02
'    +1.60970998e-02
'    +6.53284181e-03
'    -1.93721048e-02
'    +1.70427226e-03
'    +1.99059481e-02
'    -9.66036553e-03
'    -1.90288787e-02
'    +1.96636410e-02
'    +1.38597232e-02
'    -2.91844922e-02
'    -4.98488564e-03
'    +3.91919824e-02
'    -1.09167459e-02
'    -4.75071677e-02
'    +3.66893927e-02
'    +5.45901546e-02
'    -8.92738720e-02
'    -5.86942404e-02
'    +3.12382589e-01
'    +5.60457223e-01
'    +3.12382589e-01
'    -5.86942404e-02
'    -8.92738720e-02
'    +5.45901546e-02
'    +3.66893927e-02
'    -4.75071677e-02
'    -1.09167459e-02
'    +3.91919824e-02
'    -4.98488564e-03
'    -2.91844922e-02
'    +1.38597232e-02
'    +1.96636410e-02
'    -1.90288787e-02
'    -9.66036553e-03
'    +1.99059481e-02
'    +1.70427226e-03
'    -1.93721048e-02
'    +6.53284181e-03
'    +1.60970998e-02
'    -1.25202841e-02
'    -1.40134487e-02
'    +2.16538668e-02
'    +1.28170429e-02
'    -3.91616509e-02
'    -6.05600433e-02
'    -2.86475545e-02
'
'  Stated gain:  1.0000000
'  Desired gain: 1.0000000
'  Precision:    12 bits
'  Channels:     Single
'
'Resulting PASM instructions (not including overhead):
'
'  h*x computation: 88
'  y computation:   106
'
'==========================================================================

              org      0
fir_filter    mov      xy_addr,par              'Initialize the hub address for the data exchange.
              add      xy_addr,#4

'Further user initialization code can be added here.

main_lp                                         'DO NOT MODIFY.

'The next line can be altered to acquire the next input sample in another way.

              call      #get_x                  'Read the next input.

'Compute input * filter coefficients.         

              mov       h+25,x                  'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              mov       h+24,x                  'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              mov       h+22,x                  'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              mov       h+1,x                   'DO NOT MODIFY.
              add       h+24,x                  'DO NOT MODIFY.
              mov       h+23,x                  'DO NOT MODIFY.
              mov       h+19,x                  'DO NOT MODIFY.
              mov       h+21,x                  'DO NOT MODIFY.
              add       h+25,x                  'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              mov       h+0,x                   'DO NOT MODIFY.
              sub       h+22,x                  'DO NOT MODIFY.
              mov       h+16,x                  'DO NOT MODIFY.
              mov       h+2,x                   'DO NOT MODIFY.
              mov       h+4,x                   'DO NOT MODIFY.
              mov       h+20,x                  'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              mov       h+15,x                  'DO NOT MODIFY.
              mov       h+14,x                  'DO NOT MODIFY.
              mov       h+5,x                   'DO NOT MODIFY.
              mov       h+18,x                  'DO NOT MODIFY.
              mov       h+11,x                  'DO NOT MODIFY.
              mov       h+13,x                  'DO NOT MODIFY.
              sub       h+19,x                  'DO NOT MODIFY.
              mov       h+6,x                   'DO NOT MODIFY.
              mov       h+7,x                   'DO NOT MODIFY.
              mov       h+3,x                   'DO NOT MODIFY.
              mov       h+9,x                   'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              mov       h+12,x                  'DO NOT MODIFY.
              mov       h+8,x                   'DO NOT MODIFY.
              add       h+2,x                   'DO NOT MODIFY.
              sub       h+4,x                   'DO NOT MODIFY.
              sub       h+21,x                  'DO NOT MODIFY.
              add       h+20,x                  'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              sub       h+0,x                   'DO NOT MODIFY.
              sub       h+22,x                  'DO NOT MODIFY.
              add       h+14,x                  'DO NOT MODIFY.
              sub       h+18,x                  'DO NOT MODIFY.
              add       h+11,x                  'DO NOT MODIFY.
              add       h+13,x                  'DO NOT MODIFY.
              sub       h+23,x                  'DO NOT MODIFY.
              mov       h+17,x                  'DO NOT MODIFY.
              sub       h+6,x                   'DO NOT MODIFY.
              sub       h+3,x                   'DO NOT MODIFY.
              add       h+9,x                   'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              add       h+12,x                  'DO NOT MODIFY.
              sub       h+8,x                   'DO NOT MODIFY.
              sub       h+1,x                   'DO NOT MODIFY.
              sub       h+15,x                  'DO NOT MODIFY.
              sub       h+5,x                   'DO NOT MODIFY.
              sub       h+16,x                  'DO NOT MODIFY.
              mov       h+10,x                  'DO NOT MODIFY.
              sub       h+4,x                   'DO NOT MODIFY.
              sub       h+20,x                  'DO NOT MODIFY.
              sub       h+25,x                  'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              add       h+0,x                   'DO NOT MODIFY.
              sub       h+22,x                  'DO NOT MODIFY.
              sub       h+18,x                  'DO NOT MODIFY.
              sub       h+13,x                  'DO NOT MODIFY.
              add       h+17,x                  'DO NOT MODIFY.
              add       h+6,x                   'DO NOT MODIFY.
              add       h+3,x                   'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              add       h+8,x                   'DO NOT MODIFY.
              sub       h+10,x                  'DO NOT MODIFY.
              add       h+19,x                  'DO NOT MODIFY.
              sub       h+20,x                  'DO NOT MODIFY.
              sar       x,#1                    'DO NOT MODIFY.
              sub       h+12,x                  'DO NOT MODIFY.
              add       h+0,x                   'DO NOT MODIFY.
              add       h+22,x                  'DO NOT MODIFY.
              add       h+5,x                   'DO NOT MODIFY.
              sub       h+16,x                  'DO NOT MODIFY.
              sub       h+24,x                  'DO NOT MODIFY.
              add       h+11,x                  'DO NOT MODIFY.
              add       h+13,x                  'DO NOT MODIFY.
              sub       h+6,x                   'DO NOT MODIFY.
              sub       h+21,x                  'DO NOT MODIFY.
              add       h+7,x                   'DO NOT MODIFY.
              sub       h+25,x                  'DO NOT MODIFY.
              sub       h+9,x                   'DO NOT MODIFY.

'Apply input * coefficients to FIR stages and shift one step.

              sub       astage+0,h+0            'DO NOT MODIFY.
              mov       y,astage+0              'DO NOT MODIFY.
              sar       y,#1                    'DO NOT MODIFY.

'Writing the y value here allows overlapped processing with another cog.
'Delete the next line to process the output further in this cog.

              call      #put_y                  'Write the next output.

              sub       astage+1,h+1            'DO NOT MODIFY.
              mov       astage+0,astage+1       'DO NOT MODIFY.
              sub       astage+2,h+2            'DO NOT MODIFY.
              mov       astage+1,astage+2       'DO NOT MODIFY.
              add       astage+3,h+3            'DO NOT MODIFY.
              mov       astage+2,astage+3       'DO NOT MODIFY.
              add       astage+4,h+4            'DO NOT MODIFY.
              mov       astage+3,astage+4       'DO NOT MODIFY.
              sub       astage+5,h+5            'DO NOT MODIFY.
              mov       astage+4,astage+5       'DO NOT MODIFY.
              sub       astage+6,h+6            'DO NOT MODIFY.
              mov       astage+5,astage+6       'DO NOT MODIFY.
              add       astage+7,h+7            'DO NOT MODIFY.
              mov       astage+6,astage+7       'DO NOT MODIFY.
              add       astage+8,h+8            'DO NOT MODIFY.
              mov       astage+7,astage+8       'DO NOT MODIFY.
              sub       astage+9,h+9            'DO NOT MODIFY.
              mov       astage+8,astage+9       'DO NOT MODIFY.
              add       astage+10,h+10          'DO NOT MODIFY.
              mov       astage+9,astage+10      'DO NOT MODIFY.
              add       astage+11,h+11          'DO NOT MODIFY.
              mov       astage+10,astage+11     'DO NOT MODIFY.
              sub       astage+12,h+12          'DO NOT MODIFY.
              mov       astage+11,astage+12     'DO NOT MODIFY.
              sub       astage+13,h+13          'DO NOT MODIFY.
              mov       astage+12,astage+13     'DO NOT MODIFY.
              add       astage+14,h+14          'DO NOT MODIFY.
              mov       astage+13,astage+14     'DO NOT MODIFY.
              add       astage+15,h+15          'DO NOT MODIFY.
              mov       astage+14,astage+15     'DO NOT MODIFY.
              sub       astage+16,h+16          'DO NOT MODIFY.
              mov       astage+15,astage+16     'DO NOT MODIFY.
              sub       astage+17,h+17          'DO NOT MODIFY.
              mov       astage+16,astage+17     'DO NOT MODIFY.
              add       astage+18,h+2           'DO NOT MODIFY.
              mov       astage+17,astage+18     'DO NOT MODIFY.
              sub       astage+19,h+18          'DO NOT MODIFY.
              mov       astage+18,astage+19     'DO NOT MODIFY.
              sub       astage+20,h+19          'DO NOT MODIFY.
              mov       astage+19,astage+20     'DO NOT MODIFY.
              add       astage+21,h+20          'DO NOT MODIFY.
              mov       astage+20,astage+21     'DO NOT MODIFY.
              add       astage+22,h+21          'DO NOT MODIFY.
              mov       astage+21,astage+22     'DO NOT MODIFY.
              sub       astage+23,h+22          'DO NOT MODIFY.
              mov       astage+22,astage+23     'DO NOT MODIFY.
              sub       astage+24,h+23          'DO NOT MODIFY.
              mov       astage+23,astage+24     'DO NOT MODIFY.
              add       astage+25,h+24          'DO NOT MODIFY.
              mov       astage+24,astage+25     'DO NOT MODIFY.
              add       astage+26,h+25          'DO NOT MODIFY.
              mov       astage+25,astage+26     'DO NOT MODIFY.
              add       astage+27,h+24          'DO NOT MODIFY.
              mov       astage+26,astage+27     'DO NOT MODIFY.
              sub       astage+28,h+23          'DO NOT MODIFY.
              mov       astage+27,astage+28     'DO NOT MODIFY.
              sub       astage+29,h+22          'DO NOT MODIFY.
              mov       astage+28,astage+29     'DO NOT MODIFY.
              add       astage+30,h+21          'DO NOT MODIFY.
              mov       astage+29,astage+30     'DO NOT MODIFY.
              add       astage+31,h+20          'DO NOT MODIFY.
              mov       astage+30,astage+31     'DO NOT MODIFY.
              sub       astage+32,h+19          'DO NOT MODIFY.
              mov       astage+31,astage+32     'DO NOT MODIFY.
              sub       astage+33,h+18          'DO NOT MODIFY.
              mov       astage+32,astage+33     'DO NOT MODIFY.
              add       astage+34,h+2           'DO NOT MODIFY.
              mov       astage+33,astage+34     'DO NOT MODIFY.
              sub       astage+35,h+17          'DO NOT MODIFY.
              mov       astage+34,astage+35     'DO NOT MODIFY.
              sub       astage+36,h+16          'DO NOT MODIFY.
              mov       astage+35,astage+36     'DO NOT MODIFY.
              add       astage+37,h+15          'DO NOT MODIFY.
              mov       astage+36,astage+37     'DO NOT MODIFY.
              add       astage+38,h+14          'DO NOT MODIFY.
              mov       astage+37,astage+38     'DO NOT MODIFY.
              sub       astage+39,h+13          'DO NOT MODIFY.
              mov       astage+38,astage+39     'DO NOT MODIFY.
              sub       astage+40,h+12          'DO NOT MODIFY.
              mov       astage+39,astage+40     'DO NOT MODIFY.
              add       astage+41,h+11          'DO NOT MODIFY.
              mov       astage+40,astage+41     'DO NOT MODIFY.
              add       astage+42,h+10          'DO NOT MODIFY.
              mov       astage+41,astage+42     'DO NOT MODIFY.
              sub       astage+43,h+9           'DO NOT MODIFY.
              mov       astage+42,astage+43     'DO NOT MODIFY.
              add       astage+44,h+8           'DO NOT MODIFY.
              mov       astage+43,astage+44     'DO NOT MODIFY.
              add       astage+45,h+7           'DO NOT MODIFY.
              mov       astage+44,astage+45     'DO NOT MODIFY.
              sub       astage+46,h+6           'DO NOT MODIFY.
              mov       astage+45,astage+46     'DO NOT MODIFY.
              sub       astage+47,h+5           'DO NOT MODIFY.
              mov       astage+46,astage+47     'DO NOT MODIFY.
              add       astage+48,h+4           'DO NOT MODIFY.
              mov       astage+47,astage+48     'DO NOT MODIFY.
              add       astage+49,h+3           'DO NOT MODIFY.
              mov       astage+48,astage+49     'DO NOT MODIFY.
              sub       astage+50,h+2           'DO NOT MODIFY.
              mov       astage+49,astage+50     'DO NOT MODIFY.
              sub       astage+51,h+1           'DO NOT MODIFY.
              mov       astage+50,astage+51     'DO NOT MODIFY.
              neg       astage+51,h+0           'DO NOT MODIFY.

'Add code here to further process y if the call to put_y was deleted above.          

              jmp       #main_lp                'DO NOT MODIFY.

'This subroutine acquires the next input sample (x) from the hub.
'It can be changed to acquire the sample in another way.

get_x         rdlong    x,par wz                'Read busy flag. Is it zero?
       if_z   jmp       #get_x                  '  Yes: Keep checking.
       
              rdlong    x,xy_addr               '  No:  Read the input.
get_x_ret     ret

'This subroutine writes the output of the filter (y) to the hub.
'It can be changed to deal with the output in another way.

put_y         wrlong    y,xy_addr               'Write result to hub.
              wrlong    zero,par
put_y_ret     ret

'Constants and variables.

astage        long      0[52]                   'DO NOT MODIFY.
zero          long      0

xy_addr       res       1                       'Hub address of argument.
x             res       1                       'DO NOT MODIFY.
y             res       1                       'DO NOT MODIFY.
h             res       26                      'DO NOT MODIFY.

''=======[ License ]==========================================================
{{{
***************************************************************************************
*                                                                                     *
* Permission is hereby granted, free of charge, to any person obtaining a copy of     *
* this software and associated documentation files (the "Software"), to deal in       *
* the Software without restriction, including without limitation the rights to use,   *
* copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the     *
* Software, and to permit persons to whom the Software is furnished to do so,         *
* subject to the following conditions:                                                *
*                                                                                     *
* The above copyright notice and this permission notice shall be included in all      *
* copies or substantial portions of the Software.                                     *
*                                                                                     *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, *
* INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A       *
* PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT  *
* HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION   *
* OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      *
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                              *
*                                                                                     *
***************************************************************************************
}}