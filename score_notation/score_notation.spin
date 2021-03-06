''----------------------------------------------------------------------------------------------------------------------
''
'' Scrolling Score Notation GUI
''
'' Pete Hemery - University of the West of England - 2012 Dissertation Coursework.
'' Audio Signal Processing on the Parallax Propeller Demo Board
''                                          
'' 2012-06-18    v1.0  First Release.
''----------------------------------------------------------------------------------------------------------------------
''
'' This object uses the vga graphics object to draw lines on the screen to give the appearance of
''  a bar moving across and plotting notes received from microphone input and FFT output.
''
'' The current method of note detection is error prone. It involves looking at the FFT output
''   of the bin corresponding to the desired note to be detected. These values were calculated for 6 KHz.
'' Other methods exist, however this is a 'quick&dirty' way I thought of, that took forever to implement ;) but it works.
''
'' Notes and sharps are bit-packed into two longs. These are then used by the scrolling_note_gui.
'' This method also allows other GUI's to be plugged in relatively easily, e.g. a piano keyboard or guitar fretboard.
''
'' Sharps are represented as one pixel lines, while pure notes are represented by thicker lines.
''
'' The original purpose of this object was to demonstate FFT output while playing a kalimba/mbira.
'' As such, the default spacing of notes on the stave is from B3 to E6. This is when 'kalimba_range' is on.
'' The alternative spacing is from D3 to F#7. (octave numbers change on C, so D3 is lower than B3)
'' The spacing is modified in the scrolling_note_gui object with the constant 'kalimba_range'.
''
'' Finite Impulse Response (FIR) filtering is enabled by default, which cuts off all frequencies above 1.5 KHz.
''
'' To see what a kalimba looks and sounds like, look on youtube for 'Tinashé: Mbira'.
'' Turn the volume up and enjoy the VGA output. =)
''
'' Using bst it is possible to declare #defines, but the Propeller Tool doesn't support these,
''  therefore the relevant sections of code have been commented out or modified.
'' This means that code that was #defined out is now included and the amount of RAM spare is about 1 or 2 longs.
''
'' If you uncomment stuff, be warned, things will break!     
''
'' This project pushes the Propeller RAM to the limit, so most serial debug has been commented out.
'' Some of the functionality cannot be used in the PropTool version without deleting other code to make space.
''
'' Thanks to Heater in particular and others for their help on the Parallax forums.
''
'' After I had finished this I had music playing and ended up staring at it for hours =D
'' Hopefully this can be of some use to others. Feel free to break and play =)
''
''----------------------------------------------------------------------------------------------------------------------
'' Constants to tinker with:
''
'' Object                        Constant
''   score_notation                threshold  (amplitude of frequency (volume) detected to trigger note display.)
''
''   sampler                       filtering  (1.5 KHz cutoff lowpass filter - useful when kalimba_range is on.)
''                                            (on by default to begin with. disable to see full range of notes.)
''
''   scrolling_note_gui            scroll_speed  (the higher the number the slower the scrolling bar)
''                                 kalimba_range (1 or 0 = ON or OFF)
''----------------------------------------------------------------------------------------------------------------------
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  threshold = 5000

OBJ

  fft  : "heater_fft_hamming"
  aud  : "sampler"
  gr   : "scrolling_note_gui"
  pst  : "Parallax Serial Terminal"

VAR

  long  pst_on
  long  colors_ptr

  long  notes, sharps

  'cos and sin parts of the signal to be analysed
  'Result is written back to here.
  'Just write input samples to bx and zero all by.
  long bx[fft#FFT_SIZE]
  long by[fft#FFT_SIZE]

  'Mailbox interface to fft
  long fft_mailbox_cmd        'Command
  long fft_mailbox_bxp        'Address of x buffer
  long fft_mailbox_byp        'Address of y buffer


  'pointers for audio sampler cog
  long  audio_flag
  long  audio_time  

  word  audio_buffer_1[fft#FFT_SIZE]
  word  audio_buffer_2[fft#FFT_SIZE]

PUB start | x,y,i,k,startTime, endTime, flag_copy, first_trigger, audio_endTime,audio_startTime, total_startTime,total_endTime

  if ina[31] == 1                                       'Check if we're connected via USB
    pst_on := 1
    pst.Start(115200)                                   'Start the Parallax Serial Terminal cog
    pst.NewLine
  else
    pst_on := 0

  if pst_on == 1
    pst.str(string(pst#NL,"Start"))
    
  gr.start                      'starts 3 cogs - vga driver, graphics driver & scrolling plotter

  audio_flag := 3               'will be set to 0 on initialisation 

  first_trigger := 8            'wait for the samplers averaging to settle down before beginning

  fft.start(@fft_mailbox_cmd)   '1 heater fft

  aud.start(@audio_flag)        '1 sampler

                                       
  repeat                        'Main Loop
                                   
    if flag_copy <> long[@audio_flag]
      total_startTime := cnt
      flag_copy := long[@audio_flag]
      audio_endTime := long[@audio_time]

      endTime := cnt
      if pst_on == 1
        pst.str(string(pst#HM,"main loop wait time = "))
        pst.dec((endTime - startTime) / (clkfreq / 1000))
        pst.str(string("  ms",pst#NL))

{
        pst.str(string("sampler cog 512 samples run time = "))
        pst.dec((audio_endTime - audio_startTime) / (clkfreq / 1000))
        pst.str(string("ms",pst#NL))
        audio_startTime := audio_endTime
}
'        pst.str(string("flag:"))
        pst.dec(flag_copy)
        pst.newline
'        pst.dec(word[@audio_time])
'        pst.newline

      if first_trigger <> 0
        first_trigger--   
        next

      startTime := cnt

                                ''Only when the sampler flag is 0 or 2 (out of 0-3) is an fft buffer full and ready
      case flag_copy
        0 : repeat k from 0 to 1023
              long[@bx][k] := ~~word[@audio_buffer_2][k]

        2 : repeat k from 0 to 1023
              long[@bx][k] := ~~word[@audio_buffer_1][k]

        other :
            total_endTime := cnt

{            if pst_on == 1
              pst.str(string("main loop run time = "))
              pst.dec((total_endTime - total_startTime) / (clkfreq / 1000))
              pst.str(string("ms",pst#NL))
              startTime := cnt
}
            next                'skip the stages below if flag is 1 or 3 (only half full buffers)

      endTime := cnt
{
      if pst_on == 1
        pst.str(string("data copying run time = "))
        pst.dec((endTime - startTime) / (clkfreq / 1000))
        pst.str(string("ms",pst#NL))
}

      'The Fourier transform, including bit-reversal reordering and magnitude converstion
      startTime := cnt
      fft.butterflies(fft#CMD_DECIMATE | fft#CMD_BUTTERFLY | fft#CMD_MAGNITUDE, @bx, @by)'| fft#CMD_HAMMING ''Hamming handled in the sampler
      endTime := cnt

{
      if pst_on == 1
        pst.str(string("1024 point FFT plus magnitude calculation run time = "))
        pst.dec((endTime - startTime) / (clkfreq / 1000))
        pst.str(string("ms",pst#NL))
}
      startTime := cnt
      notes := sharps := 0

      if gr#kalimba_range == 1

        'The following array values are calibrated for 6 KHz microphone input
              
        repeat x from 41 to 222   'kalimba range
          if ||bx[x] > threshold        'absolute value
            case x 
              41       : notes  |= (or05)              'B3

              43..44   : notes  |= (or06)              'C4
              47       : sharps |=   (or04)               'C#
              49       : notes  |= (or07)              'D
              52       : sharps |=   (or05)               'D#
              55       : notes  |= (or08)              'E
              58       : notes  |= (or09)              'F
              61..62   : sharps |=   (or06)               'F#
              65..66   : notes  |= (or10)              'G
              69..70   : sharps |=   (or07)               'G#
              73..74   : notes  |= (or11)              'A
              77..78   : sharps |=   (or08)               'A#
              81..82   : notes  |= (or12)              'B

              87       : notes  |= (or13)              'C5
              92..93   : sharps |=   (or09)               'C#
              98       : notes  |= (or14)              'D
              103..104 : sharps |=   (or10)               'D#
              109..110 : notes  |= (or15)              'E
              116..117 : notes  |= (or16)              'F
              123..124 : sharps |=   (or11)               'F#
              130..131 : notes  |= (or17)              'G
              138..139 : sharps |=   (or12)               'G#
              146..147 : notes  |= (or18)              'A
              155..156 : sharps |=   (or13)               'A#
              164..166 : notes  |= (or19)              'B

              173..175 : notes  |= (or20)              'C6
              184..186 : sharps |=   (or14)               'C#
              195..197 : notes  |= (or21)              'D
              206..209 : sharps |=   (or15)               'D#
              219..221 : notes  |= (or22)              'E
{
          if pst_on == 1
            pst.dec(x)
            pst.char(":")
            pst.dec(||bx[x])
            pst.newline
}
      else
        repeat x from 24 to 495   'full range

          if ||bx[x] > threshold        'absolute value
            case x
              24       : notes  |= (or00)              'D3
              26       : sharps |=   (or00)               'D#
              27,28    : notes  |= (or01)              'E
              29       : notes  |= (or02)              'F
              31       : sharps |=   (or01)               'F#
              32,33    : notes  |= (or03)              'G
              34,35    : sharps |=   (or02)               'G#
              36,37    : notes  |= (or04)              'A
              39       : sharps |=   (or03)               'A#
              41       : notes  |= (or05)              'B

              43..44   : notes  |= (or06)              'C4
              47       : sharps |=   (or04)               'C#
              49       : notes  |= (or07)              'D
              52       : sharps |=   (or05)               'D#
              55       : notes  |= (or08)              'E
              58       : notes  |= (or09)              'F
              61..62   : sharps |=   (or06)               'F#
              65..66   : notes  |= (or10)              'G
              69..70   : sharps |=   (or07)               'G#
              73..74   : notes  |= (or11)              'A
              77..78   : sharps |=   (or08)               'A#
              81..82   : notes  |= (or12)              'B

              87       : notes  |= (or13)              'C5
              92..93   : sharps |=   (or09)               'C#
              98       : notes  |= (or14)              'D
              103..104 : sharps |=   (or10)               'D#
              109..110 : notes  |= (or15)              'E
              116..117 : notes  |= (or16)              'F
              123..124 : sharps |=   (or11)               'F#
              130..131 : notes  |= (or17)              'G
              138..139 : sharps |=   (or12)               'G#
              146..147 : notes  |= (or18)              'A
              155..156 : sharps |=   (or13)               'A#
              164..166 : notes  |= (or19)              'B

              173..175 : notes  |= (or20)              'C6
              184..186 : sharps |=   (or14)               'C#
              195..197 : notes  |= (or21)              'D
              206..209 : sharps |=   (or15)               'D#
              219..221 : notes  |= (or22)              'E

              232..234 : notes  |= (or23)              'F
              245..248 : sharps |=   (or16)               'F#
              260..263 : notes  |= (or24)              'G
              276..278 : sharps |=   (or17)               'G#
              292..295 : notes  |= (or25)              'A
              309..312 : sharps |=   (or18)               'A#
              328..331 : notes  |= (or26)              'B

              347..350 : notes  |= (or27)              'C7
              368..371 : sharps |=   (or19)               'C#
              390..393 : notes  |= (or28)              'D
              413..417 : sharps |=   (or20)               'D#
              438..441 : notes  |= (or29)              'E
              464..467 : notes  |= (or30)              'F
              491..495 : sharps |=   (or21)               'F#
{
          if pst_on == 1
            pst.dec(x)
            pst.char(":")
            pst.dec(||bx[x])
            pst.newline
}
'end of if kalimba_range

      endTime := cnt

      if pst_on == 1
        pst.str(string("Finding notes and sharps took = "))
        pst.dec((endTime - startTime) / (clkfreq / 1000))
        pst.str(string("  ms",pst#NL))

      gr.copy_notes(notes,sharps)

      if pst_on == 1
        pst.str(string("notes:  "))
        pst.hex(notes,8)
        pst.newline
        pst.str(string("sharps: "))
        pst.hex(sharps,8)
        pst.newline


      'Print resulting spectrum
      'printSpectrum


      longfill(@by,0,fft#FFT_SIZE)

      total_endTime := startTime := cnt

      if pst_on == 1
        pst.str(string("main loop run time = "))
        pst.dec((total_endTime - total_startTime) / (clkfreq / 1000))
        pst.str(string("  ms",pst#NL,pst#NL))



{PUB printSpectrum  | i, real, imag, magnitude
'Spectrum is available in first half of the buffers after FFT.
  if pst_on == 1
    pst.str(string("Freq. Magnitude"))
    pst.newline
    repeat i from 0 to (fft#FFT_SIZE / 2)
        pst.dec(i)
        pst.str(string(" "))
'        pst.hex(real, 8)
'        pst.str(string(" "))
'        pst.hex(imag, 8)
'        pst.str(string(" "))
        pst.dec(bx[i])
        pst.newline
}
'----------------------------------------------------------------------------------------------------------------------
DAT

or31          long      $80000000
or30          long      $40000000
or29          long      $20000000
or28          long      $10000000
or27          long      $08000000
or26          long      $04000000
or25          long      $02000000
or24          long      $01000000
or23          long      $00800000
or22          long      $00400000
or21          long      $00200000
or20          long      $00100000
or19          long      $00080000
or18          long      $00040000
or17          long      $00020000
or16          long      $00010000

or15          long      $00008000
or14          long      $00004000
or13          long      $00002000
or12          long      $00001000
or11          long      $00000800
or10          long      $00000400
or09          long      $00000200
or08          long      $00000100
or07          long      $00000080
or06          long      $00000040
or05          long      $00000020
or04          long      $00000010
or03          long      $00000008
or02          long      $00000004
or01          long      $00000002
or00          long      $00000001


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
